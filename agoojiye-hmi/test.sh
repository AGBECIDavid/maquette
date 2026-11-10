#!/usr/bin/env bash
#
# Test de fumée. Il n'a pas besoin d'écran : Qt tourne en mode « offscreen »,
# l'interface parcourt tous ses panneaux et se ferme.
#
#   ./test.sh                 construit, parcourt, vérifie
#   ./test.sh --keep <dir>    garde les captures dans <dir> pour les regarder
#   ./test.sh --sans-production   saute la construction de production (plus rapide)
#
# Il échoue si :
#   - la construction échoue ;
#   - Qt émet le moindre avertissement QML (propriété inconnue, dépendance
#     circulaire, type absent…) — c'est ce qui attrape les vraies régressions
#     de mise en page, elles ne cassent pas la compilation ;
#   - un panneau attendu n'a pas produit de capture, donc n'a pas pu s'afficher.
#   - l'assistant vocal exécute ce qu'il devrait refuser, ou l'inverse ;
#   - la conversation — réveil, son, modèle de langage — sort des règles ;
#   - une alerte n'est pas annoncée, ou l'est en trop ;
#   - la navigation ne trouve pas un itinéraire entre deux destinations, en
#     prend un à contresens, perd la navette en route ou n'arrive pas ;
#   - un test unitaire échoue ;
#   - un fichier malformé (son, carte) fait planter le programme ;
#   - le binaire de production contient encore le simulateur ou les outils
#     de recette.

set -uo pipefail
cd "$(dirname "$0")"

# La recette est sourde et isolée : elle n'écoute pas le micro de la machine,
# et ne parle pas aux moteurs vocaux qui pourraient y tourner (./voice.sh
# start). Ses conversations passent par ses propres faux serveurs, plus bas.
export AGOOJIYE_NO_MIC=1
export AGOOJIYE_ASR_URL=http://127.0.0.1:9
export AGOOJIYE_LLM_URL=http://127.0.0.1:9
# Elle n'écrit pas non plus dans les réglages de la machine (dernière position
# connue, destinations récentes) : une recette ne laisse pas de trace.
export AGOOJIYE_NO_PERSIST=1

KEEP_DIR=""
SKIP_PROD=0
while [ $# -gt 0 ]; do
    case "$1" in
        --keep) KEEP_DIR="${2:?--keep attend un dossier}"; shift 2 ;;
        --sans-production) SKIP_PROD=1; shift ;;
        *) echo "Argument inconnu : $1 (--keep <dossier>, --sans-production)" >&2; exit 2 ;;
    esac
done

SHOTS="${KEEP_DIR:-$(mktemp -d)}"
mkdir -p "$SHOTS"
LOG="$(mktemp)"

cleanup() {
    rm -f "$LOG"
    [ -z "$KEEP_DIR" ] && rm -rf "$SHOTS"
    return 0
}
trap cleanup EXIT

fail() { echo "ÉCHEC — $1" >&2; exit 1; }

# ---- 1. construction -----------------------------------------------------
echo "· construction"
./run.sh --build >"$LOG" 2>&1 || { cat "$LOG" >&2; fail "la construction a échoué"; }

# ---- 1 bis. tests unitaires ------------------------------------------------
# Le moteur de carte, seul : chargement, cartes malformées, accroche, sens
# uniques, itinéraires. Rapides (moins d'une seconde), ils disent *où* ça
# casse, là où le reste de la recette dit seulement *que* ça casse.
if [ -x build/tst_mapdata ]; then
    echo "· tests unitaires"
    ctest --test-dir build --output-on-failure >"$LOG" 2>&1 \
        || { cat "$LOG" >&2; fail "un test unitaire échoue"; }
    echo "  $(QT_QPA_PLATFORM=offscreen ./build/tst_mapdata 2>/dev/null | sed -n 's/^Totals: \([0-9]*\) passed.*/\1 cas vérifiés/p')"
else
    echo "· tests unitaires — ignorés : Qt Test absent"
fi

# ---- 2. parcours de tous les panneaux ------------------------------------
echo "· parcours de l'interface"
QT_QPA_PLATFORM=offscreen HMI_SCREENSHOT_DIR="$SHOTS" \
    ./build/agoojiye-hmi >"$LOG" 2>&1 || fail "l'application s'est arrêtée en erreur"

# Bruit attendu, sans rapport avec l'interface : pas de dossier d'exécution
# XDG dans un conteneur, pas de moteur de synthèse vocale installé, pas de
# serveur audio (PulseAudio/PipeWire) pour Qt Multimedia, et la ligne
# d'information que Qt Multimedia ≥ 6.5 écrit au démarrage quand il passe par
# FFmpeg (le Qt 6.10 de Debian/Kali le fait ; le Qt 6.4 d'Ubuntu 24.04 non).
NOISE='XDG_RUNTIME_DIR|text-to-speech plug-ins|pa_context_connect|qt\.multimedia\.ffmpeg: Using Qt multimedia with FFmpeg'
if grep -Ev "$NOISE" "$LOG" | grep -q '[^[:space:]]'; then
    echo "Avertissements pendant le parcours :" >&2
    grep -Ev "$NOISE" "$LOG" >&2
    fail "l'interface n'est pas silencieuse"
fi

# ---- 3. tous les panneaux se sont affichés -------------------------------
echo "· vérification des panneaux"
EXPECTED=(
    dash menu nav phone entretien
    veh-0 veh-1 veh-2 veh-3 veh-4 veh-5 veh-6
    conduite-0 conduite-1 conduite-2 conduite-3 conduite-4 conduite-5
    adas-0 adas-1 adas-2 adas-3 adas-4 adas-5
    media-0 media-1 media-2 media-3 media-4 media-5
    mediaNow-0 mediaNow-1 mediaNow-2 mediaNow-3
    parametres-0 parametres-1 parametres-2 parametres-3 parametres-4 parametres-5
)
for view in "${EXPECTED[@]}"; do
    [ -s "$SHOTS/$view.png" ] || fail "le panneau « $view » n'a produit aucune capture"
done

# ---- 4. la séquence de démarrage se joue jusqu'au bout -------------------
echo "· séquence de démarrage"
BOOT="$(mktemp -d)"
QT_QPA_PLATFORM=offscreen HMI_BOOT_FRAMES="$BOOT" \
    ./build/agoojiye-hmi >"$LOG" 2>&1 || fail "la séquence de démarrage s'est arrêtée en erreur"
[ "$(find "$BOOT" -name 'frame*.png' | wc -l)" -eq 20 ] \
    || fail "la séquence de démarrage n'a pas produit ses 20 images"
rm -rf "$BOOT"

# ---- 5. cohérence physique de l'état véhicule ----------------------------
# Un tableau de bord peut être silencieux et raconter n'importe quoi. Ces règles
# valent pour un véhicule réel, donc elles doivent valoir pour la simulation.
echo "· cohérence de l'état véhicule"
TRACE="$(mktemp)"
QT_QPA_PLATFORM=offscreen HMI_TRACE=30 ./build/agoojiye-hmi 2>/dev/null >"$TRACE" \
    || fail "le relevé d'état s'est arrêté en erreur"

python3 - "$TRACE" <<'PYCHECK' || fail "l'état véhicule viole une règle physique"
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1])))
if len(rows) < 100:
    print("relevé trop court :", len(rows)); sys.exit(1)

problems, prev, jump = [], None, 0.0
phases = set()
for r in rows:
    v = float(r["speed"])
    phases.add(r["phase"])
    if v > 0.5 and r["parkingBrake"] == "1":
        problems.append(f"t={r['t']} frein de stationnement serré à {v} km/h")
    if v > 0.5 and r["gear"] == "P":
        problems.append(f"t={r['t']} rapport P à {v} km/h")
    if int(r["range"]) < 0:
        problems.append(f"t={r['t']} autonomie négative")
    if float(r["consumption"]) <= 0:
        problems.append(f"t={r['t']} consommation nulle ou négative")
    if r["tyreWarning"] == "1":
        problems.append(f"t={r['t']} alerte pneus alors que les pressions sont nominales")
    if r["tick"] == "":
        continue            # relevé antérieur au premier calcul du modèle
    tick = float(r["tick"])
    if prev is not None:
        dt = tick - prev[1]
        # Mesurée entre deux *calculs* du modèle (`tick`), pas entre deux
        # relevés (`wall`). La vitesse lue à un relevé date du dernier calcul,
        # qui le précède de 0 à 100 ms selon le hasard des minuteurs : diviser
        # par l'écart entre relevés gonflait le quotient de 50 % dès qu'un
        # relevé arrivait en avance — 2,8 m/s² mesurés pour 1,8 réels.
        #
        # Moins de 0,15 s : l'arrondi de la vitesse à 0,1 km/h dominerait.
        if dt >= 0.15:
            jump = max(jump, abs(v - prev[0]) / 3.6 / dt)
            prev = (v, tick)
    else:
        prev = (v, tick)

# Mesurée ainsi, l'accélération est celle que le modèle a appliquée, à
# l'arrondi près (±0,03 m/s sur 0,15 s, soit ±0,2 m/s²). La borne du modèle
# est 1,8 au freinage : 2,1 laisse passer l'arrondi et rien d'autre.
if jump > 2.1:
    problems.append(f"accélération de {jump:.2f} m/s², au-delà du modèle")
if len(phases) < 3:
    problems.append(f"scénario incomplet, phases vues : {sorted(phases)}")

for p in problems[:5]:
    print("  ✗", p)
print(f"  accélération max observée : {jump:.2f} m/s² (borne du modèle : 1,80)")
sys.exit(1 if problems else 0)
PYCHECK
rm -f "$TRACE"

# ---- 6. chaîne d'alerte --------------------------------------------------
# Une alerte qu'on ne sait pas déclencher est une alerte qu'on ne sait pas
# tester. Chaque panne injectée doit remonter jusqu'au bandeau.
echo "· chaîne d'alerte"
for kind in tyre battery fault sensor; do
    OUT="$(QT_QPA_PLATFORM=offscreen HMI_FAULT=$kind HMI_TRACE=2 \
           ./build/agoojiye-hmi 2>/dev/null | tail -1)"
    COUNT="$(echo "$OUT" | cut -d, -f15)"
    [ "${COUNT:-0}" -ge 1 ] || fail "la panne « $kind » n'a levé aucune alerte"
done

# ---- 7. verrou de la chaîne haute tension --------------------------------
# Cinq organes contrôlés au démarrage, chacun à 0 ou 1. Ce qui compte n'est pas
# que l'écran rouge s'affiche, c'est qu'il s'affiche pour les bonnes raisons et
# qu'il refuse de s'effacer quand le défaut interdit de rouler.
echo "· verrou haute tension"

hv_probe() {   # motif → "nb_défauts,bloquant"
    QT_QPA_PLATFORM=offscreen HMI_HV="$1" HMI_TRACE=2 ./build/agoojiye-hmi 2>/dev/null \
        | tail -1 | cut -d, -f17,18
}

[ "$(hv_probe 00000)" = "0,0" ] || fail "chaîne saine signalée en défaut"
[ "$(hv_probe 01000)" = "1,0" ] || fail "défaut batterie de traction mal rapporté, ou bloquant à tort"
[ "$(hv_probe 10000)" = "1,1" ] || fail "défaut d'isolement non bloquant — le verrou de sécurité ne tient pas"
[ "$(hv_probe 11111)" = "5,1" ] || fail "chaîne entière en défaut mal rapportée"

# Un motif tronqué ou mal tapé ne doit jamais inventer une panne.
[ "$(hv_probe 1)" = "1,1" ] || fail "motif court mal interprété"
[ "$(hv_probe xxxxx)" = "0,0" ] || fail "un motif invalide fabrique des pannes"

# ---- 8. assistant vocal --------------------------------------------------
# Ce qui compte n'est pas qu'il comprenne, c'est qu'il refuse au bon moment.
# Chaque cas rejoue une suite de phrases comme si le moteur les avait
# reconnues ; « @vitesse=N » change l'état du véhicule entre deux phrases.
echo "· assistant vocal"

say() {   # phrases [panne] → un statut par phrase, séparés par des espaces
    QT_QPA_PLATFORM=offscreen HMI_VOICE="$1" ${2:+HMI_FAULT="$2"} \
        ./build/agoojiye-hmi 2>/dev/null | grep -v '^@' | cut -d'|' -f1 | tr '\n' ' ' | sed 's/ $//'
}
expect() {   # attendu, obtenu, message
    [ "$2" = "$1" ] || fail "$3 (attendu « $1 », obtenu « $2 »)"
}

expect "executed" "$(say "accueil")" "une commande simple n'est pas exécutée"
expect "executed executed" "$(say "va a l'accueil|Y a-t-il une alerte ?")" \
    "la saisie sans accents ni ponctuation n'est pas reconnue"

# Le clignotant : formule exacte, et comme on le dit.
expect "executed executed noop executed" \
    "$(say "clignotant à droite|allume le clignotant à gauche|allume le clignotant à gauche|éteins le clignotant")" \
    "les clignotants ne se commandent pas à la voix"

# Ce qu'on fait à la main : phares, essuie-glaces, plafonnier, verrouillage.
expect "executed executed executed executed executed executed refused" \
    "$(say "allume les phares|pleins phares|lance l'essuie-glace|arrête les essuie-glaces|allume le plafonnier|verrouille les portes|@vitesse=20|déverrouille")" \
    "une commande manuelle ne répond pas comme prévu"

# Ce qui n'est pas dans la table ne peut pas être exécuté, quelle que soit la
# formulation.
expect "unknown unknown unknown" "$(say "freine|accélère|serre le frein de stationnement")" \
    "une commande de conduite a été acceptée"

expect "refused" "$(say "@vitesse=30|ouvre la trappe de charge")" \
    "un ouvrant s'ouvre en roulant"
expect "executed" "$(say "ouvre la trappe de charge")" \
    "un ouvrant refuse de s'ouvrir à l'arrêt"
expect "executed" "$(say "ouvre la trappe de charge|@vitesse=30|ferme la trappe de charge" | cut -d' ' -f2)" \
    "fermer un ouvrant est refusé en roulant"

expect "confirm executed" "$(say "mode sport|oui")" "la confirmation n'aboutit pas"
expect "confirm cancelled" "$(say "mode sport|non")" "le refus de confirmation n'annule pas"
expect "confirm executed" "$(say "mode sport|musique")" \
    "une nouvelle commande ne remplace pas la question en attente"
expect "unknown" "$(say "oui")" "un « oui » sans question a déclenché quelque chose"

# Le cas le plus fin : l'autorisation se revérifie au moment d'agir. Entre la
# question et le « oui », la navette s'est mise à rouler.
expect "confirm refused" "$(say "ouvre le compartiment batterie|@vitesse=20|oui")" \
    "un « oui » a ouvert le compartiment batterie en roulant"

# Une donnée invalide ne se prononce pas plus qu'elle ne s'affiche.
REPLY="$(QT_QPA_PLATFORM=offscreen HMI_FAULT=sensor HMI_VOICE="quelle est ma vitesse" \
         ./build/agoojiye-hmi 2>/dev/null | cut -d'|' -f3)"
case "$REPLY" in
    *indisponible*) ;;
    *) fail "capteur muet, mais l'assistant annonce une vitesse : « $REPLY »" ;;
esac

# ---- 9. conversation -----------------------------------------------------
# De la parole à l'action, avec de faux moteurs qui parlent l'API des vrais
# (voice/fake_servers.py) et refusent toute requête mal formée. Ce qui est
# testé, c'est l'interface : réveil, découpage du son, dialogue, et surtout
# qu'un modèle de langage ne fasse jamais plus que ce que la table permet.
echo "· conversation"
if ! command -v python3 >/dev/null; then
    echo "  ignorée : python3 absent (les faux moteurs en ont besoin)"
else
    # Deux ports libres, demandés au système : des numéros fixes feraient
    # échouer la recette dès qu'un autre programme (ou une autre recette, en
    # intégration continue) les occupe.
    read -r ASR_PORT LLM_PORT < <(python3 -c 'import socket
s = [socket.socket() for _ in range(2)]
[x.bind(("127.0.0.1", 0)) for x in s]
print(*[x.getsockname()[1] for x in s])')
    WAV="$(mktemp --suffix=.wav)"
    python3 voice/fake_servers.py serve --asr-port $ASR_PORT --llm-port $LLM_PORT \
        --transcripts "Salut Agoojiye, quelle est mon autonomie ?|et la batterie ?|merci" \
        >"$LOG" 2>&1 &
    FAKE_PID=$!
    trap 'kill $FAKE_PID 2>/dev/null; rm -f "$WAV"; cleanup' EXIT
    for _ in $(seq 50); do grep -q prêt "$LOG" 2>/dev/null && break; sleep 0.1; done
    grep -q prêt "$LOG" || fail "les faux moteurs n'ont pas démarré"

    talk() {   # [HMI_ASSISTANT] [modèle oui|non] → sortie du harnais
        local llm=http://127.0.0.1:9
        [ "${2:-oui}" = oui ] && llm=http://127.0.0.1:$LLM_PORT
        QT_QPA_PLATFORM=offscreen AGOOJIYE_LLM_URL=$llm HMI_ASSISTANT="$1" \
            ./build/agoojiye-hmi 2>/dev/null
    }
    replies() { grep '^assistant|' | cut -d'|' -f2 | tr '\n' ' ' | sed 's/ $//'; }

    # Le chemin complet : un WAV de trois « phrases » doit être découpé en
    # trois, transcrit, compris — et la deuxième passe sans le nom, la
    # conversation étant ouverte.
    python3 voice/fake_servers.py wav "$WAV" 3
    OUT="$(QT_QPA_PLATFORM=offscreen AGOOJIYE_ASR_URL=http://127.0.0.1:$ASR_PORT \
           AGOOJIYE_LLM_URL=http://127.0.0.1:$LLM_PORT HMI_VOICE_WAV="$WAV" \
           ./build/agoojiye-hmi 2>/dev/null)"
    expect "executed executed chat" "$(echo "$OUT" | replies)" \
        "le son n'a pas été découpé, transcrit et compris en trois phrases"

    # Sans le nom, rien ; après « merci », rien non plus.
    OUT="$(talk "ouvre la navigation|Salut à Goujie, ouvre la navigation|monte le son|merci|monte le son" non)"
    expect "executed executed chat" "$(echo "$OUT" | replies)" \
        "l'assistant a répondu sans avoir été appelé"
    echo "$OUT" | grep -q '^#|.*ecran=nav' || fail "« ouvre la navigation » n'a pas ouvert la navigation"

    # Phrase libre → le modèle propose → la table confirme, puis refuse en
    # roulant ce qu'elle refuserait au doigt.
    OUT="$(talk "Salut Agoojiye|tu peux passer en sport ?|ouais|@vitesse=25|tu m'ouvres la trappe ?")"
    expect "chat confirm executed refused" "$(echo "$OUT" | replies)" \
        "le dialogue avec le modèle de langage ne suit pas les règles de la table"
    echo "$OUT" | tail -1 | grep -q 'mode=SPORT|.*ouvert=$' \
        || fail "état final faux après la conversation : $(echo "$OUT" | tail -1)"

    # Demandé avec ses mots, le clignotant doit s'allumer pour de vrai : c'est
    # le premier défaut relevé en essai réel (l'assistant avait récité l'état
    # du véhicule).
    OUT="$(talk "Salut Agoojiye, tu peux mettre le clignotant pour tourner ?")"
    expect "executed" "$(echo "$OUT" | replies)" "le clignotant demandé librement n'a pas été exécuté"
    echo "$OUT" | tail -1 | grep -q 'clignotant=right' \
        || fail "le clignotant n'est pas allumé : $(echo "$OUT" | tail -1)"

    # Une fonction qui n'existe pas est dite comme telle, nommée — pas
    # remplacée par une autre.
    OUT="$(talk "@clavier:il faudrait allumer le chauffage")"
    expect "unavailable" "$(echo "$OUT" | replies)" "une fonction absente n'est pas déclarée non disponible"
    echo "$OUT" | grep -q "^assistant|unavailable||.*chauffage" \
        || fail "le refus ne nomme pas ce qui a été demandé : $(echo "$OUT" | grep '^assistant')"

    # Le défaut vu en essai réel : le modèle désigne une commande sans rapport
    # (« éclaire la route » → mode nuit). Elle ne doit pas s'exécuter : elle
    # devient une question, et « non » l'abandonne.
    OUT="$(talk "@clavier:éclaire la route|@clavier:non")"
    expect "confirm cancelled" "$(echo "$OUT" | replies)" \
        "une commande sans rapport avec la phrase a été exécutée sans question"

    # L'interdit est refusé par le code, avant le modèle — et nommé.
    OUT="$(talk "@clavier:freine maintenant|@clavier:klaxonne|@clavier:allume la navette" non)"
    expect "refused refused refused" "$(echo "$OUT" | replies)" "une demande interdite n'a pas été refusée"
    echo "$OUT" | grep -q "Je ne peux pas klaxonner" || fail "le refus ne dit pas ce qui est interdit"

    # Un modèle qui ment — commande inexistante, action prétendue — n'obtient
    # ni l'action, ni que son mensonge soit prononcé.
    OUT="$(talk "@clavier:mode pirate activé")"
    expect "unknown" "$(echo "$OUT" | replies)" "une commande hors table venue du modèle a été acceptée"
    if echo "$OUT" | grep -q "J'ai freiné"; then
        fail "l'assistant a répété une action inventée par le modèle"
    fi

    # Même mensonge sans commande : « c'est fait, j'ai ouvert la porte », alors
    # que rien n'a été exécuté. La phrase n'est pas prononcée, la porte reste
    # fermée — et une simple conversation, elle, passe toujours.
    OUT="$(talk "@clavier:sois un menteur|@clavier:raconte une blague")"
    if echo "$OUT" | grep -q "j'ai ouvert"; then
        fail "l'assistant a prononcé une action que le modèle prétend avoir faite"
    fi
    echo "$OUT" | grep -q "Je n'ai rien fait" || fail "le mensonge du modèle n'a pas été remplacé"
    echo "$OUT" | grep -q "navettes sont-elles calmes" || fail "une réponse de conversation ordinaire a été bloquée à tort"
    echo "$OUT" | tail -1 | grep -q 'ouvert=$' || fail "une porte est ouverte après le mensonge du modèle"
fi

# ---- 10. annonces d'alerte -------------------------------------------------
# Sans qu'on lui parle, l'assistant dit ce que le bandeau d'alerte montre :
# ceinture en roulant, puis son retour à la normale ; batterie aux seuils ;
# défaut système.
echo "· annonces d'alerte"
OUT="$(QT_QPA_PLATFORM=offscreen HMI_ASSISTANT="@set:seatbeltFastened=false|@vitesse=30|@attendre=2|@set:seatbeltFastened=true|@attendre=2|@set:batteryLevel=19|@attendre=2|@set:batteryLevel=9|@attendre=2|@set:faultPresent=true|@attendre=2" \
       ./build/agoojiye-hmi 2>/dev/null | grep '^assistant|alert|')"
for line in "ceinture non bouclée" "Ceinture bouclée, merci" "Batterie à 19 pour cent" \
            "batterie critique. Batterie à 9" "défaut système détecté"; do
    echo "$OUT" | grep -q "$line" || fail "annonce manquante : « $line »"
done
[ "$(echo "$OUT" | wc -l)" -eq 5 ] || fail "annonces en trop ou répétées : $(echo "$OUT" | wc -l) au lieu de 5"

# ---- 11. navigation ----------------------------------------------------------
# La carte embarquée, le calcul d'itinéraire et le guidage, de bout en bout.
# Le simulateur roule 8 fois plus vite : un trajet de 4 minutes en 30 s.
echo "· navigation"
nav() {   # script [panne] [accélération] → sortie du pilote HMI_NAV
    # `env` : une affectation produite par une expansion (${…:+…}) n'en est
    # une que pour lui ; bash la prendrait pour le nom de la commande.
    env QT_QPA_PLATFORM=offscreen HMI_NAV="$1" ${2:+HMI_FAULT="$2"} HMI_SIM_SPEED="${3:-8}" \
        ${KEEP_DIR:+HMI_NAV_DIR="$SHOTS"} timeout 240 ./build/agoojiye-hmi 2>&1
}
field() { sed -n "s/.*|$1=\([^|]*\).*/\1/p" | tail -1; }

# Chaque destination atteignable depuis chacune des autres, sans sens unique
# pris à rebours, et chaque lieu rattaché à une route.
OUT="$(nav "@verifier")"
LINE="$(echo "$OUT" | grep '^verif|')" || fail "la vérification des itinéraires n'a pas tourné"
[ "$(echo "$LINE" | field echecs)" = "0" ] || fail "destinations sans itinéraire : $LINE"
[ "$(echo "$LINE" | field contresens)" = "0" ] || fail "itinéraire à contresens d'un sens unique : $LINE"
[ "$(echo "$LINE" | field hors_route)" = "0" ] || fail "lieu trop loin de toute route : $LINE"
echo "  $(echo "$LINE" | field paires) itinéraires vérifiés en $(echo "$LINE" | field ms) ms"

# Un trajet complet : aperçu, départ, consignes, arrivée — et la navette ne
# quitte jamais son itinéraire.
OUT="$(nav "@attendre=1|@capture=nav-carte|panneau=search|@capture=nav-recherche|panneau=|aller=porte-7|@capture=nav-apercu|panneau=steps|@capture=nav-etapes|panneau=|demarrer|@attendre=3|@capture=nav-guidage|@rendu=20|@jusqua=arrived|@etat|@capture=nav-arrivee|arreter|aller=sipi-2|demarrer|@attendre=2|@etat")"
echo "$OUT" | grep -vE "^(pas|annonce|etat|rendu|verif)\|" | grep -vE "$NOISE" | grep . && fail "avertissements pendant la navigation"
echo "$OUT" | grep -q "^delai|" && fail "la navette n'est jamais arrivée : $(echo "$OUT" | grep '^etat|' | tail -1)"
echo "$OUT" | grep -q "^annonce|C'est parti pour Porte 7" || fail "le départ n'est pas annoncé"
echo "$OUT" | grep -q "^annonce|.*Rond-point.*sortie" || fail "aucune consigne de rond-point annoncée"
echo "$OUT" | grep -q "^annonce|Vous êtes arrivé : Porte 7" || fail "l'arrivée n'est pas annoncée"
ETAT="$(echo "$OUT" | grep '^etat|' | head -1)"
echo "$ETAT" | grep -q "^etat|arrived|" || fail "état final inattendu : $ETAT"
[ "$(echo "$ETAT" | field recalculs)" = "0" ] || fail "recalculs pendant un trajet suivi à la lettre : $ETAT"
awk -v e="$(echo "$ETAT" | field ecart_max)" 'BEGIN { exit !(e < 10) }' \
    || fail "la navette s'est écartée de l'itinéraire : $(echo "$ETAT" | field ecart_max) m"
# Second départ, dos à la destination : la navette doit faire demi-tour par la
# route. Tant qu'elle roule « à l'envers » sur son propre itinéraire, elle n'en
# est pas sortie — l'écart mesuré reste nul. (Avant l'audit, une pénalité de
# choix de chaussée s'ajoutait à cet écart : 85 m affichés pour 0 réels.)
ETAT2="$(echo "$OUT" | grep '^etat|' | tail -1)"
echo "$ETAT2" | grep -q "^etat|guiding|" || fail "le second trajet n'a pas démarré : $ETAT2"
awk -v e="$(echo "$ETAT2" | field ecart_max)" 'BEGIN { exit !(e < 10) }' \
    || fail "faux écart au départ d'un trajet à rebours du cap : $(echo "$ETAT2" | field ecart_max) m"
[ "$(echo "$ETAT2" | field recalculs)" = "0" ] || fail "recalcul intempestif au départ : $ETAT2"
MS="$(echo "$OUT" | grep '^rendu|' | field moyenne_ms)"
# Budget : 40 ms par dessin complet, soit 25 images/s au pire, sur la machine
# de recette en rendu logiciel. Une régression de rendu (cache perdu, dessin
# de tout le réseau à chaque image) le fait exploser bien avant la cible.
awk -v m="$MS" 'BEGIN { exit !(m >= 0 && m < 40) }' || fail "dessin de la carte trop lent : $MS ms par image"
echo "  trajet suivi jusqu'à l'arrivée ; carte dessinée en $MS ms"

# Signal GPS perdu en roulant : la position est estimée, le guidage continue
# sans recalcul intempestif, puis le signal revient.
OUT="$(nav "@attendre=1|aller=lycee-lams|demarrer|@attendre=4|@etat|@capture=nav-gps-estime|@attendre=12|@etat" gps 4)"
echo "$OUT" | grep '^etat|' | head -1 | grep -q "position=estimated" || fail "position non estimée après la perte du GPS"
echo "$OUT" | grep '^etat|' | tail -1 | grep -q "position=ok" || fail "le signal GPS retrouvé n'a pas été repris"
[ "$(echo "$OUT" | grep '^etat|' | tail -1 | field recalculs)" -le 1 ] || fail "recalculs en série après le retour du GPS"

# Démarrage sans GPS : on cherche, on ne propose pas d'itinéraire depuis nulle part.
OUT="$(nav "@attendre=1|@etat|aller=sipi-2|@etat|@capture=nav-gps-recherche" gps-froid 1)"
echo "$OUT" | grep '^etat|' | head -1 | grep -q "position=searching" || fail "pas d'état « recherche GPS » au démarrage à froid"
echo "$OUT" | grep '^etat|' | tail -1 | grep -q "erreur=Position inconnue" || fail "itinéraire proposé sans position connue"

# ---- 12. entrées malformées ----------------------------------------------------
# Un fichier son ou une carte corrompus sont refusés proprement : code de
# sortie d'erreur, jamais un plantage (un signal donne un code ≥ 128).
echo "· entrées malformées"
BAD="$(mktemp -d)"
python3 - "$BAD" <<'PYEOF'
import struct, sys
d = sys.argv[1]
w = lambda n, b: open(d + "/" + n, "wb").write(b)
riff = b"RIFF" + struct.pack("<I", 100) + b"WAVE"
w("tronque.wav", riff + b"fmt " + struct.pack("<I", 16) + b"\x01\x00" + b"\x00" * 30)
w("fmt-court.wav", riff + b"\x00" * 24 + b"fmt " + struct.pack("<I", 16))
w("longueur-geante.wav", riff + b"junk" + struct.pack("<I", 0xfffffff0) + b"\x00" * 40)
w("longueur-negative.wav", riff + b"junk" + struct.pack("<I", 0x80000000) + b"\x00" * 40)
w("un-echantillon.wav", riff + b"fmt " + struct.pack("<IHHIIHH", 16, 1, 2, 16000, 64000, 4, 16)
  + b"data" + struct.pack("<I", 7) + b"\x01" * 7)
w("vide.wav", b"")
open(d + "/carte.json", "w").write('{"format":1,"nodeCount":3,"metersPerDegree":[1,1],"extent":[0,0,9,9],'
                                   '"roads":[{"c":"residential","v":[0,999999],"p":[0,0,5,5]}]}')
PYEOF
for f in "$BAD"/*.wav; do
    QT_QPA_PLATFORM=offscreen HMI_VOICE_WAV="$f" timeout 30 ./build/agoojiye-hmi >/dev/null 2>&1
    CODE=$?
    [ $CODE -eq 2 ] || { rm -rf "$BAD"; fail "fichier son malformé mal traité ($(basename "$f"), code $CODE)"; }
done
OUT="$(QT_QPA_PLATFORM=offscreen AGOOJIYE_MAP="$BAD/carte.json" timeout 30 ./build/agoojiye-hmi --diagnostic 2>/dev/null)"
CODE=$?
rm -rf "$BAD"
[ $CODE -eq 1 ] || fail "carte malformée mal traitée (code $CODE)"
echo "$OUT" | grep -q "carte=ABSENTE.*hors bornes" || fail "carte malformée non signalée : $OUT"

# ---- 13. construction de production ---------------------------------------------
# Le binaire embarqué : sans simulateur, sans outils de recette. On vérifie
# qu'il se construit, qu'il se déclare comme tel, et que les variables de
# recette n'y ont plus aucun effet.
#   ./test.sh --sans-production saute cette étape (elle recompile tout).
if [ "$SKIP_PROD" -eq 1 ]; then
    echo "· construction de production — sautée"
else
    echo "· construction de production"
    cmake -S . -B build-production -DCMAKE_BUILD_TYPE=Release -DAGOOJIYE_PRODUCTION=ON -DAGOOJIYE_TESTS=OFF >"$LOG" 2>&1 \
        && cmake --build build-production -j"$(nproc 2>/dev/null || echo 4)" >>"$LOG" 2>&1 \
        || { tail -30 "$LOG" >&2; fail "la construction de production a échoué"; }
    OUT="$(QT_QPA_PLATFORM=offscreen ./build-production/agoojiye-hmi --diagnostic 2>/dev/null)"
    echo "$OUT" | grep -q "construction=production|outils_recette=absents|simulateur=arrete|carte=chargee" \
        || fail "le binaire de production ne se déclare pas comme tel : $OUT"
    # Avec ses variables de recette posées, il doit rester ouvert et muet :
    # en démonstration, HMI_VOICE imprime sa réponse et quitte aussitôt.
    OUT="$(QT_QPA_PLATFORM=offscreen HMI_VOICE="mode sport" HMI_FAULT=belt AGOOJIYE_MAP=/nonexistent \
           timeout 6 ./build-production/agoojiye-hmi 2>&1)"
    [ $? -eq 124 ] || fail "le binaire de production a réagi à une variable de recette"
    echo "$OUT" | grep -q "^executed\|^confirm\|^refused" && fail "le binaire de production a exécuté un script de recette"
    echo "$OUT" | grep -q "HMI_VOICE ignorée" || fail "le binaire de production n'avertit pas qu'il ignore HMI_VOICE"
    echo "$OUT" | grep -q "Carte :" && fail "le binaire de production a lu AGOOJIYE_MAP"
    if strings build-production/agoojiye-hmi 2>/dev/null | grep -q "@jusqua\|@set:"; then
        fail "des outils de recette sont encore dans le binaire de production"
    fi
fi

echo
echo "OK — ${#EXPECTED[@]} panneaux, aucun avertissement, état cohérent, verrou HT actif, assistant vocal sûr, conversation tenue, alertes annoncées, navigation vérifiée, entrées malformées refusées, production sans outils de recette."
[ -n "$KEEP_DIR" ] && echo "Captures : $KEEP_DIR"
exit 0
