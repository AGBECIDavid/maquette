#include "navigation.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QTime>
#include <QSettings>
#include <QtMath>
#include <algorithm>

Navigation *Navigation::s_instance = nullptr;

namespace {

constexpr double kTick = 0.1;               // s
constexpr double kComfortDecel = 0.9;       // m/s² — freinage d'anticipation, confortable
constexpr double kOffRouteMeters = 40;      // au-delà, on n'est plus sur l'itinéraire…
constexpr double kOffRouteSeconds = 2.5;    // …s'il dure
constexpr double kEstimateSeconds = 30;     // durée maximale d'estimation sans GPS
constexpr double kEstimateMeters = 300;     // distance maximale d'estimation sans GPS
constexpr double kArrivedMeters = 12;

// La boucle que suit la navette simulée quand elle n'a pas de destination :
// un tour de la zone par l'entrée, le bloc d'usines et les ronds-points.
// Si l'équipe retire un de ces lieux, la boucle se fait avec les autres.
const char *kCircuit[] = { "entree-nord", "rp-3", "porte-12", "sipi-2", "rp-7", "rp-4", "rp-2" };

QString lowerFirst(const QString &s)
{
    return s.isEmpty() ? s : s.left(1).toLower() + s.mid(1);
}

QString ordinalWord(int n)
{
    static const char *words[] = { "", "première", "deuxième", "troisième", "quatrième",
                                   "cinquième", "sixième", "septième", "huitième" };
    return n >= 1 && n <= 8 ? QString::fromUtf8(words[n]) : QString::number(n) + QStringLiteral("e");
}

} // namespace

Navigation::Navigation(QObject *parent)
    : QObject(parent)
{
    s_instance = this;
    m_persist = !qEnvironmentVariableIsSet("AGOOJIYE_NO_PERSIST");

    const QString path = qEnvironmentVariable("AGOOJIYE_MAP", QStringLiteral(":/AgoojiyeHMI/map/gdiz.map.json"));
    if (!m_map.load(path, &m_loadError))
        qWarning("Carte : %s", qPrintable(m_loadError));

    for (const MapPlace &p : m_map.places()) {
        QVariantMap m;
        m["id"] = p.id;
        m["name"] = p.name;
        m["category"] = p.category;
        m["icon"] = categoryIcon(p.category);
        m["label"] = categoryLabel(p.category);
        m["note"] = p.note;
        m["x"] = p.pos.x();
        m["y"] = p.pos.y();
        m_placeList.append(m);
    }

    if (m_persist) {
        QSettings st;
        st.beginGroup(QStringLiteral("navigation"));
        m_voice = st.value(QStringLiteral("voice"), true).toBool();
        m_recents = st.value(QStringLiteral("recents")).toStringList();
        // La dernière position connue : c'est elle qu'on montre pendant que le
        // GPS cherche ses satellites au démarrage, plutôt qu'une carte vide.
        if (st.contains(QStringLiteral("lastX")) && m_map.isLoaded()) {
            m_pos = QPointF(st.value(QStringLiteral("lastX")).toDouble(),
                            st.value(QStringLiteral("lastY")).toDouble());
            m_heading = st.value(QStringLiteral("lastHeading")).toDouble();
            m_hasPosition = m_map.extent().adjusted(-2000, -2000, 2000, 2000).contains(m_pos);
        }
        st.endGroup();
    }
    m_recents.erase(std::remove_if(m_recents.begin(), m_recents.end(),
                                   [this](const QString &id) { return m_map.placeIndex(id) < 0; }),
                    m_recents.end());

    if (m_map.isLoaded()) {
        buildCircuit();
        setDrivePath(m_circuit, 0);
    }

    m_clock.start();
    m_timer.setInterval(int(kTick * 1000));
    connect(&m_timer, &QTimer::timeout, this, &Navigation::tick);
    if (m_map.isLoaded())
        m_timer.start();
}

QString Navigation::mapDate() const
{
    const QDateTime d = QDateTime::fromString(m_map.osmTimestamp(), Qt::ISODate);
    return d.isValid() ? d.toString(QStringLiteral("dd/MM/yyyy")) : QString();
}

QString Navigation::categoryIcon(const QString &c) const
{
    static const QHash<QString, QString> icons = {
        { "entree", "ph-signpost" }, { "porte", "ph-door" }, { "usine", "ph-factory" },
        { "service", "ph-buildings" }, { "sante", "ph-first-aid" }, { "commerce", "ph-storefront" },
        { "restauration", "ph-fork-knife" }, { "carburant", "ph-gas-pump" },
        { "ecole", "ph-graduation-cap" }, { "marche", "ph-basket" }, { "village", "ph-house-line" },
        { "repere", "ph-arrows-clockwise" },
    };
    return icons.value(c, QStringLiteral("ph-map-pin"));
}

QString Navigation::categoryLabel(const QString &c) const
{
    static const QHash<QString, QString> labels = {
        { "entree", "Entrée" }, { "porte", "Porte" }, { "usine", "Usine" }, { "service", "Service" },
        { "sante", "Santé" }, { "commerce", "Commerce" }, { "restauration", "Restauration" },
        { "carburant", "Carburant" }, { "ecole", "École" }, { "marche", "Marché" },
        { "village", "Village" }, { "repere", "Repère" },
    };
    return labels.value(c, QStringLiteral("Lieu"));
}

// ================================================================= position ==

void Navigation::tick()
{
    const qint64 now = m_clock.elapsed();
    const double dt = m_lastTick > 0 ? qBound(0.0, (now - m_lastTick) / 1000.0, 0.5) : kTick;
    m_lastTick = now;
    m_dt = dt;

    updatePosition(dt);

    // Le chemin du simulateur : on y suit la navette pour lui conseiller une
    // vitesse (ralentir avant un virage, s'arrêter à destination).
    if (m_drive.valid && m_hasPosition && m_positionState != QLatin1String("searching")) {
        double d = 0;
        track(m_drive, &m_driveAlong, &m_driveIndex, &d);
    }
    if (m_state == QLatin1String("guiding") || m_state == QLatin1String("arrived"))
        updateGuidance();
    else if (m_state == QLatin1String("preview") && m_originId.isEmpty()) {
        // Pendant qu'on choisit, la navette roule peut-être encore : les
        // itinéraires proposés partent de là où elle est, pas d'où elle était.
        m_previewRefresh += dt;
        if (m_previewRefresh > 5 && !m_routes.isEmpty() && m_speed > 1) {
            m_previewRefresh = 0;
            const QString via = m_routes.value(m_selected).via;
            computeRoutes();
            for (int i = 0; i < m_routes.size(); i++)
                if (m_routes[i].via == via)
                    m_selected = i;
            emit routesChanged();
        }
    }

    const bool stopAtEnd = m_driveLoopFrom < 0;
    if (m_state == QLatin1String("arrived"))
        m_advised = 0;
    else
        updateAdvisedSpeed(m_drive, m_driveAlong, stopAtEnd);

    m_savedTimer += dt;
    if (m_savedTimer > 10) {
        m_savedTimer = 0;
        persist();
    }
}

void Navigation::updatePosition(double dt)
{
    const bool fixOk = m_gpsFix && !qIsNaN(m_gpsLat) && !qIsNaN(m_gpsLon) && m_map.isLoaded();
    const QPointF before = m_pos;
    const double headingBefore = m_heading;

    if (fixOk) {
        m_pos = m_map.toLocal(m_gpsLat, m_gpsLon);
        // À l'arrêt, le cap GPS n'est que du bruit : on garde le dernier.
        if (!qIsNaN(m_gpsHeading) && (m_speed > 1.5 || !m_everFixed))
            m_heading = m_gpsHeading;
        m_hasPosition = true;
        m_everFixed = true;
        m_lostSince = 0;
        m_lostDistance = 0;
        setPositionState(QStringLiteral("ok"));
    } else if (m_everFixed) {
        // Signal perdu en route : on estime, à partir de la vitesse des roues,
        // le long de l'itinéraire s'il y en a un, sinon tout droit puis
        // rattaché à la route. Au-delà de 30 s ou 300 m, l'estimation ne vaut
        // plus rien : la position est déclarée perdue.
        const double step = m_speed / 3.6 * dt;
        m_lostSince += dt;
        m_lostDistance += step;
        if (m_lostSince <= kEstimateSeconds && m_lostDistance <= kEstimateMeters) {
            const bool onRoute = (m_state == QLatin1String("guiding")) && !m_routes.isEmpty();
            if (onRoute) {
                const Route &r = m_routes[m_selected];
                m_along = qMin(r.length, m_along + step);
                m_pos = MapData::pointAt(r, m_along, &m_heading);
            } else {
                const double h = qDegreesToRadians(m_heading);
                QPointF p = m_pos + QPointF(std::sin(h), std::cos(h)) * step;
                const MapData::Snap s = m_map.snap(p, m_heading, 20);
                m_pos = s.valid() ? s.p : p;
            }
            setPositionState(QStringLiteral("estimated"));
        } else {
            setPositionState(QStringLiteral("lost"));
        }
    } else {
        setPositionState(QStringLiteral("searching"));
    }

    if (m_pos != before || m_heading != headingBefore) {
        const MapData::Snap s = m_map.snap(m_pos, m_heading, 30);
        m_currentRoad = s.valid() ? m_map.roads()[s.road].name : QString();
        emit positionChanged();
    }
}

void Navigation::setPositionState(const QString &s)
{
    if (s == m_positionState)
        return;
    const QString old = m_positionState;
    m_positionState = s;
    emit positionStateChanged();
    if (m_state != QLatin1String("guiding"))
        return;
    if (s == QLatin1String("lost"))
        emit announce(QStringLiteral("Signal GPS perdu. Guidage suspendu."));
    else if (s == QLatin1String("ok") && old == QLatin1String("lost"))
        emit announce(QStringLiteral("Signal GPS retrouvé."));
}

void Navigation::track(const Route &path, double *along, int *index, double *distFromPath) const
{
    const int n = path.pts.size();
    if (n < 2)
        return;
    auto bestIn = [&](int from, int to, bool useHeading, int *bestSeg, double *bestT, double *bestD) {
        *bestD = std::numeric_limits<double>::infinity();
        for (int i = qMax(0, from); i < qMin(n - 1, to); i++) {
            const QPointF a = path.pts[i], b = path.pts[i + 1];
            const QPointF ab = b - a;
            const double l2 = ab.x() * ab.x() + ab.y() * ab.y();
            double t = l2 > 1e-9 ? ((m_pos.x() - a.x()) * ab.x() + (m_pos.y() - a.y()) * ab.y()) / l2 : 0;
            t = std::clamp(t, 0.0, 1.0);
            const QPointF q = a + ab * t;
            double d = std::hypot(m_pos.x() - q.x(), m_pos.y() - q.y());
            // En roulant, un tronçon parcouru à contresens ne compte pas :
            // sur une avenue à deux chaussées, ou une boucle qui repasse au
            // même endroit, c'est ce qui départage.
            if (useHeading && l2 > 1 && qAbs(MapData::angleDiff(MapData::bearing(a, b), m_heading)) > 100)
                d += 80;
            if (d < *bestD) {
                *bestD = d;
                *bestSeg = i;
                *bestT = t;
            }
        }
    };
    const bool useHeading = m_speed > 3;
    int seg = 0;
    double t = 0, d = 0;
    bestIn(*index - 3, *index + 60, useHeading, &seg, &t, &d);
    if (d > 60)
        bestIn(0, n, useHeading, &seg, &t, &d);
    *index = seg;
    *along = path.cum[seg] + (path.cum[seg + 1] - path.cum[seg]) * t;
    *distFromPath = d;
}

void Navigation::updateAdvisedSpeed(const Route &path, double along, bool stopAtEnd)
{
    double v = 50;
    const int n = path.pts.size();
    if (n >= 2) {
        int i = std::clamp(m_driveIndex, 0, n - 2);
        if (path.roadOf[i] >= 0)
            v = qMin(v, m_map.roads()[path.roadOf[i]].speedKmh);
        // La vitesse qu'il faut avoir maintenant pour respecter, en freinant
        // confortablement, chaque limite des 250 m à venir.
        for (int k = i + 1; k < n && path.cum[k] - along < 250; k++) {
            double lim = path.limit[k];
            if (k == n - 1 && !stopAtEnd)
                lim = path.limit[qMax(0, k - 1)];
            const double d = qMax(0.0, path.cum[k] - along);
            const double allowed = std::sqrt(std::pow(lim / 3.6, 2) + 2 * kComfortDecel * d) * 3.6;
            v = qMin(v, allowed);
        }
        if (stopAtEnd && path.length - along < 3)
            v = 0;
    }
    v = std::round(v);
    if (v != m_advised) {
        m_advised = v;
        emit guidanceChanged();
    }
}

// ================================================================== guidage ==

void Navigation::updateGuidance()
{
    if (m_routes.isEmpty())
        return;
    const Route &r = m_routes[m_selected];

    if (m_state == QLatin1String("arrived")) {
        // Le trajet est fini ; au bout d'un moment l'écran revient de lui-même
        // à la carte, comme un GPS qu'on ne touche pas.
        m_arrivedFor += m_dt;
        if (m_arrivedFor > 45)
            stop();
        return;
    }

    double d = 0;
    if (m_positionState == QLatin1String("ok")) {
        track(r, &m_along, &m_alongIndex, &d);
        m_maxDeviation = qMax(m_maxDeviation, d);
    }

    // Hors itinéraire : trop loin du tracé, assez longtemps, avec un signal
    // fiable. Une estimation sans GPS ne déclenche jamais de recalcul.
    const bool off = m_positionState == QLatin1String("ok") && d > kOffRouteMeters;
    m_offTime = off ? m_offTime + m_dt : 0;
    if (off != m_offRoute) {
        m_offRoute = off;
        emit guidanceChanged();
    }
    if (m_offTime > kOffRouteSeconds) {
        reroute();
        return;
    }

    m_remaining = qMax(0.0, r.length - m_along);
    {
        int seg = 0;
        MapData::pointAt(r, m_along, nullptr, &seg);
        const double segLen = r.cum[seg + 1] - r.cum[seg];
        const double f = segLen > 1e-9 ? (m_along - r.cum[seg]) / segLen : 0;
        const double tAlong = r.cumTime[seg] + (r.cumTime[seg + 1] - r.cumTime[seg]) * f;
        m_remainingTime = qMax(0.0, r.duration - tAlong);
    }

    // Prochaine consigne, et celle d'après si elle suit de près.
    int k = 1;
    while (k < r.steps.size() && r.steps[k].at <= m_along + 2)
        k++;
    k = qMin(k, r.steps.size() - 1);
    m_nextIndex = k;
    const RouteStep &next = r.steps[k];
    const double dn = qMax(0.0, next.at - m_along);
    m_next = stepMap(next, dn);
    m_then = QVariantMap();
    if (k + 1 < r.steps.size() && r.steps[k + 1].at - next.at < 150)
        m_then = stepMap(r.steps[k + 1], r.steps[k + 1].at - m_along);

    // ---- annonces vocales ----
    // Deux par consigne : une de loin pour se préparer, une au moment d'agir.
    // La distance « de loin » croît avec la vitesse ; elle est omise si la
    // consigne précédente est trop proche pour laisser le temps de la dire.
    if (next.kind != RouteStep::Arrive && m_positionState != QLatin1String("lost")) {
        const double v = m_speed / 3.6;
        const double far = m_speed > 35 ? 400 : 200;
        const double near = qMax(35.0, v * 5);
        const double gapBefore = next.at - r.steps[k - 1].at;
        if (dn <= far && dn > near + 60 && gapBefore > far * 0.6 && !m_spokenFar.contains(k)) {
            m_spokenFar.insert(k);
            emit announce(QStringLiteral("Dans ") + spokenDistance(dn) + QStringLiteral(", ")
                          + lowerFirst(spoken(next)) + QStringLiteral("."));
        }
        if (dn <= near && !m_spokenNear.contains(k)) {
            m_spokenNear.insert(k);
            m_spokenFar.insert(k);
            QString text = spoken(next);
            if (!m_then.isEmpty() && k + 1 < r.steps.size()) {
                const RouteStep &then = r.steps[k + 1];
                text += QStringLiteral(", puis ") + lowerFirst(spoken(then));
                m_spokenFar.insert(k + 1);
            }
            emit announce(text + QStringLiteral("."));
        }
    }

    // ---- arrivée ----
    if (m_remaining < kArrivedMeters || (m_remaining < 30 && m_speed < 1 && m_along > 0)) {
        const RouteStep &arr = r.steps.last();
        QString text = QStringLiteral("Vous êtes arrivé");
        if (!m_destName.isEmpty())
            text += QStringLiteral(" : ") + m_destName;
        if (arr.side != 0)
            text += arr.side > 0 ? QStringLiteral(". C'est sur votre droite")
                                 : QStringLiteral(". C'est sur votre gauche");
        m_arrivedFor = 0;
        m_remaining = 0;
        m_remainingTime = 0;
        m_next = stepMap(arr, 0);
        m_then = QVariantMap();
        setState(QStringLiteral("arrived"));
        emit announce(text + QStringLiteral("."));
        emit arrived(m_destName);
    }
    emit guidanceChanged();
}

QVariantMap Navigation::stepMap(const RouteStep &s, double distance) const
{
    QVariantMap m;
    m["icon"] = s.icon;
    m["text"] = s.text;
    m["distance"] = distance;
    m["distanceText"] = MapData::formatDistance(distance);
    m["exit"] = s.exit;
    m["kind"] = int(s.kind);
    m["side"] = s.side;
    m["x"] = s.pos.x();
    m["y"] = s.pos.y();
    return m;
}

QVariantList Navigation::upcomingSteps() const
{
    QVariantList out;
    if (m_routes.isEmpty())
        return out;
    const Route &r = m_routes[m_selected];
    for (int k = qMax(1, m_nextIndex); k < r.steps.size(); k++)
        out.append(stepMap(r.steps[k], r.steps[k].at - m_along));
    return out;
}

QString Navigation::spokenDistance(double m) const
{
    if (m < 1000) {
        const int r = m < 100 ? qMax(10, int(std::round(m / 10) * 10)) : int(std::round(m / 50) * 50);
        return QString::number(r) + QStringLiteral(" mètres");
    }
    const double km = std::round(m / 100) / 10;
    if (km == std::floor(km))
        return QString::number(int(km)) + (km >= 2 ? QStringLiteral(" kilomètres") : QStringLiteral(" kilomètre"));
    return QString::number(km, 'f', 1).replace('.', ',') + QStringLiteral(" kilomètres");
}

QString Navigation::spoken(const RouteStep &s) const
{
    // Le texte affiché, sauf pour les ronds-points : « 2ᵉ » se lit mal par la
    // synthèse vocale, « deuxième » se dit.
    if (s.kind == RouteStep::Arrive)
        return QStringLiteral("Vous arrivez à destination");
    if (s.kind != RouteStep::Roundabout)
        return s.text;
    const QString where = s.landmark.startsWith(QLatin1String("Rond-point"))
        ? QStringLiteral("Au ") + s.landmark : QStringLiteral("Au rond-point");
    return where + QStringLiteral(", prenez la ") + ordinalWord(s.exit) + QStringLiteral(" sortie")
         + (s.road.isEmpty() ? QString() : QStringLiteral(" vers ") + s.road);
}

QString Navigation::arrivalTime() const
{
    if (m_state != QLatin1String("guiding") && m_state != QLatin1String("arrived"))
        return QString();
    return QTime::currentTime().addSecs(int(m_remainingTime)).toString(QStringLiteral("HH:mm"));
}

double Navigation::progress() const
{
    if (m_routes.isEmpty())
        return 0;
    const double len = m_routes[m_selected].length;
    return len > 0 ? qBound(0.0, m_along / len, 1.0) : 1;
}

// ============================================================== itinéraires ==

QString Navigation::originName() const
{
    if (m_originId.isEmpty())
        return QStringLiteral("Ma position");
    const int i = m_map.placeIndex(m_originId);
    return i >= 0 ? m_map.places()[i].name : QString();
}

bool Navigation::preview(const QString &placeId)
{
    const int i = m_map.placeIndex(placeId);
    if (i < 0)
        return false;
    m_destId = placeId;
    m_destName = m_map.places()[i].name;
    m_destPos = m_map.places()[i].pos;
    if (m_originId == placeId)
        m_originId.clear();
    computeRoutes();
    setState(QStringLiteral("preview"));
    return !m_routes.isEmpty();
}

bool Navigation::previewPoint(double x, double y)
{
    m_destId.clear();
    m_destPos = QPointF(x, y);
    m_destName = describePoint(x, y);
    computeRoutes();
    setState(QStringLiteral("preview"));
    return !m_routes.isEmpty();
}

bool Navigation::setOrigin(const QString &placeId)
{
    if (!placeId.isEmpty() && m_map.placeIndex(placeId) < 0)
        return false;
    m_originId = placeId;
    if (m_state == QLatin1String("preview"))
        computeRoutes();
    else
        emit routesChanged();
    return true;
}

void Navigation::computeRoutes()
{
    m_routes.clear();
    m_selected = 0;
    m_routeError.clear();

    MapData::Snap from;
    if (m_originId.isEmpty()) {
        if (!m_hasPosition || m_positionState == QLatin1String("lost")) {
            m_routeError = QStringLiteral("Position inconnue : choisissez un point de départ.");
            emit routesChanged();
            return;
        }
        from = m_map.snap(m_pos, m_heading);
    } else {
        from = m_map.snap(m_map.places()[m_map.placeIndex(m_originId)].pos);
    }
    const MapData::Snap to = m_map.snap(m_destPos, qQNaN(), 250);
    if (!to.valid()) {
        m_routeError = QStringLiteral("Ce point est trop loin d'une route praticable.");
    } else if (!from.valid()) {
        m_routeError = QStringLiteral("La navette est trop loin d'une route praticable.");
    } else {
        m_routes = m_map.routes(from, to, 3, m_destName, m_destPos, true);
        if (m_routes.isEmpty())
            m_routeError = QStringLiteral("Aucun itinéraire praticable jusqu'à ce point.");
    }
    emit routesChanged();
}

QVariantList Navigation::routeList() const
{
    QVariantList out;
    const QTime now = QTime::currentTime();
    for (int i = 0; i < m_routes.size(); i++) {
        const Route &r = m_routes[i];
        QVariantMap m;
        m["distance"] = r.length;
        m["distanceText"] = MapData::formatDistance(r.length);
        m["duration"] = r.duration;
        m["durationText"] = MapData::formatDuration(r.duration);
        m["arrival"] = now.addSecs(int(r.duration)).toString(QStringLiteral("HH:mm"));
        m["via"] = r.via;
        m["fastest"] = i == 0;
        m["extra"] = i == 0 ? QString() : QStringLiteral("+ ") + MapData::formatDuration(r.duration - m_routes[0].duration);
        QVariantList steps;
        for (const RouteStep &s : r.steps)
            steps.append(stepMap(s, s.at));
        m["steps"] = steps;
        out.append(m);
    }
    return out;
}

void Navigation::selectRoute(int index)
{
    if (index < 0 || index >= m_routes.size() || index == m_selected)
        return;
    m_selected = index;
    emit routesChanged();
}

bool Navigation::start()
{
    if (m_routes.isEmpty() || !m_originId.isEmpty())
        return false;
    // Recalcul depuis la position du moment : depuis l'aperçu, la navette a
    // pu avancer. On garde l'itinéraire choisi s'il existe encore.
    const QString via = m_routes[m_selected].via;
    computeRoutes();
    if (m_routes.isEmpty())
        return false;
    for (int i = 0; i < m_routes.size(); i++)
        if (m_routes[i].via == via)
            m_selected = i;
    // Les alternatives ne servent plus : on ne garde que l'itinéraire suivi.
    const Route chosen = m_routes[m_selected];
    m_routes = { chosen };
    m_selected = 0;
    m_along = 0;
    m_alongIndex = 0;
    m_offTime = 0;
    m_offRoute = false;
    m_spokenFar.clear();
    m_spokenNear.clear();
    m_nextIndex = -1;
    m_maxDeviation = 0;
    m_reroutes = 0;
    setDrivePath(chosen, -1);
    if (!m_destId.isEmpty())
        remember(m_destId);
    setState(QStringLiteral("guiding"));
    emit routesChanged();

    QString intro = QStringLiteral("C'est parti pour ") + m_destName + QStringLiteral(" : ")
                  + spokenDistance(chosen.length) + QStringLiteral(", environ ")
                  + MapData::formatDuration(chosen.duration).replace(QStringLiteral("min"), QStringLiteral("minutes"))
                  + QStringLiteral(".");
    emit announce(intro);
    updateGuidance();
    return true;
}

void Navigation::reroute()
{
    m_offTime = 0;
    m_reroutes++;
    const QString name = m_destName;
    computeRoutes();
    if (m_routes.isEmpty()) {
        emit announce(QStringLiteral("Impossible de recalculer l'itinéraire."));
        return;
    }
    const Route chosen = m_routes[0];
    m_routes = { chosen };
    m_selected = 0;
    m_along = 0;
    m_alongIndex = 0;
    m_offRoute = false;
    m_spokenFar.clear();
    m_spokenNear.clear();
    setDrivePath(chosen, -1);
    emit routesChanged();
    emit announce(QStringLiteral("Nouvel itinéraire vers ") + name + QStringLiteral("."));
}

void Navigation::stop()
{
    m_routes.clear();
    m_selected = 0;
    m_destId.clear();
    m_destName.clear();
    m_originId.clear();
    m_routeError.clear();
    m_next = QVariantMap();
    m_then = QVariantMap();
    m_offRoute = false;
    setState(QStringLiteral("idle"));
    emit routesChanged();
    emit guidanceChanged();
    // Si la navette suivait un itinéraire (même abandonné pour un aperçu),
    // elle reprend sa boucle depuis là où elle est.
    if (m_driveLoopFrom < 0)
        returnToCircuit();
}

void Navigation::setState(const QString &s)
{
    if (s == m_state)
        return;
    m_state = s;
    emit stateChanged();
}

// ========================================================== chemin simulé ==

void Navigation::buildCircuit()
{
    QVector<MapData::Snap> stops;
    for (const char *id : kCircuit) {
        const int i = m_map.placeIndex(QString::fromLatin1(id));
        if (i >= 0)
            stops.append(m_map.snap(m_map.places()[i].pos));
    }
    for (int i = 0; stops.size() < 3 && i < m_map.places().size(); i++)
        stops.append(m_map.snap(m_map.places()[i].pos));
    QVector<Route> legs;
    for (int i = 0; i < stops.size(); i++)
        legs.append(m_map.route(stops[i], stops[(i + 1) % stops.size()]));
    m_circuit = m_map.join(legs);
}

void Navigation::returnToCircuit()
{
    if (!m_circuit.valid)
        return;
    if (!m_hasPosition) {
        setDrivePath(m_circuit, 0);
        return;
    }
    const MapData::Snap from = m_map.snap(m_pos, m_heading);
    const MapData::Snap to = m_map.snap(m_circuit.pts.first());
    const Route back = m_map.route(from, to);
    if (!back.valid) {
        setDrivePath(m_circuit, 0);
        return;
    }
    setDrivePath(m_map.join({ back, m_circuit }), back.length);
}

void Navigation::setDrivePath(const Route &r, double loopFrom)
{
    m_drive = r;
    m_driveLoopFrom = loopFrom;
    m_driveAlong = 0;
    m_driveIndex = 0;
    m_drivePath.clear();
    for (int i = 0; i < r.pts.size(); i++) {
        double lat, lon;
        m_map.toGeo(r.pts[i], &lat, &lon);
        m_drivePath.append(QVariant(QVariantList{ lat, lon, r.cum[i] }));
    }
    m_drivePathVersion++;
    emit drivePathChanged();
}

// ================================================================ requêtes ==

QString Navigation::placeAt(double x, double y, double radius) const
{
    QString best;
    double bestD = radius;
    for (const MapPlace &p : m_map.places()) {
        const double d = std::hypot(p.pos.x() - x, p.pos.y() - y);
        if (d < bestD) {
            bestD = d;
            best = p.id;
        }
    }
    return best;
}

QVariantMap Navigation::place(const QString &id) const
{
    const int i = m_map.placeIndex(id);
    return i >= 0 ? m_placeList[i].toMap() : QVariantMap();
}

QVariantMap Navigation::roadDistances() const
{
    QVariantMap out;
    if (!m_hasPosition)
        return out;
    const MapData::Field f = m_map.distancesFrom(m_map.snap(m_pos, m_heading));
    for (const MapPlace &p : m_map.places()) {
        const double d = m_map.distanceTo(f, m_map.snap(p.pos));
        if (std::isfinite(d))
            out[p.id] = d;
    }
    return out;
}

QString Navigation::describePoint(double x, double y) const
{
    const QPointF p(x, y);
    const MapPlace *best = nullptr;
    double bestD = 150;
    for (const MapPlace &pl : m_map.places()) {
        const double d = std::hypot(pl.pos.x() - x, pl.pos.y() - y);
        if (d < bestD) {
            bestD = d;
            best = &pl;
        }
    }
    if (best)
        return QStringLiteral("Près de ") + best->name;
    const MapData::Snap s = m_map.snap(p, qQNaN(), 80);
    if (s.valid() && !m_map.roads()[s.road].name.isEmpty())
        return QStringLiteral("Sur ") + m_map.roads()[s.road].name;
    return QStringLiteral("Point sur la carte");
}

void Navigation::setVoiceGuidance(bool on)
{
    if (on == m_voice)
        return;
    m_voice = on;
    emit voiceGuidanceChanged();
    persist();
}

void Navigation::remember(const QString &id)
{
    m_recents.removeAll(id);
    m_recents.prepend(id);
    while (m_recents.size() > 5)
        m_recents.removeLast();
    emit recentsChanged();
    persist();
}

void Navigation::persist()
{
    if (!m_persist)
        return;
    QSettings st;
    st.beginGroup(QStringLiteral("navigation"));
    st.setValue(QStringLiteral("voice"), m_voice);
    st.setValue(QStringLiteral("recents"), m_recents);
    if (m_everFixed && m_positionState == QLatin1String("ok")) {
        st.setValue(QStringLiteral("lastX"), m_pos.x());
        st.setValue(QStringLiteral("lastY"), m_pos.y());
        st.setValue(QStringLiteral("lastHeading"), m_heading);
    }
    st.endGroup();
}

// ================================================================== recette ==

QVariantMap Navigation::selfCheck() const
{
    QElapsedTimer t;
    t.start();
    const QVector<MapPlace> &places = m_map.places();
    QVector<MapData::Snap> snaps;
    QStringList unsnapped;
    for (const MapPlace &p : places) {
        snaps.append(m_map.snap(p.pos, qQNaN(), 250));
        if (!snaps.last().valid())
            unsnapped << p.id;
    }
    int pairs = 0, wrongWay = 0;
    QStringList failures;
    for (int a = 0; a < places.size(); a++) {
        for (int b = 0; b < places.size(); b++) {
            if (a == b || !snaps[a].valid() || !snaps[b].valid())
                continue;
            pairs++;
            const Route r = m_map.route(snaps[a], snaps[b]);
            if (!r.valid) {
                failures << places[a].id + QStringLiteral("→") + places[b].id;
                continue;
            }
            // Chaque tronçon parcouru dans le sens permis : on compare l'ordre
            // des points de l'itinéraire à celui du tracé de la route.
            for (int i = 0; i + 1 < r.pts.size(); i++) {
                const quint64 key = r.keys[i];
                const int road = int(key >> 32), seg = int(key & 0xffffffff);
                if (road < 0 || road >= m_map.roads().size())
                    continue;
                const MapRoad &rd = m_map.roads()[road];
                if (!rd.oneway || seg + 1 >= rd.pts.size())
                    continue;
                const QPointF dir = rd.pts[seg + 1] - rd.pts[seg];
                const QPointF go = r.pts[i + 1] - r.pts[i];
                const double dot = dir.x() * go.x() + dir.y() * go.y();
                if ((rd.oneway > 0 && dot < -1e-6) || (rd.oneway < 0 && dot > 1e-6))
                    wrongWay++;
            }
        }
    }
    QVariantMap m;
    m["places"] = int(places.size());
    m["pairs"] = pairs;
    m["failures"] = failures;
    m["unsnapped"] = unsnapped;
    m["wrongWay"] = wrongWay;
    m["ms"] = qint64(t.elapsed());
    return m;
}

QVariantMap Navigation::diagnostics() const
{
    QVariantMap m;
    m["maxDeviation"] = m_maxDeviation;
    m["reroutes"] = m_reroutes;
    m["along"] = m_along;
    return m;
}
