#!/usr/bin/env python3
"""Lecture des extraits OpenStreetMap de la GDIZ, pour map.sh.

    osm_tool.py candidates locate.json      choisit la zone, écrit son emprise
    osm_tool.py report gdiz.osm.json DIR    rapport.txt + apercu.svg dans DIR

Bibliothèque standard seulement : rien à installer.

Le rapport répond à une seule question : les données suffisent-elles pour une
carte qui trace un itinéraire ? D'où ce qu'il mesure — longueur de routes
roulables, part du réseau d'un seul tenant (un itinéraire ne passe pas d'un
morceau à l'autre), lieux nommés (ce sont eux, les destinations).
"""

import json
import math
import sys
from collections import Counter, defaultdict

# Routes sur lesquelles la navette peut rouler. « track » (piste) en fait
# partie : dans une zone en construction, beaucoup de voies y sont encore
# classées. Les chemins piétons, non.
DRIVABLE = {
    "motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
    "secondary", "secondary_link", "tertiary", "tertiary_link", "unclassified",
    "residential", "living_street", "service", "road", "track",
}

# Hiérarchie pour l'aperçu : plus la route est importante, plus le trait est
# large et clair.
ROAD_STYLE = {
    "motorway": (5, "#f2c14e"), "trunk": (5, "#f2c14e"), "primary": (4.5, "#f2c14e"),
    "secondary": (4, "#e8e8e8"), "tertiary": (3.5, "#e8e8e8"),
    "unclassified": (2.6, "#c8ccd4"), "residential": (2.6, "#c8ccd4"),
    "living_street": (2.4, "#c8ccd4"), "road": (2.4, "#c8ccd4"),
    "service": (1.6, "#9aa3b2"), "track": (1.4, "#b08d5a"),
}
LANDUSE_FILL = {
    "industrial": "#3a2f4f", "commercial": "#4f3a3a", "retail": "#4f3a3a",
    "residential": "#2f4f45", "construction": "#4a4a3a", "railway": "#3a3a3a",
    "farmland": "#2a3a25", "grass": "#25402c", "forest": "#1f3a24",
}

KM_PER_DEG_LAT = 111.32


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        die("Lecture impossible de %s : %s" % (path, e))


def haversine_km(a, b):
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 2 * 6371.0 * math.asin(math.sqrt(h))


def geom(el):
    return [(p["lat"], p["lon"]) for p in el.get("geometry") or [] if p]


def length_km(points):
    return sum(haversine_km(points[i], points[i + 1]) for i in range(len(points) - 1))


def area_km2(points):
    """Aire d'un polygone, en projection locale : exacte à mieux que 1 % à
    l'échelle d'une zone de quelques kilomètres."""
    if len(points) < 3:
        return 0.0
    lat0 = sum(p[0] for p in points) / len(points)
    kx = KM_PER_DEG_LAT * math.cos(math.radians(lat0))
    xy = [(p[1] * kx, p[0] * KM_PER_DEG_LAT) for p in points]
    s = 0.0
    for i in range(len(xy)):
        x1, y1 = xy[i]
        x2, y2 = xy[(i + 1) % len(xy)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


# ------------------------------------------------------------ candidates ----
def candidates(path):
    data = load(path)
    found = []
    for el in data.get("elements", []):
        tags = el.get("tags", {})
        name = tags.get("name") or tags.get("operator") or "(sans nom)"
        low = (name + " " + tags.get("operator", "")).lower()
        b = el.get("bounds")
        if b:
            box = (b["minlat"], b["minlon"], b["maxlat"], b["maxlon"])
        elif "lat" in el:
            box = None
        else:
            continue
        lat = el.get("lat", (box[0] + box[2]) / 2 if box else 0)
        lon = el.get("lon", (box[1] + box[3]) / 2 if box else 0)
        area = 0.0
        if box:
            w = haversine_km((lat, box[1]), (lat, box[3]))
            h = haversine_km((box[0], lon), (box[2], lon))
            area = w * h

        # Ce qui ressemble à la zone industrielle elle-même passe devant le
        # village du même nom, qui ne sert qu'en dernier recours.
        score = 0
        kind = tags.get("landuse") or tags.get("place") or tags.get("amenity") \
            or tags.get("industrial") or tags.get("boundary") or el["type"]
        if tags.get("landuse") == "industrial" or "industrial" in tags:
            score += 5
        if "gdiz" in low:
            score += 4
        if "industrial zone" in low or "zone industrielle" in low or "zone économique" in low:
            score += 3
        if 2 <= area <= 40:
            score += 3
        if "place" in tags:
            score += 1
        found.append({"score": score, "name": name, "kind": kind, "type": el["type"],
                      "id": el["id"], "lat": lat, "lon": lon, "box": box, "area": area})

    if not found:
        die("Aucun objet nommé « GDIZ » ou « Glo-Djigbé » trouvé dans OpenStreetMap.\n"
            "Donnez l'emprise à la main :  ./map.sh fetch --bbox SUD,OUEST,NORD,EST")

    found.sort(key=lambda c: (-c["score"], -c["area"]))
    print("Candidats trouvés dans OpenStreetMap (le premier est retenu) :", file=sys.stderr)
    for c in found[:12]:
        size = "%.1f km²" % c["area"] if c["box"] else "point"
        print("  [%2d] %-45s %-12s %-9s %s  (%.5f, %.5f)  osm:%s/%s"
              % (c["score"], c["name"][:45], c["kind"][:12], size, "", c["lat"], c["lon"],
                 c["type"], c["id"]), file=sys.stderr)

    best = found[0]
    if best["box"] and best["area"] >= 0.5:
        s, w, n, e = best["box"]
    else:
        # Un simple point : on prend 3 km autour. Assez pour 1 640 ha.
        dlat = 3 / KM_PER_DEG_LAT
        dlon = 3 / (KM_PER_DEG_LAT * math.cos(math.radians(best["lat"])))
        s, w, n, e = best["lat"] - dlat, best["lon"] - dlon, best["lat"] + dlat, best["lon"] + dlon
        print("  → le candidat retenu est un point : emprise de 6 × 6 km autour.", file=sys.stderr)

    # Marge de 1,5 km : les accès (RNIE2) et l'environnement immédiat.
    lat = (s + n) / 2
    m_lat = 1.5 / KM_PER_DEG_LAT
    m_lon = 1.5 / (KM_PER_DEG_LAT * math.cos(math.radians(lat)))
    s, w, n, e = s - m_lat, w - m_lon, n + m_lat, e + m_lon
    width = haversine_km((lat, w), (lat, e))
    height = haversine_km((s, w), (n, w))
    if width > 20 or height > 20:
        die("L'emprise retenue fait %.0f × %.0f km : trop grande, ce n'est sans doute pas "
            "la zone.\nDonnez-la à la main :  ./map.sh fetch --bbox SUD,OUEST,NORD,EST" % (width, height))
    print("Emprise retenue, marge de 1,5 km comprise : %.1f × %.1f km" % (width, height), file=sys.stderr)
    print(json.dumps({"bbox": [round(v, 6) for v in (s, w, n, e)], "from": best}, ensure_ascii=False))


# ---------------------------------------------------------------- report ----
class Components:
    def __init__(self):
        self.parent = {}

    def find(self, x):
        self.parent.setdefault(x, x)
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[ra] = rb


def report(path, outdir):
    data = load(path)
    elements = data.get("elements", [])
    stamp = (data.get("osm3s") or {}).get("timestamp_osm_base", "inconnue")

    roads = []          # (type, points, tags, nodes)
    buildings = []
    landuse = []        # (type, points, tags)
    pois = []           # (name, kind, lat, lon)
    gates = []
    other_lines = []    # railways, waterways

    for el in elements:
        tags = el.get("tags", {})
        t = el["type"]
        if t == "way":
            pts = geom(el)
            if "highway" in tags:
                roads.append((tags["highway"], pts, tags, el.get("nodes", [])))
            elif "building" in tags:
                buildings.append((pts, tags))
            elif "landuse" in tags:
                landuse.append((tags["landuse"], pts, tags))
            elif "railway" in tags or "waterway" in tags:
                other_lines.append((pts, tags))
            if "barrier" in tags and tags["barrier"] in ("gate", "lift_gate", "entrance"):
                if pts:
                    gates.append((tags.get("name", ""), pts[0][0], pts[0][1]))
        elif t == "relation" and "landuse" in tags:
            for m in el.get("members", []):
                if m.get("role") == "outer" and m.get("geometry"):
                    landuse.append((tags["landuse"], geom(m), tags))
        elif t == "node":
            if tags.get("barrier") in ("gate", "lift_gate") or "entrance" in tags:
                gates.append((tags.get("name", ""), el["lat"], el["lon"]))

        # Les lieux nommés — usines, bureaux, services : les futures destinations.
        name = tags.get("name")
        if name and "highway" not in tags:
            kind = next((k + "=" + tags[k] for k in ("amenity", "office", "industrial", "shop",
                                                      "building", "landuse", "place", "barrier",
                                                      "man_made", "public_transport")
                         if k in tags), "?")
            if t == "node":
                lat, lon = el["lat"], el["lon"]
            else:
                pts = geom(el) or [p for m in el.get("members", []) for p in geom(m)]
                if not pts:
                    continue
                lat = sum(p[0] for p in pts) / len(pts)
                lon = sum(p[1] for p in pts) / len(pts)
            pois.append((name, kind, lat, lon))

    # ---- routes ----
    per_type = defaultdict(lambda: [0, 0.0])
    names = Counter()
    surface = Counter()
    oneway = 0
    comp = Components()
    edge_len = []
    for kind, pts, tags, nodes in roads:
        km = length_km(pts)
        per_type[kind][0] += 1
        per_type[kind][1] += km
        if kind not in DRIVABLE:
            continue
        if tags.get("name"):
            names[tags["name"]] += 1
        surface[tags.get("surface", "non renseignée")] += km
        if tags.get("oneway") in ("yes", "1", "-1"):
            oneway += 1
        for i in range(len(nodes) - 1):
            comp.union(nodes[i], nodes[i + 1])
        if nodes:
            edge_len.append((nodes[0], km))

    drivable_km = sum(v[1] for k, v in per_type.items() if k in DRIVABLE)
    by_comp = defaultdict(float)
    for first, km in edge_len:
        by_comp[comp.find(first)] += km
    pieces = sorted(by_comp.values(), reverse=True)
    main_share = pieces[0] / drivable_km if drivable_km and pieces else 0.0

    # ---- rapport ----
    L = []
    bb = bounds(elements)
    L.append("RAPPORT DES DONNÉES OPENSTREETMAP — GDIZ")
    L.append("Fichier : %s" % path)
    L.append("Données OSM du : %s" % stamp)
    if bb:
        lat = (bb[0] + bb[2]) / 2
        L.append("Emprise : %.5f,%.5f → %.5f,%.5f  (%.1f × %.1f km)"
                 % (bb[0], bb[1], bb[2], bb[3], haversine_km((lat, bb[1]), (lat, bb[3])),
                    haversine_km((bb[0], bb[1]), (bb[2], bb[1]))))
    L.append("Objets : %d" % len(elements))
    L.append("")
    L.append("ROUTES (par type OSM)")
    for kind, (n, km) in sorted(per_type.items(), key=lambda kv: -kv[1][1]):
        L.append("  %-16s %4d tronçons  %7.2f km%s" % (kind, n, km, "" if kind in DRIVABLE else "   (non roulable)"))
    L.append("  → roulable : %.1f km" % drivable_km)
    L.append("  → d'un seul tenant : %.0f %% (réseau principal), %d morceaux au total"
             % (main_share * 100, len(pieces)))
    L.append("  → sens unique : %d tronçons" % oneway)
    L.append("  → revêtement : " + ", ".join("%s %.1f km" % (k, v) for k, v in surface.most_common(6)))
    L.append("  → rues nommées (%d) : %s" % (len(names), ", ".join(sorted(names)[:40]) or "aucune"))
    L.append("")
    L.append("BÂTIMENTS : %d, dont %d nommés" % (len(buildings), sum(1 for _, t in buildings if t.get("name"))))
    L.append("")
    L.append("OCCUPATION DU SOL")
    lu = defaultdict(float)
    for kind, pts, _ in landuse:
        lu[kind] += area_km2(pts)
    for kind, a in sorted(lu.items(), key=lambda kv: -kv[1]):
        L.append("  %-16s %7.2f km²" % (kind, a))
    if not lu:
        L.append("  aucune")
    L.append("")
    L.append("PORTES / ENTRÉES : %d" % len(gates))
    for name, la, lo in gates[:20]:
        L.append("  %-40s (%.5f, %.5f)" % (name or "(sans nom)", la, lo))
    L.append("")
    L.append("LIEUX NOMMÉS — destinations possibles : %d" % len(pois))
    for name, kind, la, lo in sorted(pois)[:80]:
        L.append("  %-45s %-28s (%.5f, %.5f)" % (name[:45], kind[:28], la, lo))
    if len(pois) > 80:
        L.append("  … et %d autres" % (len(pois) - 80))
    L.append("")
    L.append("VERDICT")
    verdict = []
    if drivable_km < 10:
        verdict.append("× Peu de routes (%.1f km) : la zone est mal cartographiée dans OSM. "
                       "Il faudra compléter (plan officiel, relevé GPS sur place)." % drivable_km)
    else:
        verdict.append("✓ Réseau routier présent : %.1f km roulables." % drivable_km)
    if main_share < 0.8:
        verdict.append("× Réseau morcelé (%.0f %% d'un seul tenant) : certains trajets seront "
                       "impossibles à calculer tant que les raccords manquent." % (main_share * 100))
    else:
        verdict.append("✓ Réseau d'un seul tenant à %.0f %% : les itinéraires se calculent." % (main_share * 100))
    if len(pois) < 10:
        verdict.append("× Peu de lieux nommés (%d) : les destinations devront être ajoutées "
                       "par l'équipe (usines, portes, logements…)." % len(pois))
    else:
        verdict.append("✓ %d lieux nommés pour servir de destinations." % len(pois))
    if not gates:
        verdict.append("· Aucune porte d'entrée cartographiée.")
    L.extend("  " + v for v in verdict)
    L.append("")
    L.append("Données © contributeurs OpenStreetMap, licence ODbL — openstreetmap.org/copyright")

    with open(outdir + "/rapport.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    svg(outdir + "/apercu.svg", bb, roads, buildings, landuse, gates, pois, other_lines)
    print("\n".join(L))


def bounds(elements):
    lats, lons = [], []
    for el in elements:
        if "lat" in el:
            lats.append(el["lat"]); lons.append(el["lon"])
        for p in el.get("geometry") or []:
            if p:
                lats.append(p["lat"]); lons.append(p["lon"])
    if not lats:
        return None
    return min(lats), min(lons), max(lats), max(lons)


def svg(path, bb, roads, buildings, landuse, gates, pois, other_lines):
    if not bb:
        return
    s, w, n, e = bb
    lat0 = (s + n) / 2
    kx = math.cos(math.radians(lat0))
    W = 1400.0
    H = W * (n - s) / ((e - w) * kx) if e > w else W
    sx = W / (e - w)
    sy = H / (n - s) if n > s else 1

    def xy(p):
        return "%.1f,%.1f" % ((p[1] - w) * sx, (n - p[0]) * sy)

    def poly(pts):
        return " ".join(xy(p) for p in pts)

    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
           % (W, H + 40, W, H + 40),
           '<rect width="100%" height="100%" fill="#0b0f17"/>']
    for kind, pts, _ in landuse:
        if len(pts) > 2:
            out.append('<polygon points="%s" fill="%s" fill-opacity="0.8"/>'
                       % (poly(pts), LANDUSE_FILL.get(kind, "#2a2f3a")))
    for pts, tags in other_lines:
        color = "#3a6ea5" if "waterway" in tags else "#777"
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="1.5" stroke-dasharray="6 4"/>'
                   % (poly(pts), color))
    for pts, _ in buildings:
        if len(pts) > 2:
            out.append('<polygon points="%s" fill="#3d4656" stroke="#566174" stroke-width="0.5"/>' % poly(pts))
    order = sorted(roads, key=lambda r: ROAD_STYLE.get(r[0], (1, ""))[0])
    for kind, pts, _, _ in order:
        width, color = ROAD_STYLE.get(kind, (1, "#556"))
        dash = "" if kind in DRIVABLE else ' stroke-dasharray="3 3"'
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="%.1f" '
                   'stroke-linecap="round" stroke-linejoin="round"%s/>' % (poly(pts), color, width, dash))
    for name, la, lo in gates:
        x, y = xy((la, lo)).split(",")
        out.append('<circle cx="%s" cy="%s" r="5" fill="#e5484d"/>' % (x, y))
    for name, kind, la, lo in pois:
        x, y = xy((la, lo)).split(",")
        out.append('<circle cx="%s" cy="%s" r="3" fill="#2ec4b6"/>' % (x, y))
        out.append('<text x="%.1f" y="%.1f" font-family="sans-serif" font-size="11" fill="#cfe">%s</text>'
                   % (float(x) + 5, float(y) - 4, esc(name[:40])))
    # Échelle : 1 km.
    px_km = sx / (KM_PER_DEG_LAT * kx)
    out.append('<line x1="20" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#fff" stroke-width="3"/>'
               % (H + 22, 20 + px_km, H + 22))
    out.append('<text x="20" y="%.1f" font-family="sans-serif" font-size="12" fill="#fff">1 km</text>' % (H + 16))
    out.append('<text x="%.1f" y="%.1f" text-anchor="end" font-family="sans-serif" font-size="12" '
               'fill="#aaa">© contributeurs OpenStreetMap</text>' % (W - 12, H + 28))
    out.append("</svg>")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out))


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "candidates":
        candidates(sys.argv[2])
    elif len(sys.argv) == 4 and sys.argv[1] == "report":
        report(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(2)
