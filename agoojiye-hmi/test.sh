#!/usr/bin/env bash
#
# Test de fumée. Il n'a pas besoin d'écran : Qt tourne en mode « offscreen »,
# l'interface parcourt tous ses panneaux et se ferme.
#
#   ./test.sh                 construit, parcourt, vérifie
#   ./test.sh --keep <dir>    garde les captures dans <dir> pour les regarder
#
# Il échoue si :
#   - la construction échoue ;
#   - Qt émet le moindre avertissement QML (propriété inconnue, dépendance
#     circulaire, type absent…) — c'est ce qui attrape les vraies régressions
#     de mise en page, elles ne cassent pas la compilation ;
#   - un panneau attendu n'a pas produit de capture, donc n'a pas pu s'afficher.

set -uo pipefail
cd "$(dirname "$0")"

KEEP_DIR=""
if [ "${1:-}" = "--keep" ]; then
    KEEP_DIR="${2:?--keep attend un dossier}"
fi

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

# ---- 2. parcours de tous les panneaux ------------------------------------
echo "· parcours de l'interface"
QT_QPA_PLATFORM=offscreen HMI_SCREENSHOT_DIR="$SHOTS" \
    ./build/agoojiye-hmi >"$LOG" 2>&1 || fail "l'application s'est arrêtée en erreur"

# Bruit attendu, sans rapport avec l'interface : pas de dossier d'exécution
# XDG dans un conteneur, et pas de moteur de synthèse vocale installé.
NOISE='XDG_RUNTIME_DIR|text-to-speech plug-ins'
if grep -Ev "$NOISE" "$LOG" | grep -q '[^[:space:]]'; then
    echo "Avertissements pendant le parcours :" >&2
    grep -Ev "$NOISE" "$LOG" >&2
    fail "l'interface n'est pas silencieuse"
fi

# ---- 3. tous les panneaux se sont affichés -------------------------------
echo "· vérification des panneaux"
EXPECTED=(
    dash menu nav phone entretien
    veh-0 veh-1 veh-2 veh-3 veh-4 veh-5
    conduite-0 conduite-1 conduite-2 conduite-3 conduite-4 conduite-5
    adas-0 adas-1 adas-2 adas-3 adas-4 adas-5
    media-0 media-1 media-2 media-3 media-4 media-5
    mediaNow-0 mediaNow-1 mediaNow-2 mediaNow-3
    parametres-0 parametres-1 parametres-2 parametres-3 parametres-4
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
    if prev is not None:
        jump = max(jump, abs(v - prev))
    prev = v

# 200 ms entre deux relevés ; au-delà de 2 km/h l'écart trahit une téléportation.
if jump > 2.0:
    problems.append(f"saut de vitesse de {jump:.1f} km/h en 200 ms")
if len(phases) < 3:
    problems.append(f"scénario incomplet, phases vues : {sorted(phases)}")

for p in problems[:5]:
    print("  ✗", p)
print(f"  accélération max observée : {jump/0.2/3.6:.2f} m/s²")
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
    COUNT="$(echo "$OUT" | cut -d, -f14)"
    [ "${COUNT:-0}" -ge 1 ] || fail "la panne « $kind » n'a levé aucune alerte"
done

echo
echo "OK — ${#EXPECTED[@]} panneaux, aucun avertissement, état cohérent."
[ -n "$KEEP_DIR" ] && echo "Captures : $KEEP_DIR"
exit 0
