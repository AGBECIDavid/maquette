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

echo
echo "OK — ${#EXPECTED[@]} panneaux, aucun avertissement."
[ -n "$KEEP_DIR" ] && echo "Captures : $KEEP_DIR"
exit 0
