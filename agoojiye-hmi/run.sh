#!/usr/bin/env bash
#
# Construit et lance l'interface.
#
#   ./run.sh                  construit puis lance
#   ./run.sh --build          construit seulement
#   ./run.sh --clean          repart d'un dossier de build vide
#
# Le but est qu'un membre de l'équipe qui clone le dépôt n'ait rien à deviner :
# les dépendances manquantes sont nommées avec la commande qui les installe.

set -euo pipefail
cd "$(dirname "$0")"

BUILD_DIR=build
BUILD_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --build) BUILD_ONLY=1 ;;
        --clean) rm -rf "$BUILD_DIR" ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "Option inconnue : $arg" >&2; exit 2 ;;
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

exec "./$BUILD_DIR/agoojiye-hmi"
