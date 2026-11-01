#include "mapview.h"
#include "navigation.h"

#include <QElapsedTimer>
#include <QFont>
#include <QFontMetricsF>
#include <QPainter>
#include <QPainterPath>
#include <QtMath>

namespace {

// Palette de la carte. Sombre, peu saturée : la carte est un fond, ce qui se
// lit dessus — l'itinéraire, la navette, la destination — doit ressortir.
const QColor kBg("#0b111c");
const QColor kZoneFill(20, 184, 166, 10);
const QColor kZoneLine(20, 184, 166, 110);
const QColor kBuilding("#1a2333");
const QColor kBuildingLine("#263247");
const QColor kWater("#10263f");
const QColor kRouteFill("#3b82f6");
const QColor kRouteCasing("#1e3a8a");
const QColor kRouteAlt("#55657f");
const QColor kRouteAltCasing("#273246");
const QColor kRouteDone("#4b5568");
const QColor kVehicle("#3b82f6");
const QColor kEstimated("#f59e0b");
const QColor kLost("#7b879b");
const QColor kDestination("#ef4444");
const QColor kText("#d5deec");
const QColor kTextMuted("#8b98ad");
const QColor kHalo("#0b111c");

QColor areaColor(const QString &k)
{
    if (k == QLatin1String("residential")) return QColor("#111a26");
    if (k == QLatin1String("industrial")) return QColor("#151b2b");
    if (k == QLatin1String("commercial") || k == QLatin1String("retail")) return QColor("#1a1a28");
    if (k == QLatin1String("construction")) return QColor("#17191f");
    if (k == QLatin1String("farmland") || k == QLatin1String("orchard") || k == QLatin1String("meadow")
            || k == QLatin1String("grass") || k == QLatin1String("forest"))
        return QColor("#0f1a16");
    return QColor("#11161f");
}

struct RoadStyle {
    double meters;      // largeur réelle approximative
    double minPx;
    QColor fill, casing;
    bool dashed = false;
};

RoadStyle roadStyle(const QString &cls)
{
    QString c = cls;
    c.remove(QLatin1String("_link"));
    if (c == QLatin1String("motorway") || c == QLatin1String("trunk") || c == QLatin1String("primary"))
        return { 14, 3.2, QColor("#c9933a"), QColor("#4a3415") };
    if (c == QLatin1String("secondary"))
        return { 12, 2.8, QColor("#b39a5c"), QColor("#3d3420") };
    if (c == QLatin1String("tertiary"))
        return { 11, 2.4, QColor("#4a5873"), QColor("#1b2333") };
    if (c == QLatin1String("unclassified") || c == QLatin1String("residential") || c == QLatin1String("road")
            || c == QLatin1String("living_street"))
        return { 7, 1.6, QColor("#334058"), QColor("#161d2a") };
    if (c == QLatin1String("service"))
        return { 5, 1.1, QColor("#2a3447"), QColor("#141a26") };
    if (c == QLatin1String("track"))
        return { 4, 1.0, QColor("#5c4e36"), QColor(), true };
    return { 2, 0.8, QColor("#3a4152"), QColor(), true };    // chemins
}

// Codepoints Phosphor (assets/fonts/phosphor), par catégorie de lieu. Les mêmes
// que Navigation::categoryIcon, côté QML.
QString categoryGlyph(const QString &c)
{
    static const QHash<QString, ushort> cp = {
        { "entree", 0xe89c }, { "porte", 0xe61c }, { "usine", 0xe760 }, { "service", 0xe102 },
        { "sante", 0xe56e }, { "commerce", 0xe470 }, { "restauration", 0xe262 },
        { "carburant", 0xe768 }, { "ecole", 0xe62c }, { "marche", 0xe964 },
        { "village", 0xe2c4 }, { "repere", 0xe094 },
    };
    return QString(QChar(cp.value(c, 0xe316)));
}

QColor categoryColor(const QString &c)
{
    if (c == QLatin1String("entree")) return QColor("#14b8a6");
    if (c == QLatin1String("porte")) return QColor("#a78bfa");
    if (c == QLatin1String("usine")) return QColor("#a78bfa");
    if (c == QLatin1String("service")) return QColor("#60a5fa");
    if (c == QLatin1String("sante")) return QColor("#ef4444");
    if (c == QLatin1String("restauration") || c == QLatin1String("commerce") || c == QLatin1String("marche"))
        return QColor("#f59e0b");
    if (c == QLatin1String("carburant")) return QColor("#22c55e");
    if (c == QLatin1String("ecole")) return QColor("#eab308");
    return QColor("#8b98ad");
}

// Priorité d'affichage (plus petit = plus important) et zoom minimal. Les
// portes, serrées dans le bloc d'usines, n'apparaissent que de près.
int placePriority(const QString &c)
{
    if (c == QLatin1String("entree") || c == QLatin1String("service") || c == QLatin1String("usine")) return 0;
    if (c == QLatin1String("village")) return 1;
    if (c == QLatin1String("sante") || c == QLatin1String("marche") || c == QLatin1String("ecole")) return 2;
    if (c == QLatin1String("porte")) return 3;
    if (c == QLatin1String("repere")) return 5;
    return 4;
}

double placeMinZoom(const QString &c)
{
    if (c == QLatin1String("village")) return 0.05;
    if (c == QLatin1String("entree") || c == QLatin1String("service") || c == QLatin1String("usine")) return 0.08;
    if (c == QLatin1String("porte")) return 0.45;
    if (c == QLatin1String("repere")) return 0.3;
    return 0.18;
}

QPainterPath pathOf(const QPolygonF &pts, bool closed = false)
{
    QPainterPath path;
    if (pts.isEmpty())
        return path;
    path.moveTo(pts[0]);
    for (int i = 1; i < pts.size(); i++)
        path.lineTo(pts[i]);
    if (closed)
        path.closeSubpath();
    return path;
}

QPen cosmetic(const QColor &c, double w, Qt::PenStyle style = Qt::SolidLine)
{
    QPen pen(c, w, style, Qt::RoundCap, Qt::RoundJoin);
    pen.setCosmetic(true);
    return pen;
}

} // namespace

MapView::MapView(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    setOpaquePainting(true);
    setFillColor(kBg);
    connect(this, &MapView::viewChanged, this, [this] { update(); });
}

void MapView::componentComplete()
{
    QQuickPaintedItem::componentComplete();
    // Le singleton Navigation existe dès que QML l'a nommé — au plus tard
    // dans les liaisons de cette vue, évaluées avant ce point.
    if (Navigation *nav = Navigation::instance()) {
        for (auto sig : { &Navigation::routesChanged, &Navigation::guidanceChanged,
                          &Navigation::stateChanged, &Navigation::positionStateChanged })
            connect(nav, sig, this, [this] { update(); });
    }
}

void MapView::set(double &field, double v)
{
    if (qFuzzyCompare(field + 1e9, v + 1e9) || qIsNaN(v))
        return;
    field = v;
    emit viewChanged();
}

void MapView::haloText(QPainter *p, const QPointF &at, const QString &text, const QColor &color,
                       bool centered) const
{
    // Texte détouré : lisible sur n'importe quel fond de carte.
    const QFont &f = p->font();
    const QString key = text + QChar(0x1f) + QString::number(f.pixelSize()) + QChar(0x1f)
                      + QString::number(int(f.weight()));
    auto it = m_textPaths.find(key);
    if (it == m_textPaths.end()) {
        QPainterPath path;
        path.addText(QPointF(0, 0), f, text);
        it = m_textPaths.insert(key, path);
    }
    QPointF o = at;
    if (centered)
        o.rx() -= it->boundingRect().width() / 2;
    const QPainterPath path = it->translated(o);
    p->setPen(QPen(kHalo, 3.5, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    p->setBrush(Qt::NoBrush);
    p->drawPath(path);
    p->setPen(Qt::NoPen);
    p->setBrush(color);
    p->drawPath(path);
}

void MapView::setSelectedPlace(const QString &id)
{
    if (id == m_selected)
        return;
    m_selected = id;
    emit viewChanged();
}

QTransform MapView::world() const
{
    QTransform t;
    t.translate(width() * m_ax, height() * m_ay);
    t.rotate(-m_bearing);
    t.scale(m_zoom, -m_zoom);
    t.translate(-m_cx, -m_cy);
    return t;
}

QPointF MapView::toScreen(double x, double y) const
{
    return world().map(QPointF(x, y));
}

QPointF MapView::toMap(double px, double py) const
{
    return world().inverted().map(QPointF(px, py));
}

QVariantMap MapView::fit(const QRectF &r, double left, double top, double right, double bottom) const
{
    const double w = qMax(50.0, width() - left - right);
    const double h = qMax(50.0, height() - top - bottom);
    const double zoom = qBound(0.03, qMin(w / qMax(r.width(), 1.0), h / qMax(r.height(), 1.0)) * 0.9, 3.0);
    // Le centre du rectangle doit tomber au milieu de la zone libre, compte
    // tenu de l'ancre de la vue.
    const double sx = left + w / 2 - width() * m_ax;
    const double sy = top + h / 2 - height() * m_ay;
    QVariantMap m;
    m["x"] = r.center().x() - sx / zoom;
    m["y"] = r.center().y() + sy / zoom;
    m["zoom"] = zoom;
    return m;
}

QRectF MapView::routeBounds() const
{
    const Navigation *nav = Navigation::instance();
    if (!nav)
        return QRectF();
    QRectF b;
    for (const Route &r : nav->routeObjects())
        b = b.isNull() ? r.bounds : b.united(r.bounds);
    if (nav->state() != QLatin1String("idle"))
        b = b.united(QRectF(nav->destinationPos(), QSizeF(1, 1)));
    return b;
}

// ==================================================================== dessin ==

void MapView::paint(QPainter *p)
{
    QElapsedTimer clock;
    clock.start();
    struct Measure {
        QElapsedTimer &c; double &total; int &count;
        ~Measure() { total += c.nsecsElapsed() / 1e6; count++; }
    } measure{ clock, m_paintTotal, m_paintCount };
    const Navigation *nav = Navigation::instance();
    p->fillRect(QRectF(0, 0, width(), height()), kBg);
    if (!nav || !nav->ready())
        return;
    const MapData &map = nav->map();
    p->setRenderHint(QPainter::Antialiasing, true);
    p->setRenderHint(QPainter::TextAntialiasing, true);

    // Ce qui est visible, en coordonnées de carte (avec une marge pour les
    // traits épais et les étiquettes qui débordent).
    const QRectF visible = world().inverted().mapRect(QRectF(-60, -60, width() + 120, height() + 120));

    p->save();
    p->setTransform(world());
    drawBase(p, map, visible);
    drawRoutes(p);
    p->restore();

    drawLabels(p, map);
    drawMarkers(p);
    drawVehicle(p);
}

void MapView::drawBase(QPainter *p, const MapData &map, const QRectF &visible) const
{
    p->setPen(Qt::NoPen);
    for (const MapArea &a : map.areas()) {
        if (!a.poly.boundingRect().intersects(visible))
            continue;
        p->setBrush(areaColor(a.kind));
        p->drawPolygon(a.poly);
    }

    // La zone industrielle : un voile et un contour en tirets, toujours là —
    // c'est le cadre du service.
    if (!map.zone().isEmpty()) {
        p->setBrush(kZoneFill);
        p->setPen(cosmetic(kZoneLine, 1.6, Qt::DashLine));
        p->drawPolygon(map.zone());
    }

    p->setPen(Qt::NoPen);
    p->setBrush(kWater);
    for (const QPolygonF &w : map.waterAreas())
        p->drawPolygon(w);
    p->setBrush(Qt::NoBrush);
    p->setPen(cosmetic(kWater.lighter(140), 1.6));
    for (const QPolygonF &w : map.waterLines())
        p->drawPolyline(w);

    if (m_zoom > 0.1) {
        const double a = qBound(0.0, (m_zoom - 0.1) / 0.15, 1.0);
        QColor fill = kBuilding, line = kBuildingLine;
        fill.setAlphaF(a);
        line.setAlphaF(a);
        p->setBrush(fill);
        p->setPen(m_zoom > 0.4 ? cosmetic(line, 1) : Qt::NoPen);
        for (const QPolygonF &b : map.buildings())
            if (b.boundingRect().intersects(visible))
                p->drawPolygon(b);
    }

    // Routes : toutes les bordures d'abord, puis tous les remplissages, par
    // ordre d'importance — un carrefour se dessine alors sans couture.
    QVector<int> order;
    for (int i = 0; i < map.roads().size(); i++)
        if (map.roads()[i].bounds.intersects(visible))
            order.append(i);
    std::sort(order.begin(), order.end(),
              [&](int a, int b) { return map.roads()[a].rank < map.roads()[b].rank; });

    if (m_roadPaths.size() != map.roads().size()) {
        m_roadPaths.clear();
        for (const MapRoad &road : map.roads())
            m_roadPaths.append(pathOf(road.pts));
    }
    const QVector<QPainterPath> &paths = m_roadPaths;
    p->setBrush(Qt::NoBrush);
    for (int pass = 0; pass < 2; pass++) {
        for (int i : order) {
            const MapRoad &road = map.roads()[i];
            const RoadStyle st = roadStyle(road.cls);
            const double w = qBound(st.minPx, st.meters * m_zoom, 46.0);
            if (pass == 0) {
                if (!st.casing.isValid())
                    continue;
                p->setPen(cosmetic(st.casing, w + qMax(1.5, w * 0.25)));
            } else if (st.dashed || road.privateAccess) {
                p->setPen(cosmetic(st.fill, qMax(1.0, w * 0.7), Qt::DashLine));
            } else {
                p->setPen(cosmetic(st.fill, w));
            }
            p->drawPath(paths[i]);
        }
    }

    // Sens uniques, de près : une flèche discrète au milieu des longs tronçons.
    if (m_zoom > 0.9) {
        p->setPen(Qt::NoPen);
        p->setBrush(QColor(255, 255, 255, 60));
        const QTransform tw = world();
        for (int i : order) {
            const MapRoad &road = map.roads()[i];
            if (!road.oneway || road.roundabout)
                continue;
            for (int s = 0; s + 1 < road.pts.size(); s++) {
                QPointF a = tw.map(road.pts[s]), b = tw.map(road.pts[s + 1]);
                if (road.oneway < 0)
                    std::swap(a, b);
                const QPointF d = b - a;
                const double len = std::hypot(d.x(), d.y());
                if (len < 70)
                    continue;
                const QPointF u = d / len, n(-u.y(), u.x());
                const QPointF m = (a + b) / 2;
                p->save();
                p->resetTransform();
                QPolygonF tri;
                tri << m + u * 6 << m - u * 4 + n * 4 << m - u * 4 - n * 4;
                p->drawPolygon(tri);
                p->restore();
            }
        }
    }
}

void MapView::drawRoutes(QPainter *p) const
{
    const Navigation *nav = Navigation::instance();
    const QVector<Route> &routes = nav->routeObjects();
    if (routes.isEmpty() || nav->state() == QLatin1String("idle"))
        return;
    const double w = qBound(6.0, 11 * m_zoom + 3, 22.0);
    p->setBrush(Qt::NoBrush);

    // Les alternatives, dessous, en gris : on voit qu'elles existent, on
    // touche pour les choisir.
    for (int i = 0; i < routes.size(); i++) {
        if (i == nav->selectedRoute())
            continue;
        const QPainterPath path = pathOf(routes[i].pts);
        p->setPen(cosmetic(kRouteAltCasing, w + 3));
        p->drawPath(path);
        p->setPen(cosmetic(kRouteAlt, w));
        p->drawPath(path);
    }

    const Route &r = routes[nav->selectedRoute()];
    const bool guiding = nav->state() == QLatin1String("guiding") || nav->state() == QLatin1String("arrived");
    const double along = guiding ? nav->alongRoute() : 0;

    // Ce qui reste à faire, en bleu ; ce qui est fait, en gris.
    QPolygonF done, todo;
    int seg = 0;
    const QPointF cut = MapData::pointAt(r, along, nullptr, &seg);
    for (int i = 0; i <= seg; i++)
        done << r.pts[i];
    done << cut;
    todo << cut;
    for (int i = seg + 1; i < r.pts.size(); i++)
        todo << r.pts[i];

    if (guiding && along > 1) {
        p->setPen(cosmetic(kRouteDone, w * 0.8));
        p->drawPath(pathOf(done));
    }
    const QPainterPath path = pathOf(todo);
    QColor glow = kRouteFill;
    glow.setAlpha(45);
    p->setPen(cosmetic(glow, w + 10));
    p->drawPath(path);
    p->setPen(cosmetic(kRouteCasing, w + 3));
    p->drawPath(path);
    p->setPen(cosmetic(kRouteFill, w));
    p->drawPath(path);
}

void MapView::drawLabels(QPainter *p, const MapData &map) const
{
    const Navigation *nav = Navigation::instance();
    const QTransform tw = world();
    const QRectF screen(0, 0, width(), height());
    QVector<QRectF> taken;
    auto free = [&](const QRectF &r) {
        for (const QRectF &t : taken)
            if (t.intersects(r))
                return false;
        return true;
    };

    // Le véhicule et la destination réservent leur place : aucune étiquette
    // ne vient les masquer.
    if (nav->hasPosition()) {
        const QPointF v = tw.map(QPointF(m_vx, m_vy));
        taken.append(QRectF(v - QPointF(26, 26), QSizeF(52, 52)));
    }
    if (nav->state() != QLatin1String("idle")) {
        const QPointF d = tw.map(nav->destinationPos());
        taken.append(QRectF(d - QPointF(18, 46), QSizeF(36, 50)));
    }

    // ---- noms de route : un écusson par route nommée, sur son plus long
    // tronçon visible.
    QFont shield(QStringLiteral("Inter"));
    shield.setPixelSize(12);
    shield.setWeight(QFont::Bold);
    p->setFont(shield);
    const QFontMetricsF sfm(shield);
    QHash<QString, QPair<double, QPointF>> bestSeg;
    for (const MapRoad &road : map.roads()) {
        if (road.name.isEmpty())
            continue;
        for (int s = 0; s + 1 < road.pts.size(); s++) {
            const QPointF a = tw.map(road.pts[s]), b = tw.map(road.pts[s + 1]);
            const QPointF m = (a + b) / 2;
            if (!screen.adjusted(40, 40, -40, -40).contains(m))
                continue;
            const double len = std::hypot(b.x() - a.x(), b.y() - a.y());
            if (len > bestSeg.value(road.name).first)
                bestSeg[road.name] = { len, m };
        }
    }
    for (auto it = bestSeg.cbegin(); it != bestSeg.cend(); ++it) {
        if (it.value().first < 30)
            continue;
        const double w = sfm.horizontalAdvance(it.key()) + 14;
        const QRectF r(it.value().second - QPointF(w / 2, 10), QSizeF(w, 20));
        if (!free(r))
            continue;
        taken.append(r);
        p->setPen(QPen(QColor("#7f1d1d"), 1));
        p->setBrush(QColor("#dc2626"));
        p->drawRoundedRect(r, 5, 5);
        p->setPen(Qt::white);
        p->drawText(r, Qt::AlignCenter, it.key());
    }

    // ---- lieux, par ordre d'importance ----
    QVector<int> order;
    for (int i = 0; i < map.places().size(); i++)
        order.append(i);
    std::sort(order.begin(), order.end(), [&](int a, int b) {
        const MapPlace &pa = map.places()[a], &pb = map.places()[b];
        const bool sa = pa.id == m_selected || pa.id == nav->destinationId();
        const bool sb = pb.id == m_selected || pb.id == nav->destinationId();
        if (sa != sb)
            return sa;
        return placePriority(pa.category) < placePriority(pb.category);
    });

    QFont label(QStringLiteral("Inter"));
    label.setPixelSize(13);
    label.setWeight(QFont::Medium);
    QFont village(QStringLiteral("Inter"));
    village.setPixelSize(14);
    village.setWeight(QFont::DemiBold);
    village.setLetterSpacing(QFont::PercentageSpacing, 104);
    QFont glyph(QStringLiteral("Phosphor-Fill"));
    glyph.setPixelSize(13);

    for (int i : order) {
        const MapPlace &pl = map.places()[i];
        const bool forced = pl.id == m_selected || pl.id == nav->destinationId();
        if (!forced && m_zoom < placeMinZoom(pl.category))
            continue;
        const QPointF s = tw.map(pl.pos);
        if (!screen.contains(s))
            continue;

        if (pl.category == QLatin1String("village")) {
            p->setFont(village);
            const QFontMetricsF fm(village);
            const double w = fm.horizontalAdvance(pl.name);
            const QRectF r(s.x() - w / 2 - 2, s.y() - 12, w + 4, 18);
            if (!forced && !free(r))
                continue;
            taken.append(r);
            haloText(p, QPointF(s.x(), s.y() + 4), pl.name, kTextMuted, true);
            continue;
        }

        p->setFont(label);
        const QFontMetricsF fm(label);
        const double tw2 = fm.horizontalAdvance(pl.name);
        const QRectF dot(s - QPointF(11, 11), QSizeF(22, 22));
        const QRectF text(s.x() + 14, s.y() - 9, tw2 + 4, 18);
        if (!forced && !free(dot))
            continue;
        const bool withText = forced || free(text);
        taken.append(dot);
        if (withText)
            taken.append(text);

        const QColor c = categoryColor(pl.category);
        p->setPen(QPen(kHalo, 2));
        p->setBrush(forced ? c : c.darker(160));
        p->drawEllipse(dot);
        p->setFont(glyph);
        p->setPen(forced ? Qt::white : c.lighter(130));
        p->drawText(dot, Qt::AlignCenter, categoryGlyph(pl.category));
        if (withText) {
            p->setFont(label);
            haloText(p, QPointF(text.left() + 2, s.y() + 4.5), pl.name, forced ? Qt::white : kText);
        }
    }
}

void MapView::drawMarkers(QPainter *p) const
{
    const Navigation *nav = Navigation::instance();
    const QTransform tw = world();
    const QString state = nav->state();
    if (state == QLatin1String("idle"))
        return;

    // Prochaine manœuvre, en guidage : un point blanc là où il faudra tourner.
    if (state == QLatin1String("guiding")) {
        const QVariantMap next = nav->nextStep();
        if (!next.isEmpty()) {
            const QPointF m = tw.map(QPointF(next.value("x").toDouble(), next.value("y").toDouble()));
            p->setPen(QPen(kRouteCasing, 3));
            p->setBrush(Qt::white);
            p->drawEllipse(m, 6, 6);
        }
    }

    // Départ choisi (autre que la navette) : un anneau blanc.
    if (!nav->originId().isEmpty()) {
        const int i = nav->map().placeIndex(nav->originId());
        if (i >= 0) {
            const QPointF o = tw.map(nav->map().places()[i].pos);
            p->setPen(QPen(QColor("#1e293b"), 3));
            p->setBrush(Qt::white);
            p->drawEllipse(o, 9, 9);
            p->setBrush(QColor("#1e293b"));
            p->setPen(Qt::NoPen);
            p->drawEllipse(o, 3.5, 3.5);
        }
    }

    // Destination : l'épingle, pointe sur le lieu.
    const QPointF d = tw.map(nav->destinationPos());
    QPainterPath pin;
    pin.moveTo(d);
    pin.cubicTo(d + QPointF(-4, -10), d + QPointF(-15, -18), d + QPointF(-15, -30));
    pin.arcTo(QRectF(d.x() - 15, d.y() - 45, 30, 30), 180, -180);
    pin.cubicTo(d + QPointF(15, -18), d + QPointF(4, -10), d);
    p->setPen(QPen(QColor(0, 0, 0, 90), 4));
    p->setBrush(Qt::NoBrush);
    p->drawPath(pin.translated(0, 2));
    p->setPen(QPen(QColor("#7f1d1d"), 1.5));
    p->setBrush(kDestination);
    p->drawPath(pin);
    p->setPen(Qt::NoPen);
    p->setBrush(Qt::white);
    p->drawEllipse(d + QPointF(0, -30), 5.5, 5.5);
}

void MapView::drawVehicle(QPainter *p) const
{
    const Navigation *nav = Navigation::instance();
    if (!nav->hasPosition())
        return;
    const QString st = nav->positionState();
    const QPointF c = world().map(QPointF(m_vx, m_vy));
    const QColor color = st == QLatin1String("ok") ? kVehicle
                       : st == QLatin1String("estimated") ? kEstimated : kLost;

    p->save();
    p->translate(c);

    // Halo de précision : plein quand le GPS répond, en tirets quand la
    // position est estimée, absent quand elle n'est plus qu'un souvenir.
    if (st == QLatin1String("ok") || st == QLatin1String("estimated")) {
        QColor halo = color;
        halo.setAlpha(40);
        p->setBrush(halo);
        p->setPen(st == QLatin1String("estimated")
                      ? QPen(color, 1.5, Qt::DashLine) : QPen(QColor(color.red(), color.green(), color.blue(), 90), 1));
        p->drawEllipse(QPointF(0, 0), 26, 26);
    }

    p->setPen(QPen(QColor(0, 0, 0, 80), 4));
    p->setBrush(Qt::NoBrush);
    p->drawEllipse(QPointF(0, 1.5), 15, 15);
    p->setPen(Qt::NoPen);
    p->setBrush(Qt::white);
    p->drawEllipse(QPointF(0, 0), 15, 15);
    p->setBrush(color);
    p->drawEllipse(QPointF(0, 0), 12.5, 12.5);

    // La flèche, dans le sens de marche, relatif à l'orientation de la carte.
    p->rotate(m_vh - m_bearing);
    QPolygonF arrow;
    arrow << QPointF(0, -8) << QPointF(6.5, 6.5) << QPointF(0, 3) << QPointF(-6.5, 6.5);
    p->setBrush(st == QLatin1String("searching") || st == QLatin1String("lost") ? QColor("#d5deec") : QColor(Qt::white));
    p->drawPolygon(arrow);
    p->restore();
}
