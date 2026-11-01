#pragma once

#include <QHash>
#include <QPointF>
#include <QPolygonF>
#include <QRectF>
#include <QString>
#include <QVector>
#include <limits>

// La carte embarquée, et ce qu'on calcule dessus : accroche à la route,
// itinéraire, consignes de guidage.
//
// Aucune dépendance à QML ni à l'affichage : ce fichier se teste seul, et la
// même carte sert à l'écran, au guidage et au simulateur.
//
// Tout est en mètres, dans un repère local centré sur la zone : x vers l'est,
// y vers le nord. map/gdiz.map.json est déjà projeté ainsi (tools/map/build.py) ;
// seules les positions GPS passent par toLocal().

struct MapRoad {
    QString cls;            // type OSM : trunk, tertiary, service…
    QString name;           // nom, ou référence (« RNIE 2 »), ou vide
    int oneway = 0;         // 1 : dans le sens du tracé ; -1 : à rebours
    bool roundabout = false;
    bool privateAccess = false;
    bool drivable = false;
    bool mainNetwork = false;   // fait partie du réseau principal (d'un seul tenant)
    double speedKmh = 30;   // allure retenue pour le calcul de durée
    int rank = 0;           // importance, pour l'ordre de dessin
    QVector<int> nodes;     // un nœud du graphe par point du tracé
    QPolygonF pts;
    QRectF bounds;
};

struct MapPlace {
    QString id, name, category, note;
    QPointF pos;
};

struct MapArea {
    QString kind;
    QPolygonF poly;
};

// Un pas de guidage.
struct RouteStep {
    enum Kind { Depart, Turn, Keep, Roundabout, Arrive };
    Kind kind = Turn;
    int direction = 0;      // -2 demi-tour gauche … 0 tout droit … +2 demi-tour droit
    double angle = 0;       // degrés, positif à droite
    int exit = 0;           // rond-point : numéro de sortie
    double at = 0;          // distance depuis le départ, m
    QPointF pos;
    QString road;           // nom de la route prise, s'il existe
    QString landmark;       // repère proche (« Porte 5 »)
    int side = 0;           // arrivée : -1 à gauche, +1 à droite
    QString text;           // consigne complète : « Tournez à droite sur RNIE 2 »
    QString icon;           // icône Phosphor
};

struct Route {
    bool valid = false;
    QPolygonF pts;
    QVector<double> cum;        // distance cumulée à chaque point, m
    QVector<double> cumTime;    // durée cumulée à chaque point, s
    QVector<double> limit;      // vitesse conseillée au passage de chaque point, km/h
    QVector<int> roadOf;        // route empruntée par le tronçon i → i+1
    QVector<int> nodeAt;        // nœud du graphe au point i, ou -1
    QVector<quint64> keys;      // tronçon de carte emprunté par le tronçon i → i+1
    QVector<RouteStep> steps;
    double length = 0;
    double duration = 0;
    QString via;                // trait principal : « par RNIE 2 », « par Rond-point 3 »
    QRectF bounds;
};

class MapData
{
public:
    bool load(const QString &path, QString *error = nullptr);
    bool isLoaded() const { return m_loaded; }

    // ---- géographie ----
    QPointF toLocal(double lat, double lon) const;
    void toGeo(const QPointF &p, double *lat, double *lon) const;
    QRectF extent() const { return m_extent; }
    QString name() const { return m_name; }
    QString attribution() const { return m_attribution; }
    QString osmTimestamp() const { return m_osmTimestamp; }

    // ---- contenu ----
    const QVector<MapRoad> &roads() const { return m_roads; }
    const QVector<MapPlace> &places() const { return m_places; }
    const QVector<MapArea> &areas() const { return m_areas; }
    const QVector<QPolygonF> &buildings() const { return m_buildings; }
    const QVector<QPolygonF> &waterAreas() const { return m_waterAreas; }
    const QVector<QPolygonF> &waterLines() const { return m_waterLines; }
    const QVector<QPolygonF> &rails() const { return m_rails; }
    const QVector<QPointF> &gates() const { return m_gates; }
    QPolygonF zone() const { return m_zone; }
    int placeIndex(const QString &id) const;

    // ---- accroche à la route ----
    // Le point de route roulable le plus proche. Avec un cap (degrés depuis le
    // nord), un tronçon orienté à contresens coûte plus cher : sur une avenue
    // à deux chaussées, la navette est sur celle de son sens.
    struct Snap {
        int road = -1;
        int seg = -1;
        double t = 0;           // position sur le tronçon, 0..1
        QPointF p;
        double dist = std::numeric_limits<double>::infinity();
        bool valid() const { return road >= 0; }
    };
    Snap snap(const QPointF &p, double headingDeg = qQNaN(), double maxDist = 400) const;

    // ---- itinéraire ----
    // Le plus rapide, en respectant les sens uniques. `penalty` (optionnel)
    // multiplie le coût de certains tronçons : c'est ainsi qu'on cherche un
    // itinéraire alternatif.
    Route route(const Snap &from, const Snap &to, const QString &destinationName = QString(),
                const QPointF &destinationPos = QPointF(), bool destinationKnown = false,
                const QHash<quint64, double> *penalty = nullptr) const;

    // Jusqu'à `count` itinéraires distincts, le meilleur d'abord.
    QVector<Route> routes(const Snap &from, const Snap &to, int count,
                          const QString &destinationName, const QPointF &destinationPos,
                          bool destinationKnown) const;

    // Plusieurs itinéraires mis bout à bout (la boucle du simulateur).
    Route join(const QVector<Route> &parts) const;

    // Point et cap à `d` mètres du départ d'un itinéraire.
    static QPointF pointAt(const Route &r, double d, double *heading = nullptr, int *segment = nullptr);

    // Temps de trajet depuis `from` vers chacun des nœuds (Dijkstra) : sert
    // à classer les destinations par distance réelle, pas à vol d'oiseau.
    struct Field {
        QVector<double> time, len;
    };
    Field distancesFrom(const Snap &from) const;
    double distanceTo(const Field &field, const Snap &to) const;    // m, ou infini

    static double bearing(const QPointF &a, const QPointF &b);
    static double angleDiff(double a, double b);    // b - a, ramené dans ]-180, 180]
    static QString formatDistance(double meters);
    static QString formatDuration(double seconds);
    static QString cardinal(double bearingDeg);

    int nodeCount() const { return m_nodePos.size(); }

private:
    struct Edge {
        int to;
        int road;
        int seg;
        bool forward;
        double len;
        double time;
    };

    void buildGraph();
    void finishRoute(Route &r, const QString &destinationName, const QPointF &destinationPos,
                     bool destinationKnown) const;
    void buildSteps(Route &r, const QString &destinationName, const QPointF &destinationPos,
                    bool destinationKnown) const;
    void buildSpeedLimits(Route &r) const;
    QString landmarkNear(const QPointF &p, double radius, bool withArticle = false) const;
    static quint64 edgeKey(int road, int seg) { return (quint64(road) << 32) | quint32(seg); }

    bool m_loaded = false;
    QString m_name, m_attribution, m_osmTimestamp;
    double m_lat0 = 0, m_lon0 = 0, m_kLat = 1, m_kLon = 1;
    QRectF m_extent;
    QPolygonF m_zone;
    QVector<MapRoad> m_roads;
    QVector<MapPlace> m_places;
    QVector<MapArea> m_areas;
    QVector<QPolygonF> m_buildings, m_waterAreas, m_waterLines, m_rails;
    QVector<QPointF> m_gates;

    QVector<QPointF> m_nodePos;
    QVector<QVector<Edge>> m_adj;
    QVector<int> m_degree;      // nombre de voisins roulables distincts, tous sens confondus
};
