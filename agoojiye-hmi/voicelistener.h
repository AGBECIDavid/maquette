#pragma once

#include <QObject>
#include <QString>
#include <QByteArray>
#include <QVector>
#include <qqmlintegration.h>

class QNetworkAccessManager;
class QTimer;
class QIODevice;
#ifdef AGOOJIYE_HAS_MIC
class QAudioSource;
class QMediaDevices;
#include <QAudioFormat>
#endif

/*!
 * L'oreille de l'assistant : micro → phrases → texte.
 *
 *   micro ─► détection de parole ─► WAV ─► whisper-server ─► heard(texte)
 *            (ici, sans modèle)           (local, HTTP)
 *
 * La détection de parole est un seuil d'énergie qui suit le bruit de fond :
 * dans une navette ouverte, le niveau du vent change d'une minute à l'autre,
 * et un seuil fixe serait soit sourd en ville, soit déclenché par chaque
 * rafale. Une phrase commence quand l'énergie dépasse nettement ce fond, et
 * finit après 0,8 s de retour au calme.
 *
 * Pendant que l'assistant parle, l'écoute est coupée (`muted`) : sinon il
 * entendrait sa propre voix dans les haut-parleurs et se répondrait.
 *
 * La reconnaissance est déléguée à `whisper-server` (whisper.cpp), lancé par
 * `voice.sh`. Sans lui, l'oreille capte mais n'envoie rien ; sans Qt
 * Multimedia, il n'y a pas de micro — l'assistant reste utilisable au
 * clavier. Rien de tout cela n'empêche l'application de construire ou de
 * tourner.
 */
class VoiceListener : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    //! Vrai si l'application a été compilée avec Qt Multimedia.
    Q_PROPERTY(bool micCompiled READ micCompiled CONSTANT)
    //! Vrai si le système propose un micro. Suivi en continu : sous PipeWire,
    //! la liste des micros se remplit *après* le démarrage.
    Q_PROPERTY(bool micAvailable READ micAvailable NOTIFY micChanged)
    //! Nom du micro écouté, vide sinon — pour vérifier que c'est le bon.
    Q_PROPERTY(QString micName READ micName NOTIFY micChanged)
    Q_PROPERTY(bool serverReady READ serverReady NOTIFY serverReadyChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)
    //! off | listening | hearing | transcribing
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    //! Niveau du micro, 0..1, lissé — pour l'animation.
    Q_PROPERTY(qreal level READ level NOTIFY levelChanged)
    Q_PROPERTY(QString serverUrl READ serverUrl CONSTANT)

public:
    explicit VoiceListener(QObject *parent = nullptr);
    ~VoiceListener() override;

    bool micCompiled() const;
    bool micAvailable() const;
    QString micName() const { return m_micName; }
    bool serverReady() const { return m_serverReady; }
    bool enabled() const { return m_enabled; }
    void setEnabled(bool on);
    bool muted() const { return m_muted; }
    void setMuted(bool on);
    QString state() const;
    qreal level() const { return m_level; }
    QString serverUrl() const { return m_url; }

    //! Recette : fait passer un fichier WAV par exactement le même chemin
    //! que le micro (détection, découpage, envoi). Rend faux si le fichier
    //! est illisible.
    Q_INVOKABLE bool feedWav(const QString &path);
    //! Requêtes de reconnaissance en cours ou en attente.
    Q_INVOKABLE int busy() const { return m_inFlight + m_queue.size(); }

signals:
    void heard(const QString &text);
    void micChanged();
    void serverReadyChanged();
    void enabledChanged();
    void mutedChanged();
    void stateChanged();
    void levelChanged();

private:
    // ---- capture ------------------------------------------------------------
    void startCapture();
    void stopCapture();
    void onAudio();
    void onDevicesChanged();

    // ---- détection de parole --------------------------------------------------
    // Échantillons mono 16 bits à 16 kHz, quelle que soit la source.
    void process(const qint16 *samples, int count);
    void processFrame(const qint16 *frame);
    void endUtterance(bool keep);
    void resetVad();

    // ---- reconnaissance -------------------------------------------------------
    void enqueue(const QVector<qint16> &pcm);
    void sendNext();
    void checkServer();
    void setServerReady(bool ready);
    static QByteArray wav(const QVector<qint16> &pcm);
    static QString clean(const QString &text);

    void setLevel(qreal l);
    void updateState();

    QString m_url;
    QString m_prompt;
    QNetworkAccessManager *m_net = nullptr;
    QTimer *m_health = nullptr;
    bool m_serverReady = false;
    bool m_enabled = true;
    bool m_muted = false;
    qreal m_level = 0;
    QString m_state = QStringLiteral("off");

    QString m_micName;
    QTimer *m_retry = nullptr;
#ifdef AGOOJIYE_HAS_MIC
    QMediaDevices *m_devices = nullptr;
    QByteArray m_deviceId;
    QAudioSource *m_source = nullptr;
    QIODevice *m_io = nullptr;
    QAudioFormat m_format;
    double m_resamplePos = 0;   // position fractionnaire dans le flux source
#endif

    // État de la détection.
    static constexpr int kRate = 16000;
    static constexpr int kFrame = 320;              // 20 ms
    QVector<qint16> m_frame;                        // trame en cours de remplissage
    QVector<QVector<qint16>> m_preroll;             // 300 ms avant le début
    QVector<qint16> m_utterance;
    bool m_inSpeech = false;
    int m_loudRun = 0;
    int m_quietRun = 0;
    int m_voicedFrames = 0;
    int m_holdoff = 0;                              // trames ignorées après la voix
    double m_floor = 0.01;

    QVector<QVector<qint16>> m_queue;
    int m_inFlight = 0;
};
