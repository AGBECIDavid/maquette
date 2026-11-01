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


def point_in(poly, p):
    """Le point est-il dans le polygone ? Lancer de rayon, en degrés : à cette
    échelle la courbure n'a aucun effet."""
    lat, lon = p
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        yi, xi = poly[i]
        yj, xj = poly[j]
        if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def centroid(pts):
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def zone_outline(elements, ref):
    """Le contour de la GDIZ, tel qu'OSM le connaît : l'objet retenu par la
    recherche. Pour une relation, son plus grand anneau extérieur."""
    if not isinstance(ref, dict):
        return None, None
    for el in elements:
        if el["type"] == ref.get("type") and el["id"] == ref.get("id"):
            if el["type"] == "way":
                return geom(el), el.get("tags", {}).get("name")
            rings = [geom(m) for m in el.get("members", []) if m.get("role") == "outer"]
            rings = [r for r in rings if len(r) > 2]
            if rings:
                return max(rings, key=area_km2), el.get("tags", {}).get("name")
    return None, None


def report(path, outdir):
    data = load(path)
    elements = data.get("elements", [])
    stamp = (data.get("osm3s") or {}).get("timestamp_osm_base", "inconnue")
    zone = load(outdir + "/zone.json")
    s, w, n, e = zone["bbox"]
    outline, zone_name = zone_outline(elements, zone.get("from"))

    # Overpass rend chaque route en entier dès qu'un bout touche l'emprise :
    # la RNIE 2 arrive avec ses 30 km. Tout est donc ramené à deux lieux —
    # « zone », dans le contour de la GDIZ, et « autour », dans l'emprise mais
    # hors du contour. Le reste est ignoré : la carte ne l'affichera pas.
    def where(p):
        if not (s <= p[0] <= n and w <= p[1] <= e):
            return None
        if outline and point_in(outline, p):
            return "zone"
        return "autour"

    roads, buildings, landuse, other_lines = [], [], [], []
    gates = {"zone": [], "autour": []}
    pois = {"zone": [], "autour": []}
    dropped_pois = 0

    for el in elements:
        tags = el.get("tags", {})
        t = el["type"]
        pts = geom(el) if t == "way" else []
        if t == "way":
            if "highway" in tags:
                roads.append((tags["highway"], pts, tags, el.get("nodes", [])))
            elif "building" in tags and len(pts) > 2:
                buildings.append((pts, tags, where(centroid(pts))))
            elif "landuse" in tags and len(pts) > 2:
                landuse.append((tags["landuse"], pts, tags, where(centroid(pts))))
            elif "railway" in tags or "waterway" in tags:
                other_lines.append((pts, tags))
            if tags.get("barrier") in ("gate", "lift_gate") and pts:
                place = where(pts[0])
                if place:
                    gates[place].append((tags.get("name", ""), pts[0][0], pts[0][1]))
        elif t == "relation" and "landuse" in tags:
            for m in el.get("members", []):
                ring = geom(m)
                if m.get("role") == "outer" and len(ring) > 2:
                    landuse.append((tags["landuse"], ring, tags, where(centroid(ring))))
        elif t == "node" and (tags.get("barrier") in ("gate", "lift_gate") or "entrance" in tags):
            place = where((el["lat"], el["lon"]))
            if place:
                gates[place].append((tags.get("name", ""), el["lat"], el["lon"]))

        # Les lieux nommés — usines, bureaux, services : les futures destinations.
        # Les limites administratives (communes entières) n'en sont pas.
        name = tags.get("name")
        ref = zone.get("from") if isinstance(zone.get("from"), dict) else {}
        is_zone = t == ref.get("type") and el["id"] == ref.get("id")
        if name and not is_zone and "highway" not in tags and "boundary" not in tags \
                and tags.get("type") != "boundary":
            kind = next((k + "=" + tags[k] for k in ("amenity", "office", "industrial", "shop",
                                                      "building", "landuse", "place", "barrier",
                                                      "man_made", "public_transport", "craft")
                         if k in tags), "?")
            if t == "node":
                p = (el["lat"], el["lon"])
            else:
                ring = pts or [q for m in el.get("members", []) for q in geom(m)]
                if not ring:
                    continue
                p = centroid(ring)
            place = where(p)
            if place:
                pois[place].append((name, kind, p[0], p[1]))
            else:
                dropped_pois += 1

    # ---- routes, découpées tronçon par tronçon ----
    km = {"zone": defaultdict(float), "autour": defaultdict(float)}
    surface = Counter()
    names = {"zone": Counter(), "autour": Counter()}
    oneway = 0
    comp = Components()
    seg_km = []         # (premier nœud, km, lieu) des tronçons roulables gardés
    for kind, pts, tags, nodes in roads:
        same = len(nodes) == len(pts)
        for i in range(len(pts) - 1):
            mid = ((pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2)
            place = where(mid)
            if not place:
                continue
            d = haversine_km(pts[i], pts[i + 1])
            km[place][kind] += d
            if kind not in DRIVABLE:
                continue
            if tags.get("name"):
                names[place][tags["name"]] += 1
            if place == "zone":
                surface[tags.get("surface", "non renseignée")] += d
            if same:
                comp.union(nodes[i], nodes[i + 1])
                seg_km.append((nodes[i], d, place))
        if kind in DRIVABLE and tags.get("oneway") in ("yes", "1", "-1") \
                and any(where(p) for p in pts):
            oneway += 1

    drive = {p: sum(v for k, v in km[p].items() if k in DRIVABLE) for p in km}
    # Morceaux du réseau gardé (zone + autour) : un itinéraire ne passe pas de
    # l'un à l'autre. La part qui compte est celle des routes de la zone.
    by_comp = defaultdict(lambda: [0.0, 0.0])
    for first, d, place in seg_km:
        c = by_comp[comp.find(first)]
        c[0] += d
        if place == "zone":
            c[1] += d
    pieces = sorted(by_comp.values(), key=lambda c: -c[0])
    main_share_zone = pieces[0][1] / drive["zone"] if pieces and drive["zone"] else 0.0
    zone_pieces = sum(1 for c in pieces if c[1] > 0)

    # ---- rapport ----
    lat0 = (s + n) / 2
    L = []
    L.append("RAPPORT DES DONNÉES OPENSTREETMAP — GDIZ")
    L.append("Données OSM du : %s" % stamp)
    L.append("Emprise : %.5f,%.5f → %.5f,%.5f  (%.1f × %.1f km)"
             % (s, w, n, e, haversine_km((lat0, w), (lat0, e)), haversine_km((s, w), (n, w))))
    if outline:
        L.append("Contour de la zone : « %s », %.2f km² (%d points)  — chiffre officiel : 16,4 km²"
                 % (zone_name or "?", area_km2(outline), len(outline)))
    else:
        L.append("Contour de la zone : introuvable — tout est compté comme « autour »")
    L.append("« zone » = dans le contour ; « autour » = dans l'emprise, hors du contour.")
    L.append("")
    L.append("ROUTES (km, par type OSM)             zone    autour")
    kinds = sorted(set(km["zone"]) | set(km["autour"]), key=lambda k: -(km["zone"][k] + km["autour"][k]))
    for k in kinds:
        L.append("  %-16s                   %7.2f   %7.2f%s"
                 % (k, km["zone"][k], km["autour"][k], "" if k in DRIVABLE else "   (non roulable)"))
    L.append("  → roulable                         %7.2f   %7.2f" % (drive["zone"], drive["autour"]))
    L.append("  → routes de la zone d'un seul tenant : %.0f %% (%d morceaux touchent la zone)"
             % (main_share_zone * 100, zone_pieces))
    L.append("  → sens unique : %d tronçons" % oneway)
    L.append("  → revêtement dans la zone : "
             + (", ".join("%s %.1f km" % (k, v) for k, v in surface.most_common(6)) or "—"))
    L.append("  → rues nommées dans la zone (%d) : %s"
             % (len(names["zone"]), ", ".join(sorted(names["zone"])) or "aucune"))
    L.append("  → rues nommées autour (%d) : %s"
             % (len(names["autour"]), ", ".join(sorted(names["autour"])[:30]) or "aucune"))
    L.append("")
    bz = [b for b in buildings if b[2] == "zone"]
    ba = [b for b in buildings if b[2] == "autour"]
    L.append("BÂTIMENTS : %d dans la zone (%d nommés), %d autour"
             % (len(bz), sum(1 for b in bz if b[1].get("name")), len(ba)))
    types = Counter(b[1].get("building") for b in bz)
    if types:
        L.append("  types dans la zone : " + ", ".join("%s %d" % kv for kv in types.most_common(6)))
    L.append("")
    L.append("OCCUPATION DU SOL (km²)              zone    autour")
    lu = {"zone": defaultdict(float), "autour": defaultdict(float)}
    for kind, pts, tags, place in landuse:
        if place and pts != outline:
            lu[place][kind] += area_km2(pts)
    for k in sorted(set(lu["zone"]) | set(lu["autour"]), key=lambda k: -(lu["zone"][k] + lu["autour"][k])):
        L.append("  %-16s                   %7.2f   %7.2f" % (k, lu["zone"][k], lu["autour"][k]))
    L.append("")
    L.append("PORTES : %d dans la zone, %d autour" % (len(gates["zone"]), len(gates["autour"])))
    for name, la, lo in gates["zone"]:
        L.append("  %-40s (%.5f, %.5f)" % (name or "(sans nom)", la, lo))
    L.append("")
    L.append("LIEUX NOMMÉS DANS LA ZONE — destinations : %d" % len(pois["zone"]))
    for name, kind, la, lo in sorted(pois["zone"]):
        L.append("  %-45s %-28s (%.5f, %.5f)" % (name[:45], kind[:28], la, lo))
    L.append("LIEUX NOMMÉS AUTOUR : %d   (hors emprise, ignorés : %d)" % (len(pois["autour"]), dropped_pois))
    for name, kind, la, lo in sorted(pois["autour"])[:60]:
        L.append("  %-45s %-28s (%.5f, %.5f)" % (name[:45], kind[:28], la, lo))
    if len(pois["autour"]) > 60:
        L.append("  … et %d autres" % (len(pois["autour"]) - 60))
    L.append("")

    L.append("VERDICT")
    v = []
    if outline and area_km2(outline) < 0.8 * 16.4:
        v.append("· Le contour OSM (%.1f km²) est plus petit que la zone officielle (16,4 km²) : "
                 "une partie de la GDIZ n'y figure pas encore." % area_km2(outline))
    if drive["zone"] < 10:
        v.append("× Peu de routes dans la zone (%.1f km) : il faudra compléter "
                 "(plan officiel, relevé GPS sur place)." % drive["zone"])
    else:
        v.append("✓ %.1f km de routes roulables dans la zone." % drive["zone"])
    if drive["zone"] and main_share_zone < 0.8:
        v.append("× Routes de la zone morcelées (%.0f %% d'un seul tenant) : certains trajets "
                 "seront impossibles tant que les raccords manquent." % (main_share_zone * 100))
    elif drive["zone"]:
        v.append("✓ Routes de la zone d'un seul tenant à %.0f %% : les itinéraires se calculent."
                 % (main_share_zone * 100))
    if not names["zone"]:
        v.append("· Aucune rue nommée dans la zone : le guidage parlera en repères "
                 "(« tournez à droite vers la porte 2 »), pas en noms de rue.")
    if len(pois["zone"]) < 10:
        v.append("× %d lieu(x) nommé(s) dans la zone : les destinations (usines, portes, "
                 "logements…) devront être ajoutées par l'équipe." % len(pois["zone"]))
    else:
        v.append("✓ %d lieux nommés dans la zone pour servir de destinations." % len(pois["zone"]))
    L.extend("  " + x for x in v)
    L.append("")
    L.append("Données © contributeurs OpenStreetMap, licence ODbL — openstreetmap.org/copyright")

    with open(outdir + "/rapport.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    svg(outdir + "/apercu.svg", (s, w, n, e), outline, roads, buildings, landuse, gates, pois, other_lines)
    print("\n".join(L))


def svg(path, bb, outline, roads, buildings, landuse, gates, pois, other_lines):
    s, w, n, e = bb
    lat0 = (s + n) / 2
    kx = math.cos(math.radians(lat0))
    W = 1400.0
    H = W * (n - s) / ((e - w) * kx)
    sx = W / (e - w)
    sy = H / (n - s)

    def xy(p):
        return ((p[1] - w) * sx, (n - p[0]) * sy)

    def poly(pts):
        return " ".join("%.1f,%.1f" % xy(p) for p in pts)

    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
           % (W, H + 40, W, H + 40),
           '<defs><clipPath id="c"><rect width="%d" height="%d"/></clipPath></defs>' % (W, H),
           '<rect width="100%" height="100%" fill="#0b0f17"/>',
           '<g clip-path="url(#c)">']
    for kind, pts, _, _ in landuse:
        if pts != outline:
            out.append('<polygon points="%s" fill="%s" fill-opacity="0.8"/>'
                       % (poly(pts), LANDUSE_FILL.get(kind, "#2a2f3a")))
    if outline:
        out.append('<polygon points="%s" fill="#2ec4b6" fill-opacity="0.07" stroke="#2ec4b6" '
                   'stroke-width="2.5" stroke-dasharray="10 6"/>' % poly(outline))
    for pts, tags in other_lines:
        color = "#3a6ea5" if "waterway" in tags else "#777"
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="1.5" stroke-dasharray="6 4"/>'
                   % (poly(pts), color))
    for pts, _, _ in buildings:
        out.append('<polygon points="%s" fill="#3d4656" stroke="#566174" stroke-width="0.5"/>' % poly(pts))
    for kind, pts, _, _ in sorted(roads, key=lambda r: ROAD_STYLE.get(r[0], (1, ""))[0]):
        width, color = ROAD_STYLE.get(kind, (1, "#556"))
        dash = "" if kind in DRIVABLE else ' stroke-dasharray="3 3"'
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="%.1f" '
                   'stroke-linecap="round" stroke-linejoin="round"%s/>' % (poly(pts), color, width, dash))
    for place in ("zone", "autour"):
        for name, la, lo in gates[place]:
            out.append('<circle cx="%.1f" cy="%.1f" r="5" fill="#e5484d"/>' % xy((la, lo)))
    for place, color in (("autour", "#7f8ea3"), ("zone", "#2ec4b6")):
        for name, kind, la, lo in pois[place]:
            x, y = xy((la, lo))
            out.append('<circle cx="%.1f" cy="%.1f" r="3" fill="%s"/>' % (x, y, color))
            if place == "zone":
                out.append('<text x="%.1f" y="%.1f" font-family="sans-serif" font-size="12" '
                           'fill="#dff">%s</text>' % (x + 5, y - 4, esc(name[:40])))
    out.append("</g>")
    px_km = sx / (KM_PER_DEG_LAT * kx)
    out.append('<line x1="20" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#fff" stroke-width="3"/>'
               % (H + 22, 20 + px_km, H + 22))
    out.append('<text x="20" y="%.1f" font-family="sans-serif" font-size="12" fill="#fff">1 km</text>' % (H + 16))
    out.append('<text x="%.1f" y="%.1f" font-family="sans-serif" font-size="12" fill="#2ec4b6">'
               '- - contour GDIZ   ● portes (rouge)   ● lieux nommés</text>' % (40 + px_km, H + 28))
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
