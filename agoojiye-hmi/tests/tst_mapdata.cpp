// Tests unitaires de la carte : chargement, accroche à la route, itinéraire,
// consignes. Sans interface ni simulateur — MapData se teste seul, c'est fait
// pour.
//
//   ctest --test-dir build --output-on-failure        (ou ./test.sh)
//
// Deux cartes : une petite, écrite ici, dont chaque distance se calcule de
// tête ; et la vraie (map/gdiz.map.json), pour les propriétés qui doivent
// tenir sur le terrain.

#include "mapdata.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>

namespace {

//            D (100,100)
//            ▲  ╲
//   sens     │   ╲ D–C, double sens
//   unique   │    ╲
//   A ────── B ───── C          A(0,0)  B(100,0)  C(200,0)
//
// B→D est à sens unique. E–F (1000,1000)–(1100,1000) est un tronçon isolé.
QJsonObject road(const QString &cls, const QList<int> &nodes, const QList<double> &xy, int oneway = 0)
{
    QJsonObject r;
    r["c"] = cls;
    QJsonArray v, p;
    for (int n : nodes) v.append(n);
    for (double c : xy) p.append(c);
    r["v"] = v;
    r["p"] = p;
    if (oneway)
        r["o"] = oneway;
    return r;
}

QJsonObject smallMap()
{
    QJsonObject o;
    o["format"] = 1;
    o["name"] = "Carte d'essai";
    o["origin"] = QJsonArray{ 6.6, 2.25 };
    o["metersPerDegree"] = QJsonArray{ 111194.9, 110457.0 };
    o["extent"] = QJsonArray{ -500, -500, 1500, 1500 };
    o["nodeCount"] = 6;
    o["roads"] = QJsonArray{
        road("residential", { 0, 1, 2 }, { 0, 0, 100, 0, 200, 0 }),
        road("residential", { 1, 3 }, { 100, 0, 100, 100 }, 1),
        road("residential", { 3, 2 }, { 100, 100, 200, 0 }),
        road("residential", { 4, 5 }, { 1000, 1000, 1100, 1000 }),
    };
    QJsonObject place;
    place["id"] = "d";
    place["name"] = "Lieu D";
    place["cat"] = "porte";
    place["x"] = 100;
    place["y"] = 104;
    o["places"] = QJsonArray{ place };
    return o;
}

} // namespace

class TestMapData : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    int m_count = 0;

    QString write(const QJsonObject &o)
    {
        const QString path = m_dir.filePath(QStringLiteral("carte%1.json").arg(m_count++));
        QFile f(path);
        f.open(QIODevice::WriteOnly);
        f.write(QJsonDocument(o).toJson());
        return path;
    }

    bool loads(const QJsonObject &o, QString *error = nullptr)
    {
        MapData m;
        return m.load(write(o), error);
    }

private slots:
    // ---- chargement ----------------------------------------------------------
    void chargeLaPetiteCarte()
    {
        MapData m;
        QString err;
        QVERIFY2(m.load(write(smallMap()), &err), qPrintable(err));
        QCOMPARE(m.roads().size(), 4);
        QCOMPARE(m.places().size(), 1);
        QCOMPARE(m.placeIndex("d"), 0);
        QCOMPARE(m.placeIndex("inconnu"), -1);
    }

    // Une carte est une donnée : malformée, elle est refusée avec un message,
    // jamais lue au-delà de ses bornes. Chacun de ces cas faisait planter le
    // programme avant l'audit.
    void refuseUneCarteMalformee_data()
    {
        QTest::addColumn<QJsonObject>("map");
        QTest::addColumn<QString>("message");

        QJsonObject m = smallMap();
        QJsonArray roads = m["roads"].toArray();
        QJsonObject bad = roads[0].toObject();
        bad["v"] = QJsonArray{ 0, 999999, 2 };
        roads[0] = bad;
        m["roads"] = roads;
        QTest::newRow("noeud hors bornes") << m << "hors bornes";

        m = smallMap();
        roads = m["roads"].toArray();
        bad = roads[1].toObject();
        bad["v"] = QJsonArray{ -5, 3 };
        roads[1] = bad;
        m["roads"] = roads;
        QTest::newRow("noeud negatif") << m << "hors bornes";

        m = smallMap();
        m["nodeCount"] = 2;
        QTest::newRow("nodeCount trop petit") << m << "hors bornes";

        m = smallMap();
        m["nodeCount"] = 2000000000;
        QTest::newRow("nodeCount demesure") << m << "nombre de nœuds";

        m = smallMap();
        m["nodeCount"] = 0;
        QTest::newRow("nodeCount nul") << m << "nombre de nœuds";

        m = smallMap();
        m["metersPerDegree"] = QJsonArray{ 0, 0 };
        QTest::newRow("echelle nulle") << m << "échelle";

        m = smallMap();
        m.remove("extent");
        QTest::newRow("sans emprise") << m << "emprise";

        m = smallMap();
        m["roads"] = QJsonArray();
        QTest::newRow("sans routes") << m << "sans routes";

        m = smallMap();
        m["roads"] = QJsonArray{ road("footway", { 0, 1 }, { 0, 0, 100, 0 }) };
        QTest::newRow("sans route praticable") << m << "praticable";

        m = smallMap();
        m["format"] = 99;
        QTest::newRow("format inconnu") << m << "format";
    }
    void refuseUneCarteMalformee()
    {
        QFETCH(QJsonObject, map);
        QFETCH(QString, message);
        QString err;
        QVERIFY2(!loads(map, &err), "une carte malformée a été acceptée");
        QVERIFY2(err.contains(message), qPrintable("message inattendu : " + err));
    }

    void refuseUnFichierIllisible()
    {
        MapData m;
        QString err;
        QVERIFY(!m.load(m_dir.filePath("absent.json"), &err));
        QVERIFY(err.contains("introuvable"));

        const QString path = m_dir.filePath("tronque.json");
        QFile f(path);
        f.open(QIODevice::WriteOnly);
        f.write("{\"format\":1,\"roads\":[{\"c\":\"resid");
        f.close();
        QVERIFY(!m.load(path, &err));
        QVERIFY(err.contains("illisible"));
        QVERIFY(!m.isLoaded());
    }

    // Recharger après un échec ne garde rien de la carte précédente.
    void unEchecNeLaisseRien()
    {
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        QJsonObject bad = smallMap();
        bad["nodeCount"] = 0;
        QVERIFY(!m.load(write(bad)));
        QVERIFY(!m.isLoaded());
        QVERIFY(!m.snap(QPointF(50, 0)).valid());
    }

    // ---- accroche ------------------------------------------------------------
    void accrocheALaRouteLaPlusProche()
    {
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        const MapData::Snap s = m.snap(QPointF(50, 7));
        QVERIFY(s.valid());
        QCOMPARE(s.p, QPointF(50, 0));
        QCOMPARE(s.dist, 7.0);
    }

    void nAccrochePasAuTronconIsole()
    {
        // E–F ne mène nulle part : un départ posé dessus n'aurait aucun
        // itinéraire. On ne s'y accroche pas, même en étant dessus.
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        QVERIFY(!m.snap(QPointF(1050, 1000), qQNaN(), 100).valid());
    }

    void nAccrochePasTropLoin()
    {
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        QVERIFY(!m.snap(QPointF(50, 900), qQNaN(), 250).valid());
    }

    // ---- itinéraire ----------------------------------------------------------
    void prendLeSensUniqueDansLeBonSens()
    {
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        const Route r = m.route(m.snap(QPointF(100, 0)), m.snap(QPointF(100, 100)));
        QVERIFY(r.valid);
        QVERIFY2(qAbs(r.length - 100) < 0.5, qPrintable(QString::number(r.length)));
    }

    void neRemontePasUnSensUnique()
    {
        // De D vers B : le trajet direct (100 m) est interdit. Il faut passer
        // par C : 141,4 m + 100 m.
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        const Route r = m.route(m.snap(QPointF(100, 100)), m.snap(QPointF(100, 0)));
        QVERIFY(r.valid);
        QVERIFY2(qAbs(r.length - (std::sqrt(2.0) * 100 + 100)) < 1.0, qPrintable(QString::number(r.length)));
    }

    void itineraireSurLeMemeTroncon()
    {
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        const Route r = m.route(m.snap(QPointF(20, 0)), m.snap(QPointF(70, 0)));
        QVERIFY(r.valid);
        QVERIFY(qAbs(r.length - 50) < 0.5);
        QCOMPARE(r.steps.first().kind, RouteStep::Depart);
        QCOMPARE(r.steps.last().kind, RouteStep::Arrive);
    }

    void itineraireVersSoiMeme()
    {
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        const Route r = m.route(m.snap(QPointF(20, 0)), m.snap(QPointF(20, 0)));
        QVERIFY(r.valid);
        QVERIFY(r.length < 0.5);
    }

    void accrocheInvalideDonneAucunItineraire()
    {
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        QVERIFY(!m.route(MapData::Snap(), m.snap(QPointF(20, 0))).valid);
        QVERIFY(!m.route(m.snap(QPointF(20, 0)), MapData::Snap()).valid);
    }

    void ditLeCoteALArrivee()
    {
        // On arrive en D en roulant vers le nord ; le lieu est 4 m plus au
        // nord que la fin de route : ni à gauche ni à droite ne serait vrai
        // s'il était dans l'axe — ici il est posé dans l'axe, côté indéfini
        // ou gauche/droite selon l'arrondi : on vérifie seulement qu'un lieu
        // nettement à l'est est annoncé à droite.
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        const Route r = m.route(m.snap(QPointF(100, 0)), m.snap(QPointF(100, 60)),
                                "Lieu", QPointF(130, 60), true);
        QVERIFY(r.valid);
        QCOMPARE(r.steps.last().side, 1);
        const Route l = m.route(m.snap(QPointF(100, 0)), m.snap(QPointF(100, 60)),
                                "Lieu", QPointF(70, 60), true);
        QCOMPARE(l.steps.last().side, -1);
    }

    void cumulsCoherents()
    {
        MapData m;
        QVERIFY(m.load(write(smallMap())));
        const Route r = m.route(m.snap(QPointF(5, 0)), m.snap(QPointF(100, 95)));
        QVERIFY(r.valid);
        QCOMPARE(r.cum.size(), r.pts.size());
        QCOMPARE(r.cumTime.size(), r.pts.size());
        QCOMPARE(r.limit.size(), r.pts.size());
        QCOMPARE(r.roadOf.size(), r.pts.size());
        for (int i = 1; i < r.cum.size(); i++) {
            QVERIFY(r.cum[i] > r.cum[i - 1]);
            QVERIFY(r.cumTime[i] > r.cumTime[i - 1]);
        }
        QCOMPARE(r.limit.last(), 0.0);          // on s'arrête à l'arrivée
        QVERIFY(r.duration > 0);
        // pointAt : bornes et milieu.
        QCOMPARE(MapData::pointAt(r, -10), r.pts.first());
        QCOMPARE(MapData::pointAt(r, r.length + 10), r.pts.last());
        double heading = -1;
        MapData::pointAt(r, 10, &heading);
        QVERIFY(qAbs(heading - 90) < 0.5);      // plein est
    }

    // ---- la vraie carte --------------------------------------------------------
    void laCarteEmbarqueeSeCharge()
    {
        MapData m;
        QString err;
        QVERIFY2(m.load(QStringLiteral(MAP_FILE), &err), qPrintable(err));
        QVERIFY(m.places().size() >= 10);
        QVERIFY(!m.attribution().isEmpty());    // exigée par la licence ODbL
        QVERIFY(!m.zone().isEmpty());
    }

    void toutesLesDestinationsSontReliees()
    {
        MapData m;
        QVERIFY(m.load(QStringLiteral(MAP_FILE)));
        QVector<MapData::Snap> snaps;
        for (const MapPlace &p : m.places()) {
            snaps.append(m.snap(p.pos, qQNaN(), 250));
            QVERIFY2(snaps.last().valid(), qPrintable("lieu loin de toute route : " + p.id));
        }
        for (int a = 0; a < snaps.size(); a++)
            for (int b = 0; b < snaps.size(); b++) {
                if (a == b)
                    continue;
                const Route r = m.route(snaps[a], snaps[b]);
                QVERIFY2(r.valid, qPrintable(m.places()[a].id + " → " + m.places()[b].id));
                // Jamais plus court que le vol d'oiseau entre les deux accroches.
                const QPointF d = snaps[a].p - snaps[b].p;
                QVERIFY(r.length + 0.5 >= std::hypot(d.x(), d.y()));
            }
    }

    void lesAlternativesSontDistinctesEtRaisonnables()
    {
        MapData m;
        QVERIFY(m.load(QStringLiteral(MAP_FILE)));
        const int a = m.placeIndex("entree-nord"), b = m.placeIndex("lycee-lams");
        if (a < 0 || b < 0)
            QSKIP("lieux de référence absents de lieux.json");
        const QVector<Route> rs = m.routes(m.snap(m.places()[a].pos), m.snap(m.places()[b].pos), 3,
                                           "x", m.places()[b].pos, true);
        QVERIFY(!rs.isEmpty());
        for (int i = 1; i < rs.size(); i++) {
            QVERIFY(rs[i].duration >= rs[0].duration - 1e-6);       // la première est la plus rapide
            QVERIFY(rs[i].duration <= rs[0].duration * 1.6 + 1e-6);
        }
    }

    void conversionGeographiqueAllerRetour()
    {
        MapData m;
        QVERIFY(m.load(QStringLiteral(MAP_FILE)));
        const QPointF p(321.5, -987.25);
        double lat = 0, lon = 0;
        m.toGeo(p, &lat, &lon);
        const QPointF q = m.toLocal(lat, lon);
        QVERIFY(std::hypot(p.x() - q.x(), p.y() - q.y()) < 0.01);
    }

    // ---- outils ----------------------------------------------------------------
    void angles()
    {
        QCOMPARE(MapData::angleDiff(350, 10), 20.0);
        QCOMPARE(MapData::angleDiff(10, 350), -20.0);
        QCOMPARE(MapData::angleDiff(0, 180), 180.0);
        QCOMPARE(MapData::bearing(QPointF(0, 0), QPointF(0, 10)), 0.0);     // nord
        QCOMPARE(MapData::bearing(QPointF(0, 0), QPointF(10, 0)), 90.0);    // est
        QCOMPARE(MapData::bearing(QPointF(0, 0), QPointF(0, -10)), 180.0);  // sud
        QCOMPARE(MapData::bearing(QPointF(0, 0), QPointF(-10, 0)), 270.0);  // ouest
    }

    void formats()
    {
        QCOMPARE(MapData::formatDistance(4), QStringLiteral("10 m"));
        QCOMPARE(MapData::formatDistance(84), QStringLiteral("80 m"));
        QCOMPARE(MapData::formatDistance(260), QStringLiteral("250 m"));
        QCOMPARE(MapData::formatDistance(1540), QStringLiteral("1,5 km"));
        QCOMPARE(MapData::formatDistance(12400), QStringLiteral("12 km"));
        QCOMPARE(MapData::formatDistance(-1), QStringLiteral("- -"));
        QCOMPARE(MapData::formatDistance(qQNaN()), QStringLiteral("- -"));
        QCOMPARE(MapData::formatDuration(20), QStringLiteral("1 min"));
        QCOMPARE(MapData::formatDuration(61), QStringLiteral("2 min"));
        QCOMPARE(MapData::formatDuration(3900), QStringLiteral("1 h 05"));
        QCOMPARE(MapData::formatDuration(qInf()), QStringLiteral("- -"));
    }
};

QTEST_GUILESS_MAIN(TestMapData)
#include "tst_mapdata.moc"
