#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFontDatabase>
#include <QUrl>
#include <QQuickWindow>
#include <QTimer>
#include <QQmlComponent>
#include <QVariant>
#include <QStringList>
#include <QVariantList>
#include <cstdio>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("AGOOJIYE HMI");
    app.setOrganizationName("AGOOJIYE");

    QFontDatabase::addApplicationFont(":/AgoojiyeHMI/assets/fonts/phosphor/Phosphor-Regular.ttf");
    QFontDatabase::addApplicationFont(":/AgoojiyeHMI/assets/fonts/phosphor/Phosphor-Fill.ttf");
    QFontDatabase::addApplicationFont(":/AgoojiyeHMI/assets/fonts/inter/Inter-Regular.otf");
    QFontDatabase::addApplicationFont(":/AgoojiyeHMI/assets/fonts/inter/Inter-Medium.otf");
    QFontDatabase::addApplicationFont(":/AgoojiyeHMI/assets/fonts/inter/Inter-SemiBold.otf");
    QFontDatabase::addApplicationFont(":/AgoojiyeHMI/assets/fonts/inter/Inter-Bold.otf");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/AgoojiyeHMI/qml/Main.qml")));

    // QA aid: HMI_FAULT=<kind> injects a vehicle condition at startup, so the
    // alert chain can be exercised from the outside. It sits here rather than
    // inside one capture mode because a fault is a property of the run, not of
    // how the run happens to be observed.
    const QString fault = qEnvironmentVariable("HMI_FAULT");
    if (!fault.isEmpty() && !engine.rootObjects().isEmpty()) {
        QQmlComponent simProbe(&engine);
        simProbe.setData("import QtQml\nimport AgoojiyeHMI\n"
                         "QtObject { property QtObject sim: VehicleSimulator }", QUrl());
        QObject *simObj = simProbe.create();
        QObject *simulator = simObj ? simObj->property("sim").value<QObject *>() : nullptr;
        if (simulator)
            QMetaObject::invokeMethod(simulator, "injectFault", Q_ARG(QVariant, fault));
    }

    // Dev-only screenshot sweep: HMI_SCREENSHOT_DIR=<dir> walks every screen
    // and grabs a PNG per screen, then exits. Not used by the shipped app.
    const QString screenshotDir = qEnvironmentVariable("HMI_SCREENSHOT_DIR");
    if (!screenshotDir.isEmpty() && !engine.rootObjects().isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QQmlComponent appStateAccessor(&engine);
        appStateAccessor.setData(
            "import QtQml\nimport AgoojiyeHMI\nQtObject { property QtObject appState: AppState }", QUrl());
        QObject *accessorObj = appStateAccessor.create();
        QObject *appState = accessorObj ? accessorObj->property("appState").value<QObject *>() : nullptr;
        if (window && appState) {
            // The sweep documents the screens, not the startup sequence.
            QMetaObject::invokeMethod(appState, "skipBoot");

            // Every reachable panel, written as "screen" or "screen:section".
            // Screens with a left rail contribute one entry per section, so a
            // sweep covers the whole interface rather than its front pages.
            static const QStringList views = {
                "dash", "menu", "nav", "phone", "entretien",
                "veh:0", "veh:1", "veh:2", "veh:3", "veh:4", "veh:5",
                "conduite:0", "conduite:1", "conduite:2", "conduite:3", "conduite:4", "conduite:5",
                "adas:0", "adas:1", "adas:2", "adas:3", "adas:4", "adas:5",
                "media:0", "media:1", "media:2", "media:3", "media:4", "media:5",
                "mediaNow:0", "mediaNow:1", "mediaNow:2", "mediaNow:3",
                "parametres:0", "parametres:1", "parametres:2", "parametres:3", "parametres:4"
            };
            auto *index = new int(0);
            auto *timer = new QTimer(&app);
            timer->setInterval(250);
            QObject::connect(timer, &QTimer::timeout, &app, [=, &app]() mutable {
                if (*index > 0) {
                    QString name = views[*index - 1];
                    name.replace(':', '-');
                    window->grabWindow().save(screenshotDir + "/" + name + ".png");
                }
                if (*index >= views.size()) {
                    timer->stop();
                    app.quit();
                    return;
                }
                const QStringList parts = views[*index].split(':');
                QMetaObject::invokeMethod(appState, "go", Q_ARG(QVariant, parts.first()));
                if (parts.size() > 1) {
                    QMetaObject::invokeMethod(appState, "selectSection",
                                              Q_ARG(QVariant, parts.first()),
                                              Q_ARG(QVariant, parts.at(1).toInt()));
                }
                (*index)++;
            });
            timer->start();
        }
    }

    // QA aid: HMI_TRACE=<seconds> prints one CSV row of vehicle state per
    // 200 ms, then exits. It exists so the simulation can be checked as data
    // rather than by watching the screen — a coherence rule like "the parking
    // brake is never engaged while moving" is a column comparison here, and an
    // argument otherwise.
    const QString traceSeconds = qEnvironmentVariable("HMI_TRACE");
    if (!traceSeconds.isEmpty() && !engine.rootObjects().isEmpty()) {
        QQmlComponent probe(&engine);
        probe.setData("import QtQml\nimport AgoojiyeHMI\n"
                      "QtObject {\n"
                      "  property QtObject data: VehicleData\n"
                      "  property QtObject sim: VehicleSimulator\n"
                      "}",
                      QUrl());
        QObject *probeObj = probe.create();
        QObject *data = probeObj ? probeObj->property("data").value<QObject *>() : nullptr;
        QObject *simulator = probeObj ? probeObj->property("sim").value<QObject *>() : nullptr;
        if (data && simulator) {
            printf("t,phase,speed,power,regen,battery,consumption,range,gear,"
                   "parkingBrake,seatbeltWarning,tyreWarning,motorTemp,alerts,critical\n");
            auto *elapsed = new int(0);
            const int limit = traceSeconds.toInt() * 5;
            auto *timer = new QTimer(&app);
            timer->setInterval(200);
            QObject::connect(timer, &QTimer::timeout, &app, [=, &app]() mutable {
                const QVariantList alerts = data->property("activeAlerts").toList();
                printf("%.1f,%s,%.1f,%.1f,%.1f,%d,%.1f,%d,%s,%d,%d,%d,%d,%lld,%d\n",
                       *elapsed / 5.0,
                       qPrintable(simulator->property("phase").toString()),
                       data->property("speed").toDouble(),
                       data->property("power").toDouble(),
                       data->property("regenPower").toDouble(),
                       data->property("batteryLevel").toInt(),
                       data->property("consumption").toDouble(),
                       data->property("range").toInt(),
                       qPrintable(data->property("driveGear").toString()),
                       data->property("parkingBrake").toBool() ? 1 : 0,
                       data->property("seatbeltWarning").toBool() ? 1 : 0,
                       data->property("tyrePressureWarning").toBool() ? 1 : 0,
                       data->property("motorTemp").toInt(),
                       static_cast<long long>(alerts.size()),
                       data->property("hasCriticalAlert").toBool() ? 1 : 0);
                fflush(stdout);
                if (++(*elapsed) >= limit) {
                    timer->stop();
                    app.quit();
                }
            });
            timer->start();
        }
    }

    // Dev-only: HMI_BOOT_FRAMES=<dir> lets the startup animation play and grabs
    // a frame every 400 ms, so the sequence can be reviewed without a display.
    const QString bootDir = qEnvironmentVariable("HMI_BOOT_FRAMES");
    if (!bootDir.isEmpty() && !engine.rootObjects().isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        if (window) {
            auto *frame = new int(0);
            auto *timer = new QTimer(&app);
            timer->setInterval(400);
            QObject::connect(timer, &QTimer::timeout, &app, [=, &app]() mutable {
                window->grabWindow().save(
                    QString("%1/frame%2.png").arg(bootDir).arg(*frame, 2, 10, QChar('0')));
                if (++(*frame) >= 20) {
                    timer->stop();
                    app.quit();
                }
            });
            timer->start();
        }
    }

    return app.exec();
}
