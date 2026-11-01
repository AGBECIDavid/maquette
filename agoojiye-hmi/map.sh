#!/usr/bin/env bash
#
# Les données de la carte : la zone industrielle de Glo-Djigbé (GDIZ), tirées
# d'OpenStreetMap. Une fois récupérées, elles sont embarquées : la carte de la
# navette ne dépend jamais du réseau.
#
#   ./map.sh fetch                 trouve la GDIZ dans OSM, télécharge la zone
#   ./map.sh fetch --bbox S,O,N,E  même chose, emprise donnée à la main
#                                  (degrés décimaux : sud, ouest, nord, est)
#   ./map.sh report                refait le rapport sans retélécharger
#
# Résultat dans map/source/ :
#   gdiz.osm.json   les données brutes (routes, bâtiments, zones, lieux)
#   zone.json       l'emprise utilisée, et d'où elle vient
#   rapport.txt     ce qu'il y a, ce qui manque — c'est lui qu'il faut lire
#   apercu.svg      la zone dessinée, à ouvrir dans un navigateur
#
# Il faut curl et python3, rien d'autre. Le téléchargement passe par l'API
# publique Overpass d'OpenStreetMap : une seule requête, quelques Mo.
#
# Données © contributeurs OpenStreetMap, licence ODbL. La mention doit rester
# visible sur toute carte qui les affiche.

set -euo pipefail
cd "$(dirname "$0")"

OUT="$PWD/map/source"
TOOL="$PWD/tools/map/osm_tool.py"

# Deux serveurs Overpass publics : le second prend le relais si le premier
# est saturé, ce qui arrive aux heures chargées.
# MAP_OVERPASS remplace la liste (un miroir, ou un faux serveur pour tester).
read -r -a SERVERS <<< "${MAP_OVERPASS:-https://overpass-api.de/api/interpreter https://overpass.kumi.systems/api/interpreter}"
AGENT="AGOOJIYE-HMI/map.sh (carte embarquee de navette)"

# Où chercher la zone : le sud du Bénin, autour d'Abomey-Calavi, Zè et
# Tori-Bossito. Large exprès — c'est le nom qui trie, pas le cadre.
SEARCH_BOX="6.30,1.90,7.00,2.60"

say() { printf '· %s\n' "$*"; }
die() { printf '\n%s\n' "$*" >&2; exit 1; }

need() {
    command -v curl >/dev/null || die "curl manque : sudo apt install curl"
    command -v python3 >/dev/null || die "python3 manque : sudo apt install python3"
}

# overpass FICHIER_REQUÊTE SORTIE
overpass() {
    local query=$1 out=$2 server attempt
    for server in "${SERVERS[@]}"; do
        for attempt in 1 2 3; do
            # --fail : une page d'erreur HTML ne doit jamais passer pour des données.
            if curl -sS --fail --http1.1 -A "$AGENT" --max-time 240 \
                    --data-urlencode "data@$query" -o "$out.part" "$server"; then
                # Overpass répond parfois 200 avec un message d'erreur dans le
                # JSON (délai dépassé côté serveur) : on vérifie le contenu.
                if python3 - "$out.part" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
remark = d.get("remark", "")
sys.exit(1 if "runtime error" in remark or "timed out" in remark else 0)
EOF
                then
                    mv "$out.part" "$out"
                    return 0
                fi
                say "réponse incomplète de $(echo "$server" | cut -d/ -f3)"
            fi
            [ $attempt -lt 3 ] && { say "nouvel essai dans $((attempt * 10)) s"; sleep $((attempt * 10)); }
        done
        say "$(echo "$server" | cut -d/ -f3) ne répond pas, serveur suivant"
    done
    rm -f "$out.part"
    die "Overpass injoignable. Vérifiez la connexion (overpass-api.de doit être
joignable), puis relancez ./map.sh fetch."
}

locate() {
    say "recherche de la GDIZ dans OpenStreetMap"
    cat > "$OUT/.locate.q" <<EOF
[out:json][timeout:90];
(
  nwr["name"~"GDIZ|Glo.?Dji|Djigb",i]($SEARCH_BOX);
  nwr["operator"~"GDIZ|Arise",i]($SEARCH_BOX);
  nwr["landuse"="industrial"]["name"~"industri|GDIZ",i]($SEARCH_BOX);
);
out tags center bb;
EOF
    overpass "$OUT/.locate.q" "$OUT/.locate.json"
    python3 "$TOOL" candidates "$OUT/.locate.json" > "$OUT/zone.json"
}

download() {
    local s w n e
    IFS=, read -r s w n e < <(python3 -c 'import json,sys; print(",".join(map(str, json.load(open(sys.argv[1]))["bbox"])))' "$OUT/zone.json")
    local box="$s,$w,$n,$e"
    say "téléchargement de la zone ($box)"
    # Tout ce qu'une carte de navette affiche ou utilise : routes (le graphe de
    # l'itinéraire), bâtiments, occupation du sol, portes, lieux nommés, et les
    # repères visuels (voie ferrée, cours d'eau). « out body geom » donne à la
    # fois les coordonnées et les identifiants de nœuds : les seconds disent où
    # deux routes se croisent.
    cat > "$OUT/.fetch.q" <<EOF
[out:json][timeout:200][maxsize:268435456];
(
  way["highway"]($box);
  way["building"]($box);
  way["landuse"]($box);
  relation["landuse"]($box);
  way["barrier"]($box);
  node["barrier"~"gate|lift_gate"]($box);
  node["entrance"]($box);
  nwr["amenity"]($box);
  nwr["office"]($box);
  nwr["industrial"]($box);
  nwr["shop"]($box);
  nwr["public_transport"]($box);
  node["highway"="bus_stop"]($box);
  nwr["name"]($box);
  way["railway"]($box);
  way["waterway"]($box);
  way["natural"="water"]($box);
);
out body geom;
EOF
    overpass "$OUT/.fetch.q" "$OUT/gdiz.osm.json"
    say "$(du -h "$OUT/gdiz.osm.json" | cut -f1) reçus"
}

case "${1:-}" in
    fetch)
        need
        mkdir -p "$OUT"
        if [ "${2:-}" = "--bbox" ]; then
            [[ "${3:-}" =~ ^-?[0-9.]+,-?[0-9.]+,-?[0-9.]+,-?[0-9.]+$ ]] \
                || die "--bbox attend SUD,OUEST,NORD,EST en degrés décimaux, par exemple 6.55,2.18,6.62,2.26"
            printf '{"bbox": [%s], "from": "donnée à la main"}\n' "$3" > "$OUT/zone.json"
        elif [ -n "${2:-}" ]; then
            die "Argument inconnu : $2 (seul --bbox S,O,N,E est accepté)"
        else
            locate
        fi
        download
        say "rapport"
        echo
        python3 "$TOOL" report "$OUT/gdiz.osm.json" "$OUT"
        echo
        say "à lire : map/source/rapport.txt — à regarder : map/source/apercu.svg"
        ;;
    report)
        need
        [ -s "$OUT/gdiz.osm.json" ] || die "Pas encore de données : ./map.sh fetch"
        python3 "$TOOL" report "$OUT/gdiz.osm.json" "$OUT"
        ;;
    *)
        sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
