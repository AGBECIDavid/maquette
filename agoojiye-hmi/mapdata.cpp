#include "mapdata.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QtMath>
#include <algorithm>
#include <queue>

namespace {

constexpr double kInf = std::numeric_limits<double>::infinity();

// Allure de calcul par type de route, km/h. Une navette de zone industrielle
// plafonne bien en dessous des limites légales : ces valeurs donnent des
// durées réalistes, pas des vitesses autorisées.
double classSpeed(const QString &cls)
{
    static const QHash<QString, double> speeds = {
        { "motorway", 50 }, { "trunk", 50 }, { "primary", 50 }, { "secondary", 45 },
        { "tertiary", 40 }, { "unclassified", 30 }, { "residential", 25 },
        { "living_street", 15 }, { "service", 20 }, { "road", 25 }, { "track", 15 },
    };
    QString base = cls;
    if (base.endsWith(QLatin1String("_link")))
        return 35;
    return speeds.value(base, 20);
}

int classRank(const QString &cls)
{
    static const QStringList order = { "track", "service", "living_street", "residential",
                                       "unclassified", "road", "tertiary", "secondary",
                                       "primary", "trunk", "motorway" };
    QString base = cls;
    base.remove(QLatin1String("_link"));
    return qMax(0, order.indexOf(base));
}

bool isDrivable(const QString &cls)
{
    static const QSet<QString> set = {
        "motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
        "secondary", "secondary_link", "tertiary", "tertiary_link", "unclassified",
        "residential", "living_street", "service", "road", "track",
    };
    return set.contains(cls);
}

QPolygonF readFlat(const QJsonValue &v)
{
    const QJsonArray a = v.toArray();
    QPolygonF poly;
    poly.reserve(a.size() / 2);
    for (int i = 0; i + 1 < a.size(); i += 2)
        poly << QPointF(a[i].toDouble(), a[i + 1].toDouble());
    return poly;
}

double dist(const QPointF &a, const QPointF &b)
{
    return std::hypot(a.x() - b.x(), a.y() - b.y());
}

// Projection du point p sur le segment [a, b] : paramètre 0..1.
double project(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double l2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (l2 < 1e-9)
        return 0;
    return std::clamp(((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / l2, 0.0, 1.0);
}

QString ordinal(int n)
{
    return n == 1 ? QStringLiteral("1ʳᵉ") : QString::number(n) + QStringLiteral("ᵉ");
}

// Point situé à `d` mètres du point i, en avançant (dir = +1) ou en reculant
// (dir = -1) le long du tracé. Mesurer un angle sur 15 m plutôt que sur le
// seul segment voisin évite qu'un nœud de dessin mal placé fasse croire à un
// virage.
QPointF along(const QPolygonF &pts, int i, int dir, double d)
{
    QPointF cur = pts[i];
    int j = i + dir;
    while (j >= 0 && j < pts.size()) {
        const double seg = dist(cur, pts[j]);
        if (seg >= d) {
            const double t = d / seg;
            return cur + (pts[j] - cur) * t;
        }
        d -= seg;
        cur = pts[j];
        j += dir;
    }
    return cur;
}

} // namespace

// =============================================================== chargement ==

bool MapData::load(const QString &path, QString *error)
{
    auto fail = [&](const QString &why) {
        if (error)
            *error = why;
        m_loaded = false;
        return false;
    };

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return fail(QStringLiteral("carte introuvable : %1").arg(path));
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &perr);
    if (doc.isNull())
        return fail(QStringLiteral("carte illisible : %1").arg(perr.errorString()));
    const QJsonObject o = doc.object();
    if (o.value("format").toInt() != 1)
        return fail(QStringLiteral("format de carte inconnu"));

    m_name = o.value("name").toString();
    m_attribution = o.value("attribution").toString();
    m_osmTimestamp = o.value("osmTimestamp").toString();
    const QJsonArray origin = o.value("origin").toArray();
    const QJsonArray k = o.value("metersPerDegree").toArray();
    m_lat0 = origin.at(0).toDouble();
    m_lon0 = origin.at(1).toDouble();
    m_kLat = k.at(0).toDouble(1);
    m_kLon = k.at(1).toDouble(1);
    const QJsonArray ext = o.value("extent").toArray();
    m_extent = QRectF(QPointF(ext.at(0).toDouble(), ext.at(1).toDouble()),
                      QPointF(ext.at(2).toDouble(), ext.at(3).toDouble())).normalized();
    m_zone = readFlat(o.value("zone"));

    for (const QJsonValue &v : o.value("areas").toArray())
        m_areas.append({ v.toObject().value("k").toString(), readFlat(v.toObject().value("p")) });
    for (const QJsonValue &v : o.value("water").toArray()) {
        const QPolygonF p = readFlat(v.toObject().value("p"));
        (v.toObject().value("area").toInt() ? m_waterAreas : m_waterLines).append(p);
    }
    for (const QJsonValue &v : o.value("rail").toArray())
        m_rails.append(readFlat(v));
    for (const QJsonValue &v : o.value("buildings").toArray())
        m_buildings.append(readFlat(v));
    for (const QJsonValue &v : o.value("gates").toArray())
        m_gates.append(QPointF(v.toArray().at(0).toDouble(), v.toArray().at(1).toDouble()));

    const int nodeCount = o.value("nodeCount").toInt();
    m_nodePos = QVector<QPointF>(nodeCount);
    for (const QJsonValue &v : o.value("roads").toArray()) {
        const QJsonObject r = v.toObject();
        MapRoad road;
        road.cls = r.value("c").toString();
        road.name = r.value("n").toString();
        if (road.name.isEmpty())
            road.name = r.value("ref").toString();
        road.oneway = r.value("o").toInt();
        road.roundabout = r.value("rb").toInt() != 0;
        road.privateAccess = r.value("a").toString() == QLatin1String("prive");
        road.drivable = isDrivable(road.cls) && !road.privateAccess;
        road.speedKmh = road.roundabout ? 20 : classSpeed(road.cls);
        const QString surface = r.value("s").toString();
        if (surface == QLatin1String("unpaved") || surface == QLatin1String("dirt")
                || surface == QLatin1String("ground") || surface == QLatin1String("sand"))
            road.speedKmh *= 0.7;
        road.rank = classRank(road.cls);
        road.pts = readFlat(r.value("p"));
        for (const QJsonValue &n : r.value("v").toArray())
            road.nodes.append(n.toInt());
        if (road.nodes.size() != road.pts.size() || road.pts.size() < 2)
            continue;
        road.bounds = road.pts.boundingRect();
        for (int i = 0; i < road.nodes.size(); i++)
            if (road.nodes[i] >= 0 && road.nodes[i] < nodeCount)
                m_nodePos[road.nodes[i]] = road.pts[i];
        m_roads.append(road);
    }

    for (const QJsonValue &v : o.value("places").toArray()) {
        const QJsonObject p = v.toObject();
        m_places.append({ p.value("id").toString(), p.value("name").toString(),
                          p.value("cat").toString(), p.value("note").toString(),
                          QPointF(p.value("x").toDouble(), p.value("y").toDouble()) });
    }

    if (m_roads.isEmpty())
        return fail(QStringLiteral("carte sans routes"));
    buildGraph();
    m_loaded = true;
    return true;
}

void MapData::buildGraph()
{
    m_adj = QVector<QVector<Edge>>(m_nodePos.size());
    QVector<QSet<int>> neighbours(m_nodePos.size());
    for (int r = 0; r < m_roads.size(); r++) {
        const MapRoad &road = m_roads[r];
        if (!road.drivable)
            continue;
        const double v = road.speedKmh / 3.6;
        for (int s = 0; s + 1 < road.nodes.size(); s++) {
            const int a = road.nodes[s], b = road.nodes[s + 1];
            if (a == b)
                continue;
            const double len = dist(road.pts[s], road.pts[s + 1]);
            if (road.oneway != -1)
                m_adj[a].append({ b, r, s, true, len, len / v });
            if (road.oneway != 1)
                m_adj[b].append({ a, r, s, false, len, len / v });
            neighbours[a].insert(b);
            neighbours[b].insert(a);
        }
    }
    m_degree = QVector<int>(m_nodePos.size());
    for (int i = 0; i < m_nodePos.size(); i++)
        m_degree[i] = neighbours[i].size();

    // Réseau principal : le plus grand ensemble de routes reliées entre elles.
    // Un bout de piste isolé (fréquent dans OSM autour d'un village) ne mène
    // nulle part : on n'y accroche jamais un départ ni une arrivée.
    QVector<int> comp(m_nodePos.size(), -1);
    QVector<int> sizes;
    for (int i = 0; i < m_nodePos.size(); i++) {
        if (comp[i] >= 0 || neighbours[i].isEmpty())
            continue;
        const int c = sizes.size();
        sizes.append(0);
        QVector<int> stack{ i };
        comp[i] = c;
        while (!stack.isEmpty()) {
            const int u = stack.takeLast();
            sizes[c]++;
            for (int v : neighbours[u])
                if (comp[v] < 0) {
                    comp[v] = c;
                    stack.append(v);
                }
        }
    }
    const int main = int(std::max_element(sizes.cbegin(), sizes.cend()) - sizes.cbegin());
    for (MapRoad &road : m_roads)
        road.mainNetwork = road.drivable && !road.nodes.isEmpty() && comp[road.nodes[0]] == main;
}

QPointF MapData::toLocal(double lat, double lon) const
{
    return QPointF((lon - m_lon0) * m_kLon, (lat - m_lat0) * m_kLat);
}

void MapData::toGeo(const QPointF &p, double *lat, double *lon) const
{
    *lat = m_lat0 + p.y() / m_kLat;
    *lon = m_lon0 + p.x() / m_kLon;
}

int MapData::placeIndex(const QString &id) const
{
    for (int i = 0; i < m_places.size(); i++)
        if (m_places[i].id == id)
            return i;
    return -1;
}

// ==================================================================== outils ==

double MapData::bearing(const QPointF &a, const QPointF &b)
{
    const double deg = qRadiansToDegrees(std::atan2(b.x() - a.x(), b.y() - a.y()));
    return deg < 0 ? deg + 360 : deg;
}

double MapData::angleDiff(double a, double b)
{
    double d = std::fmod(b - a, 360.0);
    if (d <= -180)
        d += 360;
    if (d > 180)
        d -= 360;
    return d;
}

QString MapData::formatDistance(double m)
{
    if (!std::isfinite(m) || m < 0)
        return QStringLiteral("- -");
    if (m < 100)
        return QString::number(qMax(10, int(std::round(m / 10) * 10))) + QStringLiteral(" m");
    if (m < 1000)
        return QString::number(int(std::round(m / 50) * 50)) + QStringLiteral(" m");
    if (m < 10000)
        return QString::number(m / 1000, 'f', 1).replace('.', ',') + QStringLiteral(" km");
    return QString::number(int(std::round(m / 1000))) + QStringLiteral(" km");
}

QString MapData::formatDuration(double s)
{
    if (!std::isfinite(s) || s < 0)
        return QStringLiteral("- -");
    const int min = qMax(1, int(std::ceil(s / 60)));
    if (min < 60)
        return QString::number(min) + QStringLiteral(" min");
    return QStringLiteral("%1 h %2").arg(min / 60).arg(min % 60, 2, 10, QLatin1Char('0'));
}

QString MapData::cardinal(double b)
{
    static const char *names[] = { "le nord", "le nord-est", "l'est", "le sud-est",
                                   "le sud", "le sud-ouest", "l'ouest", "le nord-ouest" };
    return QString::fromUtf8(names[int(std::round(b / 45.0)) % 8]);
}

QString MapData::landmarkNear(const QPointF &p, double radius, bool withArticle) const
{
    const MapPlace *best = nullptr;
    double bestD = radius;
    for (const MapPlace &pl : m_places) {
        if (pl.category == QLatin1String("village"))
            continue;
        const double d = dist(pl.pos, p);
        if (d < bestD) {
            bestD = d;
            best = &pl;
        }
    }
    if (!best)
        return QString();
    if (!withArticle)
        return best->name;
    // « au niveau de la Porte 7 », « du Rond-point 3 », « de l'Entrée nord » :
    // la consigne est aussi lue à voix haute, elle doit sonner juste.
    const QString &n = best->name;
    if (best->category == QLatin1String("porte"))
        return QStringLiteral("de la ") + n;
    if (n.startsWith(QLatin1String("Rond-point")))
        return QStringLiteral("du ") + n;
    if (n.startsWith(QLatin1String("Entrée")) || n.startsWith(QLatin1String("Usine")))
        return QStringLiteral("de l'") + n;
    return QStringLiteral("de ") + n;
}

// ======================================================= accroche à la route ==

MapData::Snap MapData::snap(const QPointF &p, double heading, double maxDist) const
{
    Snap best;
    double bestCost = kInf;
    const bool useHeading = !qIsNaN(heading);
    for (int r = 0; r < m_roads.size(); r++) {
        const MapRoad &road = m_roads[r];
        if (!road.mainNetwork || !road.bounds.adjusted(-maxDist, -maxDist, maxDist, maxDist).contains(p))
            continue;
        for (int s = 0; s + 1 < road.pts.size(); s++) {
            const double t = project(p, road.pts[s], road.pts[s + 1]);
            const QPointF q = road.pts[s] + (road.pts[s + 1] - road.pts[s]) * t;
            const double d = dist(p, q);
            if (d > maxDist)
                continue;
            double cost = d;
            if (useHeading) {
                // L'écart de cap compte comme jusqu'à 45 m de distance : assez
                // pour choisir la bonne chaussée d'une avenue, pas assez pour
                // préférer une route lointaine à celle où l'on roule.
                const double b = bearing(road.pts[s], road.pts[s + 1]);
                double diff = 180;
                if (road.oneway != -1)
                    diff = qMin(diff, qAbs(angleDiff(b, heading)));
                if (road.oneway != 1)
                    diff = qMin(diff, qAbs(angleDiff(b + 180, heading)));
                cost += diff * 0.25;
            }
            if (cost < bestCost) {
                bestCost = cost;
                best.road = r;
                best.seg = s;
                best.t = t;
                best.p = q;
                best.dist = d;
            }
        }
    }
    return best;
}

// =============================================================== itinéraire ==

Route MapData::route(const Snap &from, const Snap &to, const QString &destinationName,
                     const QPointF &destinationPos, bool destinationKnown,
                     const QHash<quint64, double> *penalty) const
{
    Route out;
    if (!m_loaded || !from.valid() || !to.valid())
        return out;

    const int N = m_nodePos.size();
    const int S = N, T = N + 1;
    const MapRoad &r1 = m_roads[from.road];
    const MapRoad &r2 = m_roads[to.road];
    const double L1 = dist(r1.pts[from.seg], r1.pts[from.seg + 1]);
    const double L2 = dist(r2.pts[to.seg], r2.pts[to.seg + 1]);
    const double v1 = r1.speedKmh / 3.6, v2 = r2.speedKmh / 3.6;
    const quint64 k1 = edgeKey(from.road, from.seg), k2 = edgeKey(to.road, to.seg);
    auto pen = [&](quint64 key) { return penalty ? penalty->value(key, 1.0) : 1.0; };

    // Départ et arrivée sont au milieu d'un tronçon : deux nœuds virtuels les
    // relient aux extrémités de leur tronçon, dans les sens permis.
    struct VEdge { int to; double len; double time; bool forward; };
    QVector<VEdge> startEdges;
    if (r1.oneway != -1)
        startEdges.append({ r1.nodes[from.seg + 1], (1 - from.t) * L1, (1 - from.t) * L1 / v1 * pen(k1), true });
    if (r1.oneway != 1)
        startEdges.append({ r1.nodes[from.seg], from.t * L1, from.t * L1 / v1 * pen(k1), false });
    const int a2 = r2.nodes[to.seg], b2 = r2.nodes[to.seg + 1];
    const bool endFwd = r2.oneway != -1, endBwd = r2.oneway != 1;

    // Même tronçon, dans le bon ordre : on y reste.
    double directTime = kInf;
    if (from.road == to.road && from.seg == to.seg) {
        if ((endFwd && to.t >= from.t) || (endBwd && to.t <= from.t))
            directTime = qAbs(to.t - from.t) * L1 / v1;
    }

    // A*, sur la durée. L'heuristique (vol d'oiseau à 50 km/h) ne surestime
    // jamais : le premier chemin trouvé est le plus rapide.
    QVector<double> g(N + 2, kInf);
    struct Prev { int node = -1; int road = -1; int seg = -1; bool forward = true; };
    QVector<Prev> prev(N + 2);
    using QItem = std::pair<double, int>;
    std::priority_queue<QItem, std::vector<QItem>, std::greater<QItem>> open;
    const double vmax = 50 / 3.6;
    auto h = [&](int n) { return n >= N ? 0.0 : dist(m_nodePos[n], to.p) / vmax; };

    g[S] = 0;
    open.push({ h(S), S });
    while (!open.empty()) {
        const auto [f, u] = open.top();
        open.pop();
        if (u == T)
            break;
        if (f - h(u) > g[u] + 1e-9)
            continue;
        auto relax = [&](int v, double cost, int road, int seg, bool fwd) {
            if (g[u] + cost < g[v]) {
                g[v] = g[u] + cost;
                prev[v] = { u, road, seg, fwd };
                open.push({ g[v] + h(v), v });
            }
        };
        if (u == S) {
            for (const VEdge &e : startEdges)
                relax(e.to, e.time, from.road, from.seg, e.forward);
            continue;
        }
        for (const Edge &e : m_adj[u])
            relax(e.to, e.time * pen(edgeKey(e.road, e.seg)), e.road, e.seg, e.forward);
        if (u == a2 && endFwd)
            relax(T, to.t * L2 / v2 * pen(k2), to.road, to.seg, true);
        if (u == b2 && endBwd)
            relax(T, (1 - to.t) * L2 / v2 * pen(k2), to.road, to.seg, false);
    }

    if (!std::isfinite(g[T]) && !std::isfinite(directTime))
        return out;

    // Reconstitution du tracé : chaque nœud du graphe est un point de route,
    // il suffit de les enchaîner entre les deux points d'accroche.
    struct V { QPointF p; int node; int road; quint64 key; };
    QVector<V> seq;
    if (directTime <= g[T]) {
        seq.append({ from.p, -1, from.road, k1 });
        seq.append({ to.p, -1, to.road, k1 });
    } else {
        QVector<int> chain;
        for (int n = T; n != -1; n = prev[n].node)
            chain.prepend(n);
        for (int i = 0; i < chain.size(); i++) {
            const int n = chain[i];
            const Prev &pv = prev[n];
            if (n == S) {
                seq.append({ from.p, -1, -1, 0 });
                continue;
            }
            // La route du tronçon qui arrive ici est aussi celle du tronçon
            // précédent : on la recopie sur le point d'avant.
            seq.last().road = pv.road;
            seq.last().key = edgeKey(pv.road, pv.seg);
            if (n == T)
                seq.append({ to.p, -1, -1, 0 });
            else
                seq.append({ m_nodePos[n], n, -1, 0 });
        }
    }

    // Points confondus (accroche pile sur un nœud) : on les fusionne.
    for (int i = 0; i < seq.size(); i++) {
        if (!out.pts.isEmpty() && dist(out.pts.last(), seq[i].p) < 0.05) {
            if (seq[i].node >= 0)
                out.nodeAt.last() = seq[i].node;
            if (seq[i].road >= 0 && i + 1 < seq.size()) {
                out.roadOf.last() = seq[i].road;
                out.keys.last() = seq[i].key;
            }
            continue;
        }
        out.pts.append(seq[i].p);
        out.nodeAt.append(seq[i].node);
        out.roadOf.append(seq[i].road);
        out.keys.append(seq[i].key);
    }
    if (out.pts.size() < 2) {
        // Départ et arrivée confondus : un itinéraire nul mais valide.
        out.pts = QPolygonF() << from.p << to.p;
        out.nodeAt = { -1, -1 };
        out.roadOf = { from.road, -1 };
        out.keys = { k1, 0 };
    }
    finishRoute(out, destinationName, destinationPos, destinationKnown);
    return out;
}

void MapData::finishRoute(Route &r, const QString &destinationName, const QPointF &destinationPos,
                          bool destinationKnown) const
{
    const int n = r.pts.size();
    r.cum = QVector<double>(n, 0);
    r.cumTime = QVector<double>(n, 0);
    QHash<int, double> perRoad;
    for (int i = 1; i < n; i++) {
        const double d = dist(r.pts[i - 1], r.pts[i]);
        const int road = r.roadOf[i - 1];
        const double v = (road >= 0 ? m_roads[road].speedKmh : 20) / 3.6;
        r.cum[i] = r.cum[i - 1] + d;
        r.cumTime[i] = r.cumTime[i - 1] + d / v;
        if (road >= 0)
            perRoad[road] += d;
    }
    r.length = r.cum.last();
    r.duration = r.cumTime.last();
    r.bounds = r.pts.boundingRect();
    r.valid = true;

    // « Par … » : la route nommée la plus parcourue, sinon le repère le plus
    // proche du milieu du trajet. C'est ce qui distingue deux itinéraires
    // proposés côte à côte.
    QHash<QString, double> byName;
    for (auto it = perRoad.cbegin(); it != perRoad.cend(); ++it)
        if (!m_roads[it.key()].name.isEmpty())
            byName[m_roads[it.key()].name] += it.value();
    double bestLen = r.length * 0.25;
    for (auto it = byName.cbegin(); it != byName.cend(); ++it)
        if (it.value() > bestLen) {
            bestLen = it.value();
            r.via = QStringLiteral("par ") + it.key();
        }
    if (r.via.isEmpty() && n > 2) {
        QString best;
        double bestD = 120;
        for (const MapPlace &pl : m_places) {
            if (pl.category != QLatin1String("repere"))
                continue;
            // Le repère le plus proche du tracé, dans sa moitié centrale : le
            // point de départ ou d'arrivée ne distingue pas deux itinéraires.
            for (int j = 1; j < n - 1; j++) {
                if (r.cum[j] < 0.25 * r.length || r.cum[j] > 0.75 * r.length)
                    continue;
                const double d = dist(pl.pos, r.pts[j]);
                if (d < bestD) {
                    bestD = d;
                    best = pl.name;
                }
            }
        }
        if (!best.isEmpty())
            r.via = QStringLiteral("par ") + best;
    }

    buildSteps(r, destinationName, destinationPos, destinationKnown);
    buildSpeedLimits(r);
}

void MapData::buildSteps(Route &r, const QString &destinationName, const QPointF &destinationPos,
                         bool destinationKnown) const
{
    const int n = r.pts.size();
    auto roadName = [&](int road) { return road >= 0 ? m_roads[road].name : QString(); };
    auto isRb = [&](int road) { return road >= 0 && m_roads[road].roundabout; };

    RouteStep dep;
    dep.kind = RouteStep::Depart;
    dep.at = 0;
    dep.pos = r.pts[0];
    dep.road = roadName(r.roadOf[0]);
    dep.angle = bearing(r.pts[0], along(r.pts, 0, +1, 20));
    dep.text = QStringLiteral("Partez vers ") + cardinal(dep.angle)
             + (dep.road.isEmpty() ? QString() : QStringLiteral(" sur ") + dep.road);
    dep.icon = QStringLiteral("ph-navigation-arrow");
    r.steps.append(dep);

    for (int i = 1; i < n - 1; i++) {
        const int node = r.nodeAt[i];
        if (node < 0)
            continue;
        const int inRoad = r.roadOf[i - 1], outRoad = r.roadOf[i];

        // ---- rond-point : une seule consigne à l'entrée, avec le numéro de
        // sortie, comme on le dit en conduisant.
        if (!isRb(inRoad) && isRb(outRoad)) {
            int j = i + 1;
            while (j < n - 1 && isRb(r.roadOf[j]))
                j++;
            int exits = 0;
            for (int k = i + 1; k <= j && k < n; k++) {
                const int nk = r.nodeAt[k];
                if (nk < 0)
                    continue;
                bool hasExit = false;
                for (const Edge &e : m_adj[nk])
                    if (!m_roads[e.road].roundabout)
                        hasExit = true;
                if (hasExit)
                    exits++;
            }
            RouteStep st;
            st.kind = RouteStep::Roundabout;
            st.exit = qMax(1, exits);
            st.at = r.cum[i];
            st.pos = r.pts[i];
            st.road = j < n - 1 ? roadName(r.roadOf[j]) : QString();
            st.landmark = landmarkNear(st.pos, 70);
            const QString where = st.landmark.startsWith(QLatin1String("Rond-point"))
                ? QStringLiteral("Au ") + st.landmark : QStringLiteral("Au rond-point");
            st.text = where + QStringLiteral(", prenez la ") + ordinal(st.exit) + QStringLiteral(" sortie")
                    + (st.road.isEmpty() ? QString() : QStringLiteral(" vers ") + st.road);
            st.icon = QStringLiteral("ph-arrow-counter-clockwise");
            r.steps.append(st);
            i = j - 1;
            continue;
        }
        // Dans l'anneau, ou à sa sortie : la consigne d'entrée a tout dit.
        if (isRb(inRoad))
            continue;

        if (m_degree.value(node) < 3)
            continue;

        const double inB = bearing(along(r.pts, i, -1, 15), r.pts[i]);
        const double outB = bearing(r.pts[i], along(r.pts, i, +1, 15));
        const double d = angleDiff(inB, outB);
        const int prevNode = r.nodeAt[i - 1], nextNode = r.nodeAt[i + 1];

        // Les autres branches praticables depuis ce carrefour.
        QVector<double> others;
        for (const Edge &e : m_adj[node]) {
            if (e.to == nextNode || e.to == prevNode)
                continue;
            others.append(bearing(r.pts[i], m_nodePos[e.to]));
        }
        if (others.isEmpty())
            continue;

        RouteStep st;
        st.at = r.cum[i];
        st.pos = r.pts[i];
        st.angle = d;
        st.road = roadName(outRoad);
        const bool right = d > 0;
        const double ad = qAbs(d);
        if (ad < 20) {
            // Tout droit : rien à dire, sauf si une autre branche part presque
            // dans le même axe (fourche).
            double closest = 180;
            for (double b : others)
                if (qAbs(angleDiff(outB, b)) < qAbs(closest))
                    closest = angleDiff(outB, b);
            if (qAbs(closest) >= 40)
                continue;
            st.kind = RouteStep::Keep;
            st.direction = closest > 0 ? -1 : 1;
            st.text = st.direction > 0 ? QStringLiteral("Restez à droite") : QStringLiteral("Restez à gauche");
            st.icon = st.direction > 0 ? QStringLiteral("ph-arrow-up-right") : QStringLiteral("ph-arrow-up-left");
        } else if (ad < 50) {
            // Un léger coude n'est une consigne que si continuer tout droit
            // était aussi possible.
            bool straightExists = false;
            for (double b : others)
                if (qAbs(angleDiff(inB, b)) < ad + 10)
                    straightExists = true;
            if (!straightExists)
                continue;
            st.kind = RouteStep::Turn;
            st.direction = right ? 1 : -1;
            st.text = right ? QStringLiteral("Tournez légèrement à droite")
                            : QStringLiteral("Tournez légèrement à gauche");
            st.icon = right ? QStringLiteral("ph-arrow-up-right") : QStringLiteral("ph-arrow-up-left");
        } else if (ad < 145) {
            st.kind = RouteStep::Turn;
            st.direction = right ? 1 : -1;
            st.text = right ? QStringLiteral("Tournez à droite") : QStringLiteral("Tournez à gauche");
            st.icon = right ? QStringLiteral("ph-arrow-bend-up-right") : QStringLiteral("ph-arrow-bend-up-left");
        } else {
            st.kind = RouteStep::Turn;
            st.direction = right ? 2 : -2;
            st.text = right ? QStringLiteral("Tournez fortement à droite")
                            : QStringLiteral("Tournez fortement à gauche");
            st.icon = right ? QStringLiteral("ph-arrow-u-up-right") : QStringLiteral("ph-arrow-u-up-left");
        }
        st.landmark = landmarkNear(st.pos, 45);
        if (!st.road.isEmpty())
            st.text += QStringLiteral(" sur ") + st.road;
        else if (!st.landmark.isEmpty())
            st.text += QStringLiteral(" au niveau ") + landmarkNear(st.pos, 45, true);
        r.steps.append(st);
    }

    RouteStep arr;
    arr.kind = RouteStep::Arrive;
    arr.at = r.length;
    arr.pos = r.pts.last();
    arr.icon = QStringLiteral("ph-flag-checkered");
    if (destinationKnown && n >= 2) {
        const QPointF v = r.pts[n - 1] - r.pts[n - 2];
        const QPointF w = destinationPos - r.pts[n - 1];
        if (std::hypot(w.x(), w.y()) > 4) {
            const double cross = v.x() * w.y() - v.y() * w.x();
            arr.side = cross > 0 ? -1 : 1;
        }
    }
    arr.text = destinationName.isEmpty() ? QStringLiteral("Arrivée")
                                          : QStringLiteral("Arrivée : ") + destinationName;
    r.steps.append(arr);
}

void MapData::buildSpeedLimits(Route &r) const
{
    // Vitesse conseillée au passage de chaque point : celle de la route, moins
    // ce qu'imposent un virage ou un rond-point. Le guidage et le simulateur
    // s'en servent pour ralentir *avant* le virage, pas dedans.
    const int n = r.pts.size();
    r.limit = QVector<double>(n, 0);
    for (int i = 0; i < n; i++) {
        double v = 50;
        if (i > 0 && r.roadOf[i - 1] >= 0)
            v = qMin(v, m_roads[r.roadOf[i - 1]].speedKmh);
        if (i < n - 1 && r.roadOf[i] >= 0)
            v = qMin(v, m_roads[r.roadOf[i]].speedKmh);
        if (i > 0 && i < n - 1) {
            const double a = qAbs(angleDiff(bearing(along(r.pts, i, -1, 10), r.pts[i]),
                                             bearing(r.pts[i], along(r.pts, i, +1, 10))));
            if (a > 100)
                v = qMin(v, 12.0);
            else if (a > 60)
                v = qMin(v, 18.0);
            else if (a > 30)
                v = qMin(v, 28.0);
        }
        r.limit[i] = v;
    }
    r.limit[n - 1] = 0;
}

QVector<Route> MapData::routes(const Snap &from, const Snap &to, int count,
                               const QString &destinationName, const QPointF &destinationPos,
                               bool destinationKnown) const
{
    QVector<Route> found;
    Route best = route(from, to, destinationName, destinationPos, destinationKnown);
    if (!best.valid)
        return found;
    found.append(best);

    // Alternatives : on renchérit les tronçons déjà proposés et on recalcule.
    // Une alternative n'est retenue que si elle est vraiment différente (moins
    // de 70 % de parcours commun) et pas absurde (au plus 60 % plus longue).
    QHash<quint64, double> penalty;
    for (int attempt = 0; attempt < count + 2 && found.size() < count; attempt++) {
        for (const Route &r : found)
            for (quint64 k : r.keys)
                penalty[k] = penalty.value(k, 1.0) * 1.8;
        Route alt = route(from, to, destinationName, destinationPos, destinationKnown, &penalty);
        if (!alt.valid || alt.duration > best.duration * 1.6)
            continue;
        bool distinct = true;
        for (const Route &r : found) {
            QSet<quint64> used(r.keys.cbegin(), r.keys.cend());
            double shared = 0;
            for (int i = 0; i + 1 < alt.pts.size(); i++)
                if (used.contains(alt.keys[i]))
                    shared += alt.cum[i + 1] - alt.cum[i];
            if (shared > 0.7 * alt.length)
                distinct = false;
        }
        if (distinct)
            found.append(alt);
    }
    return found;
}

MapData::Field MapData::distancesFrom(const Snap &from) const
{
    Field f;
    const int N = m_nodePos.size();
    f.time = QVector<double>(N, kInf);
    f.len = QVector<double>(N, kInf);
    if (!m_loaded || !from.valid())
        return f;
    const MapRoad &r1 = m_roads[from.road];
    const double L1 = dist(r1.pts[from.seg], r1.pts[from.seg + 1]);
    const double v1 = r1.speedKmh / 3.6;
    using QItem = std::pair<double, int>;
    std::priority_queue<QItem, std::vector<QItem>, std::greater<QItem>> open;
    auto seed = [&](int node, double len) {
        if (len / v1 < f.time[node]) {
            f.time[node] = len / v1;
            f.len[node] = len;
            open.push({ f.time[node], node });
        }
    };
    if (r1.oneway != -1)
        seed(r1.nodes[from.seg + 1], (1 - from.t) * L1);
    if (r1.oneway != 1)
        seed(r1.nodes[from.seg], from.t * L1);
    while (!open.empty()) {
        const auto [t, u] = open.top();
        open.pop();
        if (t > f.time[u])
            continue;
        for (const Edge &e : m_adj[u]) {
            if (t + e.time < f.time[e.to]) {
                f.time[e.to] = t + e.time;
                f.len[e.to] = f.len[u] + e.len;
                open.push({ f.time[e.to], e.to });
            }
        }
    }
    return f;
}

double MapData::distanceTo(const Field &f, const Snap &to) const
{
    if (!to.valid() || f.time.isEmpty())
        return kInf;
    const MapRoad &r2 = m_roads[to.road];
    const double L2 = dist(r2.pts[to.seg], r2.pts[to.seg + 1]);
    double bestT = kInf, bestL = kInf;
    if (r2.oneway != -1) {
        const int a = r2.nodes[to.seg];
        if (f.time[a] < bestT) {
            bestT = f.time[a];
            bestL = f.len[a] + to.t * L2;
        }
    }
    if (r2.oneway != 1) {
        const int b = r2.nodes[to.seg + 1];
        if (f.time[b] < bestT) {
            bestT = f.time[b];
            bestL = f.len[b] + (1 - to.t) * L2;
        }
    }
    return bestL;
}

Route MapData::join(const QVector<Route> &parts) const
{
    Route out;
    for (const Route &part : parts) {
        if (!part.valid)
            continue;
        for (int i = 0; i < part.pts.size(); i++) {
            if (i == 0 && !out.pts.isEmpty() && dist(out.pts.last(), part.pts[0]) < 0.5) {
                // Point de raccord : il prend la route du morceau qui commence.
                out.roadOf.last() = part.roadOf[0];
                out.keys.last() = part.keys[0];
                if (out.nodeAt.last() < 0)
                    out.nodeAt.last() = part.nodeAt[0];
                continue;
            }
            out.pts.append(part.pts[i]);
            out.roadOf.append(part.roadOf[i]);
            out.keys.append(part.keys[i]);
            out.nodeAt.append(part.nodeAt[i]);
        }
    }
    if (out.pts.size() < 2)
        return Route();
    finishRoute(out, QString(), QPointF(), false);
    return out;
}

QPointF MapData::pointAt(const Route &r, double d, double *heading, int *segment)
{
    const int n = r.pts.size();
    if (n == 0)
        return QPointF();
    if (n == 1 || d <= 0) {
        if (heading && n > 1)
            *heading = bearing(r.pts[0], r.pts[1]);
        if (segment)
            *segment = 0;
        return r.pts[0];
    }
    if (d >= r.length) {
        if (heading)
            *heading = bearing(r.pts[n - 2], r.pts[n - 1]);
        if (segment)
            *segment = n - 2;
        return r.pts[n - 1];
    }
    const int i = int(std::upper_bound(r.cum.cbegin(), r.cum.cend(), d) - r.cum.cbegin()) - 1;
    const int seg = std::clamp(i, 0, n - 2);
    const double len = r.cum[seg + 1] - r.cum[seg];
    const double t = len > 1e-9 ? (d - r.cum[seg]) / len : 0;
    if (heading)
        *heading = bearing(r.pts[seg], r.pts[seg + 1]);
    if (segment)
        *segment = seg;
    return r.pts[seg] + (r.pts[seg + 1] - r.pts[seg]) * t;
}
