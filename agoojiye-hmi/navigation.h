#pragma once

#include "mapdata.h"

#include <QElapsedTimer>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

// La navigation de la navette : carte, choix de la destination, itinéraire,
// guidage. Singleton QML (`Navigation`).
//
//   VehicleData (position GPS, vitesse) ──► Navigation ──► écran, annonces,
//                                                          simulateur
//
// Elle ne lit rien elle-même : Main.qml lui pose la position et la vitesse
// (gpsLatitude…, vehicleSpeed). Le vrai GPS et le simulateur passent donc par
// le même chemin, et ce fichier ne sait pas lequel des deux parle.
//
// Sans connexion réseau : la carte est embarquée, l'itinéraire se calcule ici.
// Sans GPS : la position est estimée quelques secondes (vitesse des roues,
// le long de la route suivie), puis déclarée perdue — jamais inventée.
class Navigation : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // ---- carte ----
    Q_PROPERTY(bool ready READ ready CONSTANT)
    Q_PROPERTY(QString loadError READ loadError CONSTANT)
    Q_PROPERTY(QString mapName READ mapName CONSTANT)
    Q_PROPERTY(QString attribution READ attribution CONSTANT)
    Q_PROPERTY(QString mapDate READ mapDate CONSTANT)
    Q_PROPERTY(QRectF extent READ extent CONSTANT)
    Q_PROPERTY(QVariantList places READ places CONSTANT)

    // ---- entrées : posées par Main.qml ----
    Q_PROPERTY(double gpsLatitude MEMBER m_gpsLat)
    Q_PROPERTY(double gpsLongitude MEMBER m_gpsLon)
    Q_PROPERTY(double gpsHeading MEMBER m_gpsHeading)
    Q_PROPERTY(bool gpsFix MEMBER m_gpsFix)
    Q_PROPERTY(double vehicleSpeed MEMBER m_speed)

    // ---- position affichée ----
    Q_PROPERTY(bool hasPosition READ hasPosition NOTIFY positionChanged)
    Q_PROPERTY(double vehicleX READ vehicleX NOTIFY positionChanged)
    Q_PROPERTY(double vehicleY READ vehicleY NOTIFY positionChanged)
    Q_PROPERTY(double vehicleHeading READ vehicleHeading NOTIFY positionChanged)
    // "ok" · "estimated" (signal perdu, position estimée) · "lost" · "searching"
    Q_PROPERTY(QString positionState READ positionState NOTIFY positionStateChanged)
    Q_PROPERTY(QString currentRoad READ currentRoad NOTIFY positionChanged)

    // ---- itinéraire ----
    // "idle" · "preview" (itinéraires proposés) · "guiding" · "arrived"
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString destinationId READ destinationId NOTIFY routesChanged)
    Q_PROPERTY(QString destinationName READ destinationName NOTIFY routesChanged)
    Q_PROPERTY(QString originId READ originId NOTIFY routesChanged)
    Q_PROPERTY(QString originName READ originName NOTIFY routesChanged)
    Q_PROPERTY(QVariantList routes READ routeList NOTIFY routesChanged)
    Q_PROPERTY(int selectedRoute READ selectedRoute NOTIFY routesChanged)
    Q_PROPERTY(QString routeError READ routeError NOTIFY routesChanged)

    // ---- guidage ----
    Q_PROPERTY(QVariantMap nextStep READ nextStep NOTIFY guidanceChanged)
    Q_PROPERTY(QVariantMap thenStep READ thenStep NOTIFY guidanceChanged)
    Q_PROPERTY(QVariantList upcomingSteps READ upcomingSteps NOTIFY guidanceChanged)
    Q_PROPERTY(double remainingDistance READ remainingDistance NOTIFY guidanceChanged)
    Q_PROPERTY(double remainingTime READ remainingTime NOTIFY guidanceChanged)
    Q_PROPERTY(QString arrivalTime READ arrivalTime NOTIFY guidanceChanged)
    Q_PROPERTY(double progress READ progress NOTIFY guidanceChanged)
    Q_PROPERTY(bool offRoute READ offRoute NOTIFY guidanceChanged)
    Q_PROPERTY(bool voiceGuidance READ voiceGuidance WRITE setVoiceGuidance NOTIFY voiceGuidanceChanged)
    Q_PROPERTY(QStringList recents READ recents NOTIFY recentsChanged)

    // ---- pour le simulateur ----
    // Le chemin que suit la navette simulée : l'itinéraire pendant le guidage,
    // une boucle de service dans la zone sinon. Points [lat, lon, distance m].
    Q_PROPERTY(QVariantList drivePath READ drivePath NOTIFY drivePathChanged)
    Q_PROPERTY(int drivePathVersion READ drivePathVersion NOTIFY drivePathChanged)
    Q_PROPERTY(double drivePathLoopFrom READ drivePathLoopFrom NOTIFY drivePathChanged)
    Q_PROPERTY(double advisedSpeed READ advisedSpeed NOTIFY guidanceChanged)

public:
    explicit Navigation(QObject *parent = nullptr);
    static Navigation *instance() { return s_instance; }

    const MapData &map() const { return m_map; }
    const QVector<Route> &routeObjects() const { return m_routes; }
    double alongRoute() const { return m_along; }

    bool ready() const { return m_map.isLoaded(); }
    QString loadError() const { return m_loadError; }
    QString mapName() const { return m_map.name(); }
    QString attribution() const { return m_map.attribution(); }
    QString mapDate() const;
    QRectF extent() const { return m_map.extent(); }
    QVariantList places() const { return m_placeList; }

    bool hasPosition() const { return m_hasPosition; }
    double vehicleX() const { return m_pos.x(); }
    double vehicleY() const { return m_pos.y(); }
    QPointF vehiclePos() const { return m_pos; }
    double vehicleHeading() const { return m_heading; }
    QString positionState() const { return m_positionState; }
    QString currentRoad() const { return m_currentRoad; }

    QString state() const { return m_state; }
    QString destinationId() const { return m_destId; }
    QString destinationName() const { return m_destName; }
    QPointF destinationPos() const { return m_destPos; }
    QString originId() const { return m_originId; }
    QString originName() const;
    QVariantList routeList() const;
    int selectedRoute() const { return m_selected; }
    QString routeError() const { return m_routeError; }

    QVariantMap nextStep() const { return m_next; }
    QVariantMap thenStep() const { return m_then; }
    QVariantList upcomingSteps() const;
    double remainingDistance() const { return m_remaining; }
    double remainingTime() const { return m_remainingTime; }
    QString arrivalTime() const;
    double progress() const;
    bool offRoute() const { return m_offRoute; }
    bool voiceGuidance() const { return m_voice; }
    void setVoiceGuidance(bool on);
    QStringList recents() const { return m_recents; }

    QVariantList drivePath() const { return m_drivePath; }
    int drivePathVersion() const { return m_drivePathVersion; }
    double drivePathLoopFrom() const { return m_driveLoopFrom; }
    double advisedSpeed() const { return m_advised; }

    // ---- actions ----
    Q_INVOKABLE bool preview(const QString &placeId);
    Q_INVOKABLE bool previewPoint(double x, double y);
    Q_INVOKABLE bool setOrigin(const QString &placeId);     // "" : la position de la navette
    Q_INVOKABLE void selectRoute(int index);
    Q_INVOKABLE bool start();
    Q_INVOKABLE void stop();

    // ---- requêtes pour l'écran ----
    Q_INVOKABLE QString placeAt(double x, double y, double radius) const;
    Q_INVOKABLE QVariantMap place(const QString &id) const;
    Q_INVOKABLE QVariantMap roadDistances() const;      // id → mètres par la route
    Q_INVOKABLE QString describePoint(double x, double y) const;
    Q_INVOKABLE QString formatDistance(double meters) const { return MapData::formatDistance(meters); }
    Q_INVOKABLE QString formatDuration(double seconds) const { return MapData::formatDuration(seconds); }
    Q_INVOKABLE QString categoryIcon(const QString &category) const;
    Q_INVOKABLE QString categoryLabel(const QString &category) const;

    // ---- recette ----
    // Itinéraire entre chaque paire de destinations : tous doivent exister,
    // aucun ne doit prendre un sens unique à rebours.
    Q_INVOKABLE QVariantMap selfCheck() const;
    // Pendant le guidage : écart maximal au tracé, nombre de recalculs.
    Q_INVOKABLE QVariantMap diagnostics() const;

signals:
    void positionChanged();
    void positionStateChanged();
    void stateChanged();
    void routesChanged();
    void guidanceChanged();
    void voiceGuidanceChanged();
    void recentsChanged();
    void drivePathChanged();
    // Une consigne à dire. Main.qml la confie à la synthèse vocale.
    void announce(const QString &text);
    void arrived(const QString &name);

private:
    void tick();
    void updatePosition(double dt);
    void track(const Route &path, double *along, int *index, double *distFromPath) const;
    void updateGuidance();
    void updateAdvisedSpeed(const Route &path, double along, bool stopAtEnd);
    void computeRoutes();
    void reroute();
    void setState(const QString &s);
    void setPositionState(const QString &s);
    void setDrivePath(const Route &r, double loopFrom);
    void buildCircuit();
    void returnToCircuit();
    QVariantMap stepMap(const RouteStep &s, double distance) const;
    QString spokenDistance(double m) const;
    QString spoken(const RouteStep &s) const;
    void remember(const QString &id);
    void persist();

    static Navigation *s_instance;
    MapData m_map;
    QString m_loadError;
    QVariantList m_placeList;
    bool m_persist = true;

    // entrées
    double m_gpsLat = qQNaN(), m_gpsLon = qQNaN(), m_gpsHeading = qQNaN();
    bool m_gpsFix = false;
    double m_speed = 0;

    // position
    QTimer m_timer;
    QElapsedTimer m_clock;
    qint64 m_lastTick = 0;
    bool m_hasPosition = false, m_everFixed = false;
    QPointF m_pos;
    double m_heading = 0;
    QString m_positionState = QStringLiteral("searching");
    double m_lostSince = 0, m_lostDistance = 0;
    QString m_currentRoad;
    double m_savedTimer = 0;

    // itinéraire
    QString m_state = QStringLiteral("idle");
    QString m_destId, m_destName, m_originId;
    QPointF m_destPos;
    QVector<Route> m_routes;
    int m_selected = 0;
    QString m_routeError;

    // guidage
    double m_along = 0;
    int m_alongIndex = 0;
    double m_offTime = 0;
    bool m_offRoute = false;
    double m_remaining = 0, m_remainingTime = 0;
    QVariantMap m_next, m_then;
    int m_nextIndex = -1;
    QSet<int> m_spokenFar, m_spokenNear;
    bool m_voice = true;
    QStringList m_recents;
    double m_arrivedFor = 0;
    double m_dt = 0.1;
    double m_maxDeviation = 0;
    int m_reroutes = 0;
    double m_previewRefresh = 0;

    // chemin du simulateur
    Route m_circuit;
    Route m_drive;
    QVariantList m_drivePath;
    int m_drivePathVersion = 0;
    double m_driveLoopFrom = -1;
    double m_driveAlong = 0;
    int m_driveIndex = 0;
    double m_advised = 0;
};
