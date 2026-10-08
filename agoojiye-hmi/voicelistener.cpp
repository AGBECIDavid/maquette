#include "voicelistener.h"

#include <QFile>
#include <QHttpMultiPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>
#include <QtEndian>
#include <cmath>
#include <cstring>

#ifdef AGOOJIYE_HAS_MIC
#include <QAudioDevice>
#include <QAudioSource>
#include <QMediaDevices>
#endif

namespace {
// Réglages de la détection, en trames de 20 ms.
constexpr int kStartFrames = 3;         // 60 ms au-dessus du seuil pour commencer
constexpr int kEndFrames = 40;          // 800 ms de calme pour finir
constexpr int kPrerollFrames = 15;      // 300 ms gardées avant le début
constexpr int kMinVoicedFrames = 15;    // moins de 300 ms de voix : un claquement
constexpr int kMaxFrames = 750;         // 15 s : au-delà, on coupe et on envoie
constexpr int kHoldoffFrames = 20;      // 400 ms d'écho après la voix de synthèse
constexpr double kMinThreshold = 0.015; // ~ -36 dBFS : en dessous, ce n'est pas une voix
constexpr double kOverFloor = 3.0;      // ~ +10 dB au-dessus du bruit de fond

// Vocabulaire donné en amorce au moteur. Whisper prend l'amorce pour le début
// de la transcription, et en adopte l'orthographe : c'est ce qui lui fait
// écrire « Agoojiye » plutôt que « à Goujie ». Courte, parce qu'une amorce
// longue finit par être recopiée telle quelle sur un silence.
const char *kPrompt = "Salut Agoojiye. Ouvre la navigation. Mode sport. Quelle est mon autonomie ?";
}

VoiceListener::VoiceListener(QObject *parent)
    : QObject(parent)
{
    m_url = qEnvironmentVariable("AGOOJIYE_ASR_URL", QStringLiteral("http://127.0.0.1:8178"));
    // La recette ne doit jamais écouter la pièce où elle tourne.
    m_enabled = !qEnvironmentVariableIsSet("AGOOJIYE_NO_MIC");
    m_prompt = QString::fromUtf8(kPrompt);

    m_net = new QNetworkAccessManager(this);
    // Le serveur est local : un proxy système ne doit jamais s'interposer.
    m_net->setProxy(QNetworkProxy::NoProxy);

    m_health = new QTimer(this);
    m_health->setInterval(5000);
    connect(m_health, &QTimer::timeout, this, &VoiceListener::checkServer);
    m_health->start();
    QTimer::singleShot(0, this, &VoiceListener::checkServer);

    m_frame.reserve(kFrame);

    // Les micros n'existent pas forcément au démarrage. Sous PipeWire, Qt
    // remplit sa liste par messages successifs, après le lancement : demander
    // une seule fois, trop tôt, c'est conclure « aucun micro » pour toute la
    // session. On suit donc les changements, et on réessaie tant qu'on n'écoute
    // pas — un micro USB branché en cours de route est pris aussi.
    m_retry = new QTimer(this);
    m_retry->setInterval(3000);
    connect(m_retry, &QTimer::timeout, this, &VoiceListener::startCapture);
#ifdef AGOOJIYE_HAS_MIC
    m_devices = new QMediaDevices(this);
    connect(m_devices, &QMediaDevices::audioInputsChanged, this, &VoiceListener::onDevicesChanged);
#endif
    QTimer::singleShot(0, this, &VoiceListener::startCapture);
}

VoiceListener::~VoiceListener()
{
    // L'interface est en cours de démolition : ne plus lui écrire.
    blockSignals(true);
    stopCapture();
}

bool VoiceListener::micCompiled() const
{
#ifdef AGOOJIYE_HAS_MIC
    return true;
#else
    return false;
#endif
}

bool VoiceListener::micAvailable() const
{
#ifdef AGOOJIYE_HAS_MIC
    return !QMediaDevices::defaultAudioInput().isNull();
#else
    return false;
#endif
}

void VoiceListener::setEnabled(bool on)
{
    if (m_enabled == on)
        return;
    m_enabled = on;
    emit enabledChanged();
    if (on)
        startCapture();
    else
        stopCapture();
    updateState();
}

void VoiceListener::setMuted(bool on)
{
    if (m_muted == on)
        return;
    m_muted = on;
    // Ce qui était en cours d'écoute au moment où l'assistant prend la parole
    // n'est pas une demande : on le jette. En reprenant, on ignore encore un
    // instant la queue d'écho de la synthèse.
    resetVad();
    if (!on)
        m_holdoff = kHoldoffFrames;
    emit mutedChanged();
    updateState();
}

QString VoiceListener::state() const
{
    return m_state;
}

void VoiceListener::updateState()
{
    QString s;
    if (m_inSpeech)
        s = QStringLiteral("hearing");
    else if (m_inFlight > 0 || !m_queue.isEmpty())
        s = QStringLiteral("transcribing");
#ifdef AGOOJIYE_HAS_MIC
    else if (m_source && m_enabled)
        s = QStringLiteral("listening");
#endif
    else
        s = QStringLiteral("off");
    if (s != m_state) {
        m_state = s;
        emit stateChanged();
    }
}

void VoiceListener::setLevel(qreal l)
{
    if (std::abs(l - m_level) < 0.01)
        return;
    m_level = l;
    emit levelChanged();
}

// =============================================================================
//  Capture
// =============================================================================

void VoiceListener::startCapture()
{
#ifdef AGOOJIYE_HAS_MIC
    if (m_source || !m_enabled) {
        m_retry->stop();
        return;
    }
    const QAudioDevice dev = QMediaDevices::defaultAudioInput();
    if (dev.isNull()) {
        // Pas encore de micro : on repassera.
        m_retry->start();
        emit micChanged();
        return;
    }

    // 16 kHz mono 16 bits : ce qu'attend la reconnaissance. Si le périphérique
    // le refuse, on prend son format préféré et on convertit nous-mêmes.
    QAudioFormat want;
    want.setSampleRate(kRate);
    want.setChannelCount(1);
    want.setSampleFormat(QAudioFormat::Int16);
    m_format = dev.isFormatSupported(want) ? want : dev.preferredFormat();
    m_resamplePos = 0;

    m_source = new QAudioSource(dev, m_format, this);
    // Un micro débranché, ou un serveur audio relancé, arrête la source en
    // erreur : on la libère, et la boucle de reprise en ouvrira une autre.
    connect(m_source, &QAudioSource::stateChanged, this, [this](QAudio::State st) {
        if (st == QAudio::StoppedState && m_source && m_source->error() != QAudio::NoError) {
            QTimer::singleShot(0, this, [this] { stopCapture(); m_retry->start(); });
        }
    });
    m_io = m_source->start();
    if (!m_io) {
        delete m_source;
        m_source = nullptr;
        m_retry->start();
        return;
    }
    connect(m_io, &QIODevice::readyRead, this, &VoiceListener::onAudio);
    m_deviceId = dev.id();
    m_micName = dev.description();
    m_retry->stop();
    emit micChanged();
    updateState();
#endif
}

void VoiceListener::onDevicesChanged()
{
#ifdef AGOOJIYE_HAS_MIC
    // Le micro par défaut a changé (casque branché, micro USB…) : on suit.
    if (m_source && QMediaDevices::defaultAudioInput().id() != m_deviceId)
        stopCapture();
    startCapture();
    emit micChanged();
#endif
}

void VoiceListener::stopCapture()
{
#ifdef AGOOJIYE_HAS_MIC
    if (!m_source)
        return;
    m_source->stop();
    m_source->deleteLater();
    m_source = nullptr;
    m_io = nullptr;
    m_deviceId.clear();
    m_micName.clear();
    emit micChanged();
    resetVad();
    setLevel(0);
#endif
}

void VoiceListener::onAudio()
{
#ifdef AGOOJIYE_HAS_MIC
    const QByteArray raw = m_io->readAll();
    const int bps = m_format.bytesPerSample();
    const int ch = std::max(1, m_format.channelCount());
    if (bps <= 0)
        return;
    const int frames = raw.size() / (bps * ch);
    if (frames <= 0)
        return;

    // Échantillon → [-1, 1], moyenne des voies.
    auto sampleAt = [&](int f, int c) -> double {
        const char *p = raw.constData() + (f * ch + c) * bps;
        switch (m_format.sampleFormat()) {
        case QAudioFormat::Int16: { qint16 v; std::memcpy(&v, p, 2); return v / 32768.0; }
        case QAudioFormat::Int32: { qint32 v; std::memcpy(&v, p, 4); return v / 2147483648.0; }
        case QAudioFormat::Float: { float v; std::memcpy(&v, p, 4); return v; }
        case QAudioFormat::UInt8: return (static_cast<quint8>(*p) - 128) / 128.0;
        default: return 0;
        }
    };

    // Rééchantillonnage linéaire vers 16 kHz. Grossier, mais la voix tient
    // bien sous 8 kHz et la reconnaissance n'en demande pas plus.
    const double step = double(m_format.sampleRate()) / kRate;
    QVector<qint16> out;
    out.reserve(int(frames / step) + 2);
    while (m_resamplePos < frames - 1) {
        const int i = int(m_resamplePos);
        const double frac = m_resamplePos - i;
        double a = 0, b = 0;
        for (int c = 0; c < ch; ++c) {
            a += sampleAt(i, c);
            b += sampleAt(i + 1, c);
        }
        const double v = (a + (b - a) * frac) / ch;
        out.append(qint16(std::clamp(v, -1.0, 1.0) * 32767));
        m_resamplePos += step;
    }
    m_resamplePos -= frames - 1;
    process(out.constData(), out.size());
#endif
}

// =============================================================================
//  Détection de parole
// =============================================================================

void VoiceListener::process(const qint16 *samples, int count)
{
    for (int i = 0; i < count; ++i) {
        m_frame.append(samples[i]);
        if (m_frame.size() == kFrame) {
            processFrame(m_frame.constData());
            m_frame.clear();
        }
    }
}

void VoiceListener::processFrame(const qint16 *frame)
{
    double sum = 0;
    for (int i = 0; i < kFrame; ++i) {
        const double v = frame[i] / 32768.0;
        sum += v * v;
    }
    const double rms = std::sqrt(sum / kFrame);
    setLevel(std::min(1.0, rms * 8));

    if (m_muted)
        return;
    if (m_holdoff > 0) {
        --m_holdoff;
        return;
    }

    const double threshold = std::max(m_floor * kOverFloor, kMinThreshold);
    QVector<qint16> f(frame, frame + kFrame);

    if (!m_inSpeech) {
        // Le fond suit vite vers le bas, lentement vers le haut : une voix qui
        // commence ne doit pas relever le seuil qui sert à la détecter.
        m_floor = rms < m_floor ? m_floor * 0.9 + rms * 0.1
                                : m_floor * 0.995 + rms * 0.005;
        m_floor = std::max(m_floor, 0.002);

        m_preroll.append(f);
        if (m_preroll.size() > kPrerollFrames)
            m_preroll.removeFirst();

        m_loudRun = rms > threshold ? m_loudRun + 1 : 0;
        if (m_loudRun >= kStartFrames) {
            m_inSpeech = true;
            m_utterance.clear();
            for (const auto &p : m_preroll)
                m_utterance += p;
            m_preroll.clear();
            m_voicedFrames = m_loudRun;
            m_quietRun = 0;
            updateState();
        }
        return;
    }

    m_utterance += f;
    // Hystérésis : il faut redescendre plus bas qu'au démarrage pour finir,
    // sinon une syllabe faible couperait la phrase en deux.
    if (rms < threshold * 0.7) {
        ++m_quietRun;
    } else {
        m_quietRun = 0;
        ++m_voicedFrames;
    }

    if (m_quietRun >= kEndFrames)
        endUtterance(true);
    else if (m_utterance.size() >= kMaxFrames * kFrame)
        endUtterance(true);
}

void VoiceListener::endUtterance(bool keep)
{
    if (keep && m_voicedFrames >= kMinVoicedFrames) {
        // On ne garde que 300 ms du silence final : le reste ne coûte que du
        // temps de calcul au moteur.
        const int tail = std::max(0, m_quietRun - kPrerollFrames) * kFrame;
        QVector<qint16> pcm = m_utterance.mid(0, m_utterance.size() - tail);
        enqueue(pcm);
    }
    m_inSpeech = false;
    m_utterance.clear();
    m_voicedFrames = 0;
    m_quietRun = 0;
    m_loudRun = 0;
    updateState();
}

void VoiceListener::resetVad()
{
    m_inSpeech = false;
    m_utterance.clear();
    m_preroll.clear();
    m_frame.clear();
    m_voicedFrames = 0;
    m_quietRun = 0;
    m_loudRun = 0;
    updateState();
}

// =============================================================================
//  Reconnaissance
// =============================================================================

void VoiceListener::enqueue(const QVector<qint16> &pcm)
{
    // Pas de serveur : inutile d'empiler ce qu'on ne pourra pas envoyer.
    if (!m_serverReady)
        return;
    m_queue.append(pcm);
    // Une file qui grossit trahit un moteur trop lent pour la machine : on
    // garde les phrases les plus récentes, ce sont elles qu'on attend.
    while (m_queue.size() > 2)
        m_queue.removeFirst();
    sendNext();
    updateState();
}

void VoiceListener::sendNext()
{
    if (m_inFlight > 0 || m_queue.isEmpty())
        return;
    const QVector<qint16> pcm = m_queue.takeFirst();

    auto *multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    auto field = [multi](const char *name, const QByteArray &value) {
        QHttpPart part;
        part.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QStringLiteral("form-data; name=\"%1\"").arg(QLatin1String(name)));
        part.setBody(value);
        multi->append(part);
    };
    QHttpPart file;
    file.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("audio/wav"));
    file.setHeader(QNetworkRequest::ContentDispositionHeader,
                   QStringLiteral("form-data; name=\"file\"; filename=\"phrase.wav\""));
    file.setBody(wav(pcm));
    multi->append(file);
    field("language", "fr");
    field("response_format", "json");
    field("temperature", "0.0");
    field("no_timestamps", "true");
    field("prompt", m_prompt.toUtf8());

    QNetworkRequest req(QUrl(m_url + QStringLiteral("/inference")));
    req.setTransferTimeout(20000);
    QNetworkReply *reply = m_net->post(req, multi);
    multi->setParent(reply);
    ++m_inFlight;
    updateState();

    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        --m_inFlight;
        if (reply->error() != QNetworkReply::NoError) {
            setServerReady(false);
        } else {
            const auto obj = QJsonDocument::fromJson(reply->readAll()).object();
            const QString text = clean(obj.value(QStringLiteral("text")).toString());
            if (!text.isEmpty())
                emit heard(text);
        }
        updateState();
        sendNext();
    });
}

// Whisper, devant un bruit qu'il ne sait pas lire, écrit volontiers ce qu'il a
// le plus vu en fin de vidéo : crédits de sous-titres, « merci d'avoir
// regardé ». Ces phrases n'ont jamais été dites dans une navette.
QString VoiceListener::clean(const QString &text)
{
    QString t = text;
    t.remove(QRegularExpression(QStringLiteral("\\[[^\\]]*\\]|\\([^)]*\\)|\\*[^*]*\\*|♪")));
    t = t.simplified();
    static const char *hallucinations[] = {
        "sous-titr", "amara.org", "merci d'avoir regardé", "abonnez-vous",
        "n'oubliez pas de vous abonner", "radio-canada", "société radio",
    };
    const QString low = t.toLower();
    for (const char *h : hallucinations)
        if (low.contains(QString::fromUtf8(h)))
            return QString();
    return t;
}

QByteArray VoiceListener::wav(const QVector<qint16> &pcm)
{
    const quint32 dataBytes = quint32(pcm.size()) * 2;
    QByteArray out;
    out.reserve(44 + int(dataBytes));
    auto u32 = [&out](quint32 v) { char b[4]; qToLittleEndian(v, b); out.append(b, 4); };
    auto u16 = [&out](quint16 v) { char b[2]; qToLittleEndian(v, b); out.append(b, 2); };
    out.append("RIFF", 4); u32(36 + dataBytes); out.append("WAVE", 4);
    out.append("fmt ", 4); u32(16); u16(1); u16(1); u32(kRate); u32(kRate * 2); u16(2); u16(16);
    out.append("data", 4); u32(dataBytes);
    for (qint16 s : pcm)
        u16(quint16(s));
    return out;
}

void VoiceListener::checkServer()
{
    QNetworkRequest req(QUrl(m_url + QStringLiteral("/health")));
    req.setTransferTimeout(3000);
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        setServerReady(reply->error() == QNetworkReply::NoError
                       && reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 200);
    });
}

void VoiceListener::setServerReady(bool ready)
{
    if (m_serverReady == ready)
        return;
    m_serverReady = ready;
    emit serverReadyChanged();
}

// =============================================================================
//  Recette
// =============================================================================

bool VoiceListener::feedWav(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const QByteArray d = f.readAll();
    if (d.size() < 44 || !d.startsWith("RIFF") || d.mid(8, 4) != "WAVE")
        return false;

    // Parcours des blocs : « fmt » puis « data », dans n'importe quel ordre.
    int pos = 12, rate = 0, ch = 0, bits = 0, fmt = 0;
    QByteArray data;
    while (pos + 8 <= d.size()) {
        const QByteArray id = d.mid(pos, 4);
        const quint32 len = qFromLittleEndian<quint32>(d.constData() + pos + 4);
        if (id == "fmt ") {
            fmt = qFromLittleEndian<quint16>(d.constData() + pos + 8);
            ch = qFromLittleEndian<quint16>(d.constData() + pos + 10);
            rate = int(qFromLittleEndian<quint32>(d.constData() + pos + 12));
            bits = qFromLittleEndian<quint16>(d.constData() + pos + 22);
        } else if (id == "data") {
            data = d.mid(pos + 8, int(len));
        }
        pos += 8 + int(len) + (len & 1);
    }
    if (rate <= 0 || ch <= 0 || data.isEmpty() || !((fmt == 1 && bits == 16) || (fmt == 3 && bits == 32)))
        return false;

    const int bps = bits / 8;
    const int frames = data.size() / (bps * ch);
    auto sampleAt = [&](int i, int c) -> double {
        const char *p = data.constData() + (i * ch + c) * bps;
        if (fmt == 3) { float v; std::memcpy(&v, p, 4); return v; }
        return qFromLittleEndian<qint16>(p) / 32768.0;
    };
    QVector<qint16> pcm;
    const double step = double(rate) / kRate;
    for (double x = 0; x < frames - 1; x += step) {
        const int i = int(x);
        double a = 0, b = 0;
        for (int c = 0; c < ch; ++c) { a += sampleAt(i, c); b += sampleAt(i + 1, c); }
        pcm.append(qint16(std::clamp((a + (b - a) * (x - i)) / ch, -1.0, 1.0) * 32767));
    }
    // Une seconde de silence à la fin, pour clore une phrase restée ouverte.
    pcm += QVector<qint16>(kRate, 0);
    process(pcm.constData(), pcm.size());
    return true;
}
