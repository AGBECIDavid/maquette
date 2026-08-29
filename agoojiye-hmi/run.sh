#!/usr/bin/env bash
#
# Construit et lance l'interface.
#
#   ./run.sh                  construit puis lance
#   ./run.sh --build          construit seulement
#   ./run.sh --clean          repart d'un dossier de build vide
#
# Scénarios de démonstration, à passer directement en argument :
#
#   ./run.sh 00000            chaîne haute tension saine (défaut)
#   ./run.sh 01000            batterie de traction en défaut
#   ./run.sh 10000            isolement châssis → démarrage refusé
#   ./run.sh 11111            toute la chaîne au tapis
#
#   ./run.sh tyre             pression des pneus
#   ./run.sh belt             ceinture non bouclée
#   ./run.sh battery          batterie critique
#   ./run.sh sensor           capteur de vitesse muet
#   ./run.sh fault            défaut système
#
# Les deux se combinent : ./run.sh 01000 tyre
#
# Le but est qu'un membre de l'équipe qui clone le dépôt n'ait rien à deviner :
# les dépendances manquantes sont nommées avec la commande qui les installe, et
# un scénario se rejoue sans retenir de nom de variable d'environnement.

set -euo pipefail
cd "$(dirname "$0")"

BUILD_DIR=build
BUILD_ONLY=0
HV_PATTERN=""
FAULT=""

for arg in "$@"; do
    case "$arg" in
        --build) BUILD_ONLY=1 ;;
        --clean) rm -rf "$BUILD_DIR" ;;
        -h|--help) sed -n '2,27p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)
            # Un motif haute tension ne contient que des 0 et des 1 ; un nom de
            # panne est un mot. Les deux ne peuvent pas se confondre.
            if [[ "$arg" =~ ^[01]{1,5}$ ]]; then
                HV_PATTERN="$arg"
            elif [[ "$arg" =~ ^(belt|tyre|battery|sensor|fault)$ ]]; then
                FAULT="$arg"
            else
                # Ici l'utilisateur a tapé quelque chose exprès : une faute de
                # frappe doit être signalée, pas absorbée en silence.
                echo "Argument inconnu : $arg" >&2
                echo >&2
                echo "Motif haute tension : 5 chiffres 0/1, ex. 10000" >&2
                echo "Panne : belt, tyre, battery, sensor, fault" >&2
                echo "Aide complète : ./run.sh --help" >&2
                exit 2
            fi
            ;;
    esac
done

# ---- dépendances ---------------------------------------------------------
missing=()
command -v cmake >/dev/null || missing+=("cmake")
command -v c++   >/dev/null || missing+=("g++")

# Qt n'est pas sondé ici : la configuration CMake plus bas le fait pour de vrai,
# et son échec porte déjà le message utile.
if [ ${#missing[@]} -gt 0 ]; then
    echo "Il manque : ${missing[*]}" >&2
    echo >&2
    echo "  sudo apt install build-essential cmake" >&2
    exit 1
fi

# ---- configuration -------------------------------------------------------
# CMAKE_PREFIX_PATH permet de désigner un Qt installé ailleurs que dans le
# système, typiquement celui de l'installeur officiel :
#
#   CMAKE_PREFIX_PATH=$HOME/Qt/6.8.3/gcc_64 ./run.sh
if ! cmake -S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release; then
    echo >&2
    echo "La configuration a échoué. Si Qt 6 est introuvable :" >&2
    echo >&2
    echo "  sudo apt install qt6-base-dev qt6-declarative-dev \\" >&2
    echo "                   qml6-module-qtquick qml6-module-qtquick-controls \\" >&2
    echo "                   qml6-module-qtquick-shapes qml6-module-qtquick-window" >&2
    echo >&2
    echo "…ou désignez votre Qt :" >&2
    echo "  CMAKE_PREFIX_PATH=\$HOME/Qt/6.8.3/gcc_64 ./run.sh" >&2
    exit 1
fi

cmake --build "$BUILD_DIR" -j"$(nproc 2>/dev/null || echo 4)"

[ "$BUILD_ONLY" -eq 1 ] && exit 0

# Les scénarios passent par l'environnement, que le programme lit au démarrage.
# Les nommer en argument évite d'avoir à s'en souvenir.
if [ -n "$HV_PATTERN" ]; then echo "· chaîne haute tension : $HV_PATTERN"; fi
if [ -n "$FAULT" ]; then echo "· panne injectée : $FAULT"; fi

exec env ${HV_PATTERN:+HMI_HV="$HV_PATTERN"} ${FAULT:+HMI_FAULT="$FAULT"} \
     "./$BUILD_DIR/agoojiye-hmi"
