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
#include <QElapsedTimer>
#include <QDateTime>
#include <QJSValue>

namespace {
// A `property var` read from C++ holds either a QJSValue or an already
// converted list, depending on how QML last assigned it.
QVariantList jsList(const QVariant &v)
{
    if (v.metaType() == QMetaType::fromType<QJSValue>())
        return v.value<QJSValue>().toVariant().toList();
    return v.toList();
}
}

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

    // HMI_HV=<5 digits> overrides the high-voltage test pattern baked into
    // VehicleSimulator, so a demo can move between fault scenarios without a
    // rebuild. Digit order matches VehicleData.hvChain: isolation, traction
    // pack, BMS, OBC, motor. 1 = faulty.
    const QString hvPattern = qEnvironmentVariable("HMI_HV");
    if (!hvPattern.isEmpty() && !engine.rootObjects().isEmpty()) {
        QQmlComponent hvProbe(&engine);
        hvProbe.setData("import QtQml\nimport AgoojiyeHMI\n"
                        "QtObject { property QtObject sim: VehicleSimulator }", QUrl());
        QObject *hvObj = hvProbe.create();
        QObject *simulator = hvObj ? hvObj->property("sim").value<QObject *>() : nullptr;
        if (simulator)
            QMetaObject::invokeMethod(simulator, "applyHvPattern", Q_ARG(QVariant, hvPattern));
    }

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

    // QA aid: HMI_VOICE="phrase|phrase|…" feeds the voice command table as if
    // each phrase had been recognised, prints one "status|phrase|reply" line
    // per step, then exits. It tests what the assistant *does* with a phrase,
    // independently of any microphone or recognition engine.
    //
    // The simulator is stopped so the script controls the vehicle state: a
    // step written "@vitesse=30" sets the speed, which is how the refusal
    // rules are exercised — including a speed change between a question and
    // its "oui".
    const QString voiceScript = qEnvironmentVariable("HMI_VOICE");
    if (!voiceScript.isEmpty() && !engine.rootObjects().isEmpty()) {
        QQmlComponent voiceProbe(&engine);
        voiceProbe.setData("import QtQml\nimport AgoojiyeHMI\n"
                           "QtObject {\n"
                           "  property QtObject voice: VoiceCommands\n"
                           "  property QtObject data: VehicleData\n"
                           "  property QtObject sim: VehicleSimulator\n"
                           "  property QtObject appState: AppState\n"
                           "}", QUrl());
        QObject *probeObj = voiceProbe.create();
        auto get = [probeObj](const char *name) {
            return probeObj ? probeObj->property(name).value<QObject *>() : nullptr;
        };
        QObject *voice = get("voice");
        QObject *data = get("data");
        QObject *simulator = get("sim");
        QObject *appState = get("appState");
        if (voice && data && simulator && appState) {
            simulator->setProperty("running", false);
            data->setProperty("speed", 0.0);
            voice->setProperty("speakReplies", false);
            QMetaObject::invokeMethod(appState, "skipBoot");

            for (const QString &step : voiceScript.split('|')) {
                if (step.startsWith("@vitesse=")) {
                    // The simulator keeps speed, gear and parking brake
                    // consistent by construction; with it stopped, the
                    // script must do the same, or it stages a shuttle
                    // rolling in P with the brake on.
                    const double kmh = step.mid(9).toDouble();
                    data->setProperty("speed", kmh);
                    data->setProperty("driveGear", kmh > 0.5 ? "D" : "P");
                    data->setProperty("parkingBrake", kmh <= 0.5);
                    printf("@|%s|\n", qPrintable(step));
                    continue;
                }
                QVariant ret;
                QMetaObject::invokeMethod(voice, "handle",
                                          Q_RETURN_ARG(QVariant, ret),
                                          Q_ARG(QVariant, step));
                if (ret.canConvert<QJSValue>())
                    ret = ret.value<QJSValue>().toVariant();
                const QVariantMap out = ret.toMap();
                printf("%s|%s|%s\n",
                       qPrintable(out.value("status").toString()),
                       qPrintable(step),
                       qPrintable(out.value("reply").toString()));
            }
            fflush(stdout);
        }
        // Combined with HMI_SCREENSHOT_DIR, the sweep runs after the script
        // instead of the app quitting: the captures then show the console with
        // its exchanges, which is how the populated state gets reviewed.
        if (qEnvironmentVariable("HMI_SCREENSHOT_DIR").isEmpty())
            QTimer::singleShot(0, &app, &QCoreApplication::quit);
    }

    // ---- conversational assistant --------------------------------------------
    // AGOOJIYE_LLM_URL points the assistant at another language server. (The
    // speech server is read by VoiceListener itself, from AGOOJIYE_ASR_URL.)
    QQmlComponent convoProbe(&engine);
    convoProbe.setData("import QtQml\nimport AgoojiyeHMI\n"
                       "QtObject {\n"
                       "  property QtObject assistant: Assistant\n"
                       "  property QtObject listener: VoiceListener\n"
                       "  property QtObject voice: VoiceCommands\n"
                       "  property QtObject data: VehicleData\n"
                       "  property QtObject sim: VehicleSimulator\n"
                       "  property QtObject appState: AppState\n"
                       "  property QtObject announcer: VoiceAnnouncer\n"
                       "}", QUrl());
    QObject *convoObj = engine.rootObjects().isEmpty() ? nullptr : convoProbe.create();
    auto single = [convoObj](const char *name) {
        return convoObj ? convoObj->property(name).value<QObject *>() : nullptr;
    };
    QObject *assistant = single("assistant");
    if (assistant && qEnvironmentVariableIsSet("AGOOJIYE_LLM_URL"))
        assistant->setProperty("llmUrl", qEnvironmentVariable("AGOOJIYE_LLM_URL"));

    // QA aid: HMI_ASSISTANT="phrase|phrase|…" plays transcripts to the
    // assistant as if the microphone had heard them — wake-word rules
    // included. "@clavier:texte" types instead, "@vitesse=N" moves the
    // shuttle, "@etat" prints the vehicle state. Each step waits for the
    // language model to answer. The conversation is printed as
    // "role|status|via|text", then the app exits.
    //
    // HMI_VOICE_WAV=<file.wav> starts one step further back: the file goes
    // through the microphone path — speech detection, cutting, upload to the
    // speech server — and the conversation it produces is printed the same way.
    //
    // Replies are not spoken unless HMI_SPEAK=1.
    const QString convo = qEnvironmentVariable("HMI_ASSISTANT");
    const QString wavPath = qEnvironmentVariable("HMI_VOICE_WAV");
    QObject *listener = single("listener");
    QObject *voice = single("voice");
    QObject *vdata = single("data");
    QObject *vsim = single("sim");
    QObject *vstate = single("appState");
    if ((!convo.isEmpty() || !wavPath.isEmpty())
            && assistant && listener && voice && vdata && vsim && vstate) {
        vsim->setProperty("running", false);
        vdata->setProperty("speed", 0.0);
        voice->setProperty("speakReplies", qEnvironmentVariable("HMI_SPEAK") == "1");
        QMetaObject::invokeMethod(vstate, "skipBoot");

        auto *steps = new QStringList(convo.isEmpty() ? QStringList() : convo.split('|'));
        auto *clock = new QElapsedTimer();
        clock->start();
        auto *fed = new bool(wavPath.isEmpty());
        auto *quietSince = new qint64(-1);
        auto *waitUntil = new qint64(0);
        auto *timer = new QTimer(&app);
        timer->setInterval(50);

        QObject *announcer = single("announcer");
        const bool speak = qEnvironmentVariable("HMI_SPEAK") == "1";
        auto busy = [=]() {
            int queued = 0;
            QMetaObject::invokeMethod(listener, "busy", Q_RETURN_ARG(int, queued));
            // Avec la voix, on attend aussi qu'elle se taise : c'est ainsi que
            // la recette observe la file d'attente de la synthèse.
            const bool talking = speak && announcer && announcer->property("speaking").toBool();
            return assistant->property("thinking").toBool() || queued > 0 || talking;
        };
        auto setSpeed = [=](double kmh) {
            // Same rule as HMI_VOICE: speed, gear and brake stay consistent.
            vdata->setProperty("speed", kmh);
            vdata->setProperty("driveGear", kmh > 0.5 ? "D" : "P");
            vdata->setProperty("parkingBrake", kmh <= 0.5);
        };
        auto printState = [=]() {
            QStringList open;
            const QVariantList openings = jsList(vdata->property("openings"));
            for (const QVariant &o : openings) {
                const QVariantMap m = o.toMap();
                if (m.value("open").toBool() && !m.value("label").toString().startsWith("Accès"))
                    open << m.value("label").toString();
            }
            printf("#|mode=%s|clignotant=%s|ecran=%s|volume=%.1f|musique=%d|ouvert=%s\n",
                   qPrintable(vdata->property("driveMode").toString()),
                   qPrintable(vdata->property("turnSignal").toString()),
                   qPrintable(vstate->property("screen").toString()),
                   vstate->property("mediaVolume").toDouble(),
                   vdata->property("mediaPlaying").toBool() ? 1 : 0,
                   qPrintable(open.join(',')));
        };

        QObject::connect(timer, &QTimer::timeout, &app, [=, &app]() {
            const qint64 now = clock->elapsed();
            if (now > 90000) {
                printf("TIMEOUT|||conversation inachevée après 90 s\n");
                fflush(stdout);
                app.exit(3);
                return;
            }
            // Laisser aux serveurs le temps de répondre à leur premier contrôle
            // de santé, faute de quoi le premier tour partirait sans eux.
            const bool warm = assistant->property("modelReady").toBool()
                              && (wavPath.isEmpty() || listener->property("serverReady").toBool());
            if (now < 3000 && !warm)
                return;

            if (!*fed) {
                *fed = true;
                bool ok = false;
                QMetaObject::invokeMethod(listener, "feedWav", Q_RETURN_ARG(bool, ok),
                                          Q_ARG(QString, wavPath));
                if (!ok) {
                    printf("ERREUR|||fichier WAV illisible : %s\n", qPrintable(wavPath));
                    fflush(stdout);
                    app.exit(2);
                }
                return;
            }
            if (busy()) {
                *quietSince = -1;
                return;
            }
            if (now < *waitUntil)
                return;
            if (!steps->isEmpty()) {
                const QString step = steps->takeFirst();
                if (step.startsWith("@attendre=")) {
                    // Laisse l'assistant réagir de lui-même (annonces d'alerte).
                    *waitUntil = now + qint64(step.mid(10).toDouble() * 1000);
                } else if (step.startsWith("@set:")) {
                    // @set:propriété=valeur sur VehicleData — pour provoquer une
                    // situation (ceinture, batterie, défaut) au fil du script.
                    const QString assign = step.mid(5);
                    const QString name = assign.section('=', 0, 0);
                    const QString raw = assign.section('=', 1);
                    QVariant value = raw;
                    bool isNum = false;
                    const double num = raw.toDouble(&isNum);
                    if (raw == "true" || raw == "false")
                        value = (raw == "true");
                    else if (isNum)
                        value = num;
                    vdata->setProperty(name.toUtf8().constData(), value);
                } else if (step.startsWith("@vitesse="))
                    setSpeed(step.mid(9).toDouble());
                else if (step == "@etat")
                    printState();
                else if (step.startsWith("@clavier:"))
                    QMetaObject::invokeMethod(assistant, "ask", Q_ARG(QVariant, step.mid(9)),
                                              Q_ARG(QVariant, QStringLiteral("clavier")),
                                              Q_ARG(QVariant, QVariant()));
                else
                    QMetaObject::invokeMethod(assistant, "hear", Q_ARG(QVariant, step));
                *quietSince = -1;
                return;
            }
            // Fini quand plus rien ne bouge depuis un instant : une réponse du
            // modèle peut encore déclencher une commande juste après.
            if (*quietSince < 0) {
                *quietSince = now;
                return;
            }
            if (now - *quietSince < 400)
                return;
            timer->stop();
            const QVariantList dialog = jsList(assistant->property("dialog"));
            for (const QVariant &e : dialog) {
                const QVariantMap m = e.toMap();
                printf("%s|%s|%s|%s\n",
                       qPrintable(m.value("role").toString()),
                       qPrintable(m.value("status").toString()),
                       qPrintable(m.value("via").toString()),
                       qPrintable(m.value("text").toString()));
            }
            printState();
            fflush(stdout);
            if (qEnvironmentVariable("HMI_SCREENSHOT_DIR").isEmpty())
                app.quit();
        });
        timer->start();
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
                "veh:0", "veh:1", "veh:2", "veh:3", "veh:4", "veh:5", "veh:6",
                "conduite:0", "conduite:1", "conduite:2", "conduite:3", "conduite:4", "conduite:5",
                "adas:0", "adas:1", "adas:2", "adas:3", "adas:4", "adas:5",
                "media:0", "media:1", "media:2", "media:3", "media:4", "media:5",
                "mediaNow:0", "mediaNow:1", "mediaNow:2", "mediaNow:3",
                "parametres:0", "parametres:1", "parametres:2", "parametres:3", "parametres:4",
                "parametres:5"
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
            // A trace is a measurement, and a measurement must be repeatable:
            // the random phase durations that keep the demo lively also make a
            // fixed-length trace hit different parts of the cycle each run.
            simulator->setProperty("deterministic", true);
            QMetaObject::invokeMethod(simulator, "nextPhase");

            // `wall` porte le temps réellement écoulé. Sans lui, une accélération
            // se déduit de l'intervalle *visé* entre deux relevés — or ce relevé
            // peut lui aussi arriver en retard, et le contrôle accuserait la
            // physique d'un défaut qui n'appartient qu'à l'échantillonnage.
            printf("t,wall,phase,speed,power,regen,battery,consumption,range,gear,"
                   "parkingBrake,seatbeltWarning,tyreWarning,motorTemp,alerts,critical,"
                   "hvFaults,hvBlocking,tick\n");
            auto *started = new QElapsedTimer();
            started->start();
            auto *elapsed = new int(0);
            // Même origine que `lastTickMs`, qui vient de Date.now().
            const double epoch0 = double(QDateTime::currentMSecsSinceEpoch());
            const int limit = traceSeconds.toInt() * 5;
            auto *timer = new QTimer(&app);
            timer->setInterval(200);
            QObject::connect(timer, &QTimer::timeout, &app, [=, &app]() mutable {
                const QVariantList alerts = data->property("activeAlerts").toList();
                const QVariantList hv = data->property("hvFaults").toList();
                // `tick` : l'instant du calcul qui a produit ces valeurs, sur
                // l'horloge du modèle. La vitesse lue à un relevé date de ce
                // calcul, pas du relevé — qui peut le suivre de 100 ms ou plus.
                // Une accélération se mesure donc entre deux `tick`, jamais
                // entre deux `wall`.
                //
                // Avant le premier calcul, il n'y a pas d'instant à donner : la
                // case reste vide. Un 0 par défaut ferait croire qu'un calcul a
                // eu lieu au début du relevé, et la première fenêtre mesurée
                // couvrirait plus de modèle qu'elle n'en déclare.
                const double lastTick = simulator->property("lastTickMs").toDouble();
                const QByteArray tick = lastTick > 0
                    ? QByteArray::number((lastTick - epoch0) / 1000.0, 'f', 3) : QByteArray();
                printf("%.1f,%.3f,%s,%.1f,%.1f,%.1f,%d,%.1f,%d,%s,%d,%d,%d,%d,%lld,%d,%lld,%d,%s\n",
                       *elapsed / 5.0,
                       started->elapsed() / 1000.0,
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
                       data->property("hasCriticalAlert").toBool() ? 1 : 0,
                       static_cast<long long>(hv.size()),
                       data->property("hvBlocking").toBool() ? 1 : 0,
                       tick.constData());
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
