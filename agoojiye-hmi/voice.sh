#!/usr/bin/env bash
#
# Les moteurs locaux de l'assistant vocal : reconnaissance de la parole
# (whisper.cpp) et compréhension des phrases libres (llama.cpp). Une fois
# installés, ils tournent sur la machine et rien ne part sur Internet.
#
#   ./voice.sh install    compile les moteurs, télécharge les modèles (une fois)
#   ./voice.sh start      lance les deux serveurs en arrière-plan
#   ./voice.sh stop       les arrête
#   ./voice.sh status     dit ce qui tourne
#   ./voice.sh test       vérifie la chaîne : voix de synthèse → texte → réponse
#   ./voice.sh verify     compare les modèles à leurs empreintes de référence
#   ./voice.sh pin        inscrit l'empreinte d'un modèle vérifié à la main
#
# Puis ./run.sh — l'interface trouve les serveurs toute seule, même lancés
# après elle. ./run.sh --voix fait les deux d'un coup.
#
# Réglages, par variable d'environnement :
#   VOICE_ASR=base        modèle de reconnaissance : tiny · base · small
#                         (small comprend mieux, mais 3 fois plus lent)
#   VOICE_LLM=1.5b        modèle de langage : 1.5b · 3b
#                         (3b converse mieux ; licence non commerciale)
#   VOICE_THREADS=4       cœurs utilisés par chaque moteur
#   VOICE_STRICT=1        refuse de lancer un modèle sans empreinte de référence
#                         (à poser sur le véhicule ; voir ./voice.sh pin)
#
# Sans ces moteurs, l'assistant reste utilisable : au clavier, et pour les
# formules exactes de sa table de commandes.

set -euo pipefail
cd "$(dirname "$0")"

ROOT="$PWD/voice"
SRC="$ROOT/src"
MODELS="$ROOT/models"
RUN="$ROOT/run"
LOGS="$ROOT/logs"

# Versions figées : un moteur qui change sous l'interface peut changer son API.
# L'étiquette dit quoi télécharger ; le commit dit ce qu'on doit avoir reçu.
# Une étiquette peut être déplacée par qui contrôle le dépôt, un commit non :
# si les deux ne concordent plus, l'installation s'arrête.
WHISPER_TAG=v1.9.5
WHISPER_COMMIT=d1be6fde11ac6e0407606b4e42fe72d34add8037
LLAMA_TAG=b11497
LLAMA_COMMIT=ff30363a0e3e2630828309ef5a37da5d1d40396c

# Empreintes SHA-256 des modèles, versionnées avec le code.
SUMS="$PWD/voice/modeles.sha256"

ASR_PORT=8178
LLM_PORT=8179
ASR="${VOICE_ASR:-base}"
LLM="${VOICE_LLM:-1.5b}"
THREADS="${VOICE_THREADS:-$(( $(nproc 2>/dev/null || echo 4) > 4 ? 4 : $(nproc 2>/dev/null || echo 4) ))}"

case "$ASR" in tiny|base|small) ;; *) echo "VOICE_ASR : tiny, base ou small (reçu : $ASR)" >&2; exit 2 ;; esac
case "$LLM" in
    1.5b) LLM_REPO=Qwen/Qwen2.5-1.5B-Instruct-GGUF; LLM_FILE=qwen2.5-1.5b-instruct-q4_k_m.gguf ;;
    3b)   LLM_REPO=Qwen/Qwen2.5-3B-Instruct-GGUF;   LLM_FILE=qwen2.5-3b-instruct-q4_k_m.gguf ;;
    *) echo "VOICE_LLM : 1.5b ou 3b (reçu : $LLM)" >&2; exit 2 ;;
esac
ASR_FILE="ggml-$ASR.bin"
ASR_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$ASR_FILE"
LLM_URL="https://huggingface.co/$LLM_REPO/resolve/main/$LLM_FILE"

WHISPER_BIN="$SRC/whisper.cpp/build/bin/whisper-server"
LLAMA_BIN="$SRC/llama.cpp/build/bin/llama-server"

say()  { printf '· %s\n' "$*"; }
since() { awk -v a="$1" -v b="$(date +%s.%N)" 'BEGIN { printf "%.1f", b - a }'; }
die()  { printf '\n%s\n' "$*" >&2; exit 1; }

# ---- install --------------------------------------------------------------
build() {   # nom dépôt tag commit cible options…
    local name=$1 repo=$2 tag=$3 commit=$4 target=$5; shift 5
    local dir="$SRC/$name"
    if [ ! -d "$dir/.git" ]; then
        say "téléchargement des sources de $name ($tag)"
        git clone -q --depth 1 --branch "$tag" "$repo" "$dir"
    fi
    # Vérifié à chaque fois, pas seulement au téléchargement : des sources
    # modifiées après coup ne se compilent pas davantage.
    local got; got="$(git -C "$dir" rev-parse HEAD)"
    [ "$got" = "$commit" ] || die "Sources de $name inattendues.
  attendu : $commit ($tag)
  reçu    : $got
L'étiquette $tag ne désigne plus le commit vérifié, ou le dossier a été modifié.
Rien n'est compilé. Supprimez $dir et relancez ; si l'écart persiste,
ne l'ignorez pas : vérifiez le dépôt $repo."
    say "compilation de $target — quelques minutes la première fois"
    # Bibliothèques statiques : le binaire ne dépend pas de l'endroit où il a
    # été compilé. GGML_NATIVE optimise pour ce processeur-ci — sur la cible
    # embarquée, compiler sur la cible.
    cmake -S "$dir" -B "$dir/build" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF "$@" \
        >"$LOGS/build-$name.log" 2>&1 \
        || die "Configuration de $name impossible. Journal : $LOGS/build-$name.log"
    cmake --build "$dir/build" -j"$(nproc 2>/dev/null || echo 4)" --target "$target" \
        >>"$LOGS/build-$name.log" 2>&1 \
        || die "Compilation de $name impossible. Journal : $LOGS/build-$name.log"
}

fetch() {   # url fichier taille-indicative
    local url=$1 out="$MODELS/$2" size=$3
    if [ -s "$out" ]; then
        say "$2 déjà présent"
        return
    fi
    say "téléchargement de $2 ($size)"
    # Dans un .part, repris là où il s'est arrêté : un téléchargement coupé ne
    # doit jamais passer pour un modèle complet.
    #
    # Les gros fichiers de Hugging Face voient souvent leur flux HTTP/2 coupé
    # en route (« stream reset », erreur 92), et `--retry` de curl ne réessaie
    # pas cette erreur-là. D'où HTTP/1.1, et une boucle qui reprend elle-même
    # où l'essai précédent s'est arrêté.
    local attempt
    for attempt in 1 2 3 4 5 6; do
        if curl -L --fail --http1.1 --retry 3 -C - --progress-bar -o "$out.part" "$url"; then
            mv "$out.part" "$out"
            return
        fi
        [ $attempt -lt 6 ] && { say "coupure — reprise ($((attempt + 1))/6) dans 3 s"; sleep 3; }
    done
    die "Téléchargement impossible après 6 essais : $url
Vérifiez la connexion (huggingface.co doit être joignable), puis relancez
./voice.sh install — il reprendra où il s'est arrêté."
}

# ---- intégrité des modèles ---------------------------------------------------
# Un modèle est un fichier de plus d'un gigaoctet, téléchargé une fois et
# exécuté ensuite à chaque démarrage. Son empreinte est comparée à celle du
# fichier voice/modeles.sha256, versionné : un téléchargement corrompu, ou un
# fichier remplacé sur le disque, est refusé.
#
# Un modèle sans empreinte connue (première installation d'une variante)
# n'est PAS accepté en silence : son empreinte est affichée, et c'est
# « ./voice.sh pin », lancé par quelqu'un qui a vérifié la source, qui
# l'inscrit dans le fichier.
sha() { sha256sum "$1" | cut -d' ' -f1; }
known_sum() { [ -f "$SUMS" ] && awk -v f="$1" '$2 == f { print $1 }' "$SUMS" | head -1; }

verify() {   # fichier → 0 si conforme, 1 si inconnu, arrêt si différent
    local file=$1 want got
    want="$(known_sum "$file")"
    [ -n "$want" ] || return 1
    got="$(sha "$MODELS/$file")"
    [ "$got" = "$want" ] || die "Modèle $file altéré ou corrompu.
  attendu : $want
  reçu    : $got
Supprimez $MODELS/$file et relancez ./voice.sh install."
    return 0
}

check_models() {   # mode : strict (refuse l'inconnu) ou souple (le signale)
    local mode=$1 file unknown=0
    for file in "$ASR_FILE" "$LLM_FILE"; do
        [ -s "$MODELS/$file" ] || continue
        if verify "$file"; then
            [ "$mode" = souple ] && say "$file : empreinte conforme"
        else
            unknown=1
            echo "  $file : aucune empreinte de référence dans voice/modeles.sha256" >&2
            echo "    SHA-256 : $(sha "$MODELS/$file")" >&2
        fi
    done
    if [ $unknown -eq 1 ]; then
        echo >&2
        echo "Comparez cette empreinte à celle publiée par la source (page « Files »" >&2
        echo "du modèle sur huggingface.co, colonne SHA256), puis : ./voice.sh pin" >&2
        [ "$mode" = strict ] && die "Démarrage refusé (VOICE_STRICT=1) : modèle non vérifié."
    fi
    return 0
}

pin() {
    local file tmp; tmp="$(mktemp)"
    [ -f "$SUMS" ] && cp "$SUMS" "$tmp"
    for file in "$ASR_FILE" "$LLM_FILE"; do
        [ -s "$MODELS/$file" ] || die "Modèle $file absent : ./voice.sh install d'abord."
        if [ -n "$(known_sum "$file")" ]; then
            verify "$file"; say "$file : déjà inscrit, conforme"
        else
            printf '%s  %s\n' "$(sha "$MODELS/$file")" "$file" >> "$tmp"
            say "$file : empreinte inscrite"
        fi
    done
    { echo "# Empreintes SHA-256 des modèles vocaux — vérifiées par ./voice.sh."
      echo "# Inscrites par « ./voice.sh pin » après comparaison avec la source."
      grep -v '^#' "$tmp" | sort -k2; } > "$SUMS"
    rm -f "$tmp"
    say "à versionner : git add voice/modeles.sha256"
}

install() {
    local missing=()
    for c in git cmake c++ curl sha256sum; do command -v $c >/dev/null || missing+=("$c"); done
    [ ${#missing[@]} -eq 0 ] || die "Il manque : ${missing[*]}
  sudo apt install git cmake build-essential curl"
    mkdir -p "$SRC" "$MODELS" "$LOGS" "$RUN"

    build whisper.cpp https://github.com/ggml-org/whisper.cpp "$WHISPER_TAG" "$WHISPER_COMMIT" whisper-server \
        -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_BUILD_SERVER=ON -DWHISPER_BUILD_TESTS=OFF
    build llama.cpp https://github.com/ggml-org/llama.cpp "$LLAMA_TAG" "$LLAMA_COMMIT" llama-server \
        -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_OPENSSL=OFF

    case "$ASR" in tiny) s="75 Mo" ;; base) s="142 Mo" ;; small) s="466 Mo" ;; esac
    fetch "$ASR_URL" "$ASR_FILE" "$s"
    [ "$LLM" = 3b ] && s="1,9 Go" || s="1,1 Go"
    fetch "$LLM_URL" "$LLM_FILE" "$s"

    check_models souple
    echo
    echo "Installé. Lancer : ./voice.sh start"
}

# ---- start / stop -----------------------------------------------------------
# Un fichier .pid survit à un redémarrage de la machine, et son numéro peut
# alors appartenir à un tout autre programme : on vérifie que le processus est
# bien l'un de nos deux serveurs avant de le dire vivant — ou de le tuer.
alive() {
    local pid
    [ -f "$RUN/$1.pid" ] || return 1
    pid="$(cat "$RUN/$1.pid")"
    [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null || return 1
    case "$(readlink "/proc/$pid/exe" 2>/dev/null)" in
        "$(realpath "$WHISPER_BIN" 2>/dev/null)"|"$(realpath "$LLAMA_BIN" 2>/dev/null)") return 0 ;;
        *) return 1 ;;
    esac
}
healthy() { curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$1/health" 2>/dev/null | grep -q 200; }

start() {
    [ -x "$WHISPER_BIN" ] && [ -x "$LLAMA_BIN" ] || die "Moteurs absents. D'abord : ./voice.sh install"
    [ -s "$MODELS/$ASR_FILE" ] || die "Modèle $ASR_FILE absent. D'abord : VOICE_ASR=$ASR ./voice.sh install"
    [ -s "$MODELS/$LLM_FILE" ] || die "Modèle $LLM_FILE absent. D'abord : VOICE_LLM=$LLM ./voice.sh install"
    mkdir -p "$RUN" "$LOGS"
    # Un modèle dont l'empreinte ne correspond pas n'est jamais lancé. Un
    # modèle sans empreinte de référence est signalé, et lancé quand même sur
    # un poste de développement ; avec VOICE_STRICT=1 (à poser sur le
    # véhicule), il est refusé lui aussi.
    if [ "${VOICE_STRICT:-0}" = 1 ]; then check_models strict; else check_models silencieux; fi

    if alive asr; then say "reconnaissance déjà lancée"; else
        say "reconnaissance (whisper $ASR) sur le port $ASR_PORT"
        nohup "$WHISPER_BIN" -m "$MODELS/$ASR_FILE" -l fr -t "$THREADS" \
            --host 127.0.0.1 --port "$ASR_PORT" >"$LOGS/asr.log" 2>&1 &
        echo $! >"$RUN/asr.pid"
    fi
    if alive llm; then say "compréhension déjà lancée"; else
        say "compréhension (Qwen2.5 $LLM) sur le port $LLM_PORT"
        # Un seul échange à la fois (-np 1) : tout le contexte lui revient, et
        # le début de conversation, identique d'une phrase à l'autre, reste en
        # cache — seule la dernière phrase est calculée.
        nohup "$LLAMA_BIN" -m "$MODELS/$LLM_FILE" -t "$THREADS" -c 4096 -np 1 \
            --host 127.0.0.1 --port "$LLM_PORT" >"$LOGS/llm.log" 2>&1 &
        echo $! >"$RUN/llm.pid"
    fi

    say "chargement des modèles…"
    for _ in $(seq 120); do
        healthy $ASR_PORT && healthy $LLM_PORT && { echo; echo "Prêt. Dites « Salut Agoojiye » dans l'interface (./run.sh)."; return; }
        alive asr || die "La reconnaissance s'est arrêtée. Journal : $LOGS/asr.log"
        alive llm || die "La compréhension s'est arrêtée. Journal : $LOGS/llm.log"
        sleep 0.5
    done
    die "Les modèles ne répondent pas après 60 s. Journaux : $LOGS/"
}

stop() {
    for s in asr llm; do
        if alive $s; then kill "$(cat "$RUN/$s.pid")" && say "$s arrêté"; fi
        rm -f "$RUN/$s.pid"
    done
}

status() {
    # Libellés alignés à la main : printf compte les octets, et « é » en vaut deux.
    echo "reconnaissance ($ASR_PORT)   $(healthy $ASR_PORT && echo prête || (alive asr && echo 'en chargement' || echo arrêtée))"
    echo "compréhension  ($LLM_PORT)   $(healthy $LLM_PORT && echo prête || (alive llm && echo 'en chargement' || echo arrêtée))"
}

# ---- test -----------------------------------------------------------------
# De bout en bout, sans micro : une voix de synthèse dit une phrase, whisper
# la transcrit, le modèle de langage la comprend. Si ceci marche et que
# l'interface reste sourde, le problème est le micro, pas les moteurs.
selftest() {
    healthy $ASR_PORT && healthy $LLM_PORT || die "Moteurs arrêtés. D'abord : ./voice.sh start"
    local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN

    echo "1. Reconnaissance"
    if command -v espeak-ng >/dev/null; then
        espeak-ng -v fr -s 150 -w "$tmp/phrase.wav" "Salut Agoojiye, quelle est mon autonomie ?"
        local t0=$(date +%s.%N)
        local text
        text="$(curl -s -F file=@"$tmp/phrase.wav" -F language=fr -F response_format=json \
                -F temperature=0.0 -F 'prompt=Salut Agoojiye. Allume le clignotant à droite. Mode sport. Quelle est mon autonomie ?' \
                "http://127.0.0.1:$ASR_PORT/inference")"
        printf '   dit       : Salut Agoojiye, quelle est mon autonomie ?\n'
        printf '   entendu   : %s\n' "$(echo "$text" | python3 -c 'import json,sys; print(json.load(sys.stdin)["text"].strip())' 2>/dev/null || echo "$text")"
        printf '   durée     : %s s\n' "$(since "$t0")"
        echo "   (voix de synthèse : une vraie voix est en général mieux reconnue)"
    else
        echo "   ignorée : espeak-ng absent (sudo apt install espeak-ng)"
    fi

    echo "2. Compréhension"
    local t0=$(date +%s.%N)
    local reply
    reply="$(curl -s "http://127.0.0.1:$LLM_PORT/v1/chat/completions" -H 'Content-Type: application/json' -d '{
      "messages": [
        {"role": "system", "content": "Tu es Agoojiye, assistant vocal d une navette. Réponds en JSON {\"command\":..., \"reply\":...}. Commandes : mode-sport (passer en mode sport), ask-range (autonomie). Sinon command vaut null. Une phrase courte."},
        {"role": "user", "content": "Conducteur : tu peux me mettre en mode sport s il te plaît ?"}
      ],
      "temperature": 0.3, "max_tokens": 80,
      "response_format": {"type": "json_schema", "json_schema": {"name": "r", "schema": {
        "type": "object", "required": ["command", "reply"],
        "properties": {"command": {"anyOf": [{"type": "string", "enum": ["mode-sport", "ask-range"]}, {"type": "null"}]},
                       "reply": {"type": "string"}}}}}
    }')"
    printf '   demande   : tu peux me mettre en mode sport s il te plaît ?\n'
    printf '   réponse   : %s\n' "$(echo "$reply" | python3 -c 'import json,sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"])' 2>/dev/null || echo "$reply")"
    printf '   durée     : %s s\n' "$(since "$t0")"
    echo "   attendu   : \"command\": \"mode-sport\""
}

case "${1:-}" in
    install) install ;;
    pin)     pin ;;
    verify)  check_models souple ;;
    start)   start ;;
    stop)    stop ;;
    status)  status ;;
    test)    selftest ;;
    *)       sed -n '2,29p' "$0" | sed 's/^# \?//'; exit 2 ;;
esac
