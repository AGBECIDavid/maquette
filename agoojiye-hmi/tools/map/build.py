#!/usr/bin/env python3
"""Prépare la carte embarquée à partir de l'extrait OpenStreetMap.

    build.py SOURCE_DIR LIEUX.json SORTIE.json

SOURCE_DIR contient gdiz.osm.json et zone.json (écrits par ./map.sh fetch).
LIEUX.json est la liste des destinations, tenue par l'équipe.

La sortie est ce que l'IHM charge au démarrage : tout y est déjà projeté en
mètres autour du centre de la zone, découpé à l'emprise, et réduit à ce qui
sert à dessiner ou à calculer un itinéraire. L'IHM n'a ainsi ni projection
géographique à faire à chaque image, ni données inutiles à parcourir.

Bibliothèque standard seulement.
"""

import json
import math
import sys
from datetime import datetime, timezone

R = 6371008.8   # rayon terrestre moyen, m

CATEGORIES = {"entree", "porte", "usine", "service", "sante", "commerce", "restauration",
              "carburant", "ecole", "marche", "village", "repere"}

# Ce que la navette peut emprunter. Les chemins piétons, les escaliers, les
# pistes cyclables restent dessinés mais n'entrent pas dans le calcul.
DRIVABLE = {
    "motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
    "secondary", "secondary_link", "tertiary", "tertiary_link", "unclassified",
    "residential", "living_street", "service", "road", "track",
}


def die(msg):
    print("map build : " + msg, file=sys.stderr)
    sys.exit(1)


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except OSError as e:
        die("lecture impossible de %s : %s" % (path, e))
    except ValueError as e:
        die("%s n'est pas du JSON valide : %s" % (path, e))


class Projection:
    """Projection équirectangulaire locale. Sur 6 km, l'écart avec une vraie
    projection conforme reste sous le décimètre — très en deçà de la
    précision d'un GPS."""

    def __init__(self, lat0, lon0):
        self.lat0, self.lon0 = lat0, lon0
        self.ky = math.pi / 180 * R
        self.kx = self.ky * math.cos(math.radians(lat0))

    def __call__(self, lat, lon):
        return (round((lon - self.lon0) * self.kx, 1), round((lat - self.lat0) * self.ky, 1))


def flat(points):
    out = []
    for x, y in points:
        out += [x, y]
    return out


def main(src, lieux_path, out_path):
    data = load(src + "/gdiz.osm.json")
    zone = load(src + "/zone.json")
    lieux = load(lieux_path)
    s, w, n, e = zone["bbox"]
    proj = Projection((s + n) / 2, (w + e) / 2)

    def inside(lat, lon):
        return s <= lat <= n and w <= lon <= e

    elements = data.get("elements", [])
    ref = zone.get("from") if isinstance(zone.get("from"), dict) else {}

    zone_outline = []
    areas, water, rail, buildings, roads, gates = [], [], [], [], [], []
    node_index = {}

    def node_id(osm_id):
        if osm_id not in node_index:
            node_index[osm_id] = len(node_index)
        return node_index[osm_id]

    for el in elements:
        tags = el.get("tags", {})
        t = el["type"]
        if t == "way":
            g = [(p["lat"], p["lon"]) for p in el.get("geometry") or [] if p]
            if not g:
                continue
            if el["id"] == ref.get("id") and ref.get("type") == "way":
                zone_outline = [proj(*p) for p in g]
                continue
            any_inside = any(inside(*p) for p in g)
            if "highway" in tags:
                nodes = el.get("nodes", [])
                if len(nodes) != len(g):
                    continue
                # Découpe à l'emprise : on garde chaque tronçon dont un bout au
                # moins est dedans. La RNIE 2 arrive avec 30 km ; il en reste
                # ce qui traverse la carte, en un ou plusieurs morceaux.
                runs, cur = [], []
                for i in range(len(g) - 1):
                    if inside(*g[i]) or inside(*g[i + 1]):
                        if not cur:
                            cur = [i]
                        cur.append(i + 1)
                    elif cur:
                        runs.append(cur)
                        cur = []
                if cur:
                    runs.append(cur)
                ow = tags.get("oneway")
                oneway = 1 if ow in ("yes", "1", "true") else -1 if ow == "-1" else 0
                if tags.get("junction") in ("roundabout", "circular") and ow != "no":
                    oneway = oneway or 1
                for run in runs:
                    road = {
                        "c": tags["highway"],
                        "v": [node_id(nodes[i]) for i in run],
                        "p": flat(proj(*g[i]) for i in run),
                    }
                    if tags.get("name"):
                        road["n"] = tags["name"]
                    if tags.get("ref"):
                        road["ref"] = tags["ref"]
                    if oneway:
                        road["o"] = oneway
                    if tags.get("junction") in ("roundabout", "circular"):
                        road["rb"] = 1
                    if tags.get("access") in ("private", "no"):
                        road["a"] = "prive"
                    if tags.get("surface"):
                        road["s"] = tags["surface"]
                    if tags.get("lanes", "").isdigit():
                        road["l"] = int(tags["lanes"])
                    roads.append(road)
            elif not any_inside:
                continue
            elif "building" in tags and len(g) > 2:
                buildings.append(flat(proj(*p) for p in g))
            elif "landuse" in tags and len(g) > 2:
                areas.append({"k": tags["landuse"], "p": flat(proj(*p) for p in g)})
            elif tags.get("natural") == "water" and len(g) > 2:
                water.append({"area": 1, "p": flat(proj(*p) for p in g)})
            elif "waterway" in tags:
                water.append({"p": flat(proj(*p) for p in g)})
            elif "railway" in tags:
                rail.append(flat(proj(*p) for p in g))
        elif t == "relation" and "landuse" in tags:
            for m in el.get("members", []):
                g = [(p["lat"], p["lon"]) for p in m.get("geometry") or [] if p]
                if m.get("role") == "outer" and len(g) > 2 and any(inside(*p) for p in g):
                    areas.append({"k": tags["landuse"], "p": flat(proj(*p) for p in g)})
        elif t == "node" and tags.get("barrier") in ("gate", "lift_gate") and inside(el["lat"], el["lon"]):
            gates.append(list(proj(el["lat"], el["lon"])))

    if not roads:
        die("aucune route dans l'emprise : relancez ./map.sh fetch")

    # ---- destinations ----
    places, seen = [], set()
    for i, lieu in enumerate(lieux.get("lieux", [])):
        where = "lieux.json, entrée %d (%s)" % (i + 1, lieu.get("id", "sans id"))
        for k in ("id", "nom", "categorie", "lat", "lon"):
            if k not in lieu:
                die("%s : champ « %s » manquant" % (where, k))
        if lieu["id"] in seen:
            die("%s : id en double" % where)
        seen.add(lieu["id"])
        if lieu["categorie"] not in CATEGORIES:
            die("%s : catégorie « %s » inconnue (attendu : %s)"
                % (where, lieu["categorie"], ", ".join(sorted(CATEGORIES))))
        if not all(isinstance(lieu[k], (int, float)) for k in ("lat", "lon")):
            die("%s : lat et lon doivent être des nombres" % where)
        if not inside(lieu["lat"], lieu["lon"]):
            die("%s : position hors de la carte (%.5f, %.5f) — emprise %s"
                % (where, lieu["lat"], lieu["lon"], zone["bbox"]))
        x, y = proj(lieu["lat"], lieu["lon"])
        place = {"id": lieu["id"], "name": lieu["nom"], "cat": lieu["categorie"], "x": x, "y": y}
        if lieu.get("note"):
            place["note"] = lieu["note"]
        places.append(place)

    x0, y0 = proj(s, w)
    x1, y1 = proj(n, e)
    out = {
        "format": 1,
        "name": "Zone industrielle de Glo-Djigbé",
        "origin": [proj.lat0, proj.lon0],
        "metersPerDegree": [round(proj.ky, 3), round(proj.kx, 3)],
        "extent": [x0, y0, x1, y1],
        "osmTimestamp": (data.get("osm3s") or {}).get("timestamp_osm_base", ""),
        "built": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "attribution": "© contributeurs OpenStreetMap",
        "nodeCount": len(node_index),
        "zone": flat(zone_outline),
        "areas": areas,
        "water": water,
        "rail": rail,
        "buildings": buildings,
        "roads": roads,
        "gates": gates,
        "places": places,
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    drivable = sum(1 for r in roads if r["c"] in DRIVABLE)
    print("carte : %d routes (%d roulables), %d bâtiments, %d zones, %d portes, %d destinations, "
          "%d nœuds → %s"
          % (len(roads), drivable, len(buildings), len(areas), len(gates), len(places),
             len(node_index), out_path))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    main(*sys.argv[1:])
