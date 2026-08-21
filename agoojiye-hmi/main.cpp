#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFontDatabase>
#include <QUrl>
#include <QQuickWindow>
#include <QTimer>
#include <QQmlComponent>
#include <QVariant>
#include <QStringList>

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
            static const QStringList screens = {
                "dash", "menu", "veh", "nav", "media",
                "mediaNow", "adas", "conduite", "phone", "entretien", "parametres"
            };
            auto *index = new int(0);
            auto *timer = new QTimer(&app);
            timer->setInterval(250);
            QObject::connect(timer, &QTimer::timeout, &app, [=, &app]() mutable {
                if (*index > 0) {
                    window->grabWindow().save(screenshotDir + "/" + screens[*index - 1] + ".png");
                }
                if (*index >= screens.size()) {
                    timer->stop();
                    app.quit();
                    return;
                }
                QMetaObject::invokeMethod(appState, "go", Q_ARG(QVariant, screens[*index]));
                (*index)++;
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
