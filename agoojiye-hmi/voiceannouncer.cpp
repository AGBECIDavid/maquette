#include "voiceannouncer.h"

#include <QProcess>
#include <QStandardPaths>

#ifdef AGOOJIYE_HAS_TTS
#include <QLocale>
#endif

namespace {
// Langue de l'annonce. L'interface est en français ; c'est aussi ce que Qt
// cherche parmi les voix du système.
constexpr auto kLanguage = "fr";
// Débit, dans l'échelle de spd-say (-100 à 100). Équivaut au -0.15 réglé sur
// Qt TextToSpeech : un peu posé, ton d'accueil.
constexpr auto kRate = "-15";
}

VoiceAnnouncer::VoiceAnnouncer(QObject *parent)
    : QObject(parent)
{
#ifdef AGOOJIYE_HAS_TTS
    m_tts = new QTextToSpeech(this);

    // Voix française si le système en propose une ; sinon on garde la voix par
    // défaut plutôt que de renoncer à parler.
    for (const QLocale &loc : m_tts->availableLocales()) {
        if (loc.language() == QLocale::French) {
            m_tts->setLocale(loc);
            break;
        }
    }

    m_tts->setRate(-0.15);
    m_tts->setPitch(0.0);
    m_tts->setVolume(0.9);

    connect(m_tts, &QTextToSpeech::stateChanged, this, [this](QTextToSpeech::State s) {
        setSpeaking(s == QTextToSpeech::Speaking);
    });
#endif

    // Repli, monté seulement si Qt n'a pas trouvé de moteur : c'est le cas
    // courant, le plugin Qt manquant bien plus souvent que speech-dispatcher.
    if (!ttsReady()) {
        m_spdSay = QStandardPaths::findExecutable(QStringLiteral("spd-say"));
        if (!m_spdSay.isEmpty()) {
            m_spd = new QProcess(this);
            // `spd-say -w` rend la main quand la phrase est finie, ce qui donne
            // l'état « parle » sans bloquer l'interface : c'est le processus
            // qui attend, pas nous.
            connect(m_spd, &QProcess::started, this, [this] { setSpeaking(true); });
            connect(m_spd, &QProcess::finished, this, [this] { setSpeaking(false); });
        }
    }
}

VoiceAnnouncer::~VoiceAnnouncer()
{
    // Fermer l'application pendant une annonce ne doit pas laisser un `spd-say`
    // derrière — ni la phrase se poursuivre une fois l'écran éteint.
    if (m_spd && m_spd->state() != QProcess::NotRunning) {
        m_spd->kill();
        m_spd->waitForFinished(300);
        QProcess::startDetached(m_spdSay, { "-C" });
    }
}

bool VoiceAnnouncer::ttsReady() const
{
#ifdef AGOOJIYE_HAS_TTS
    return m_tts && m_tts->state() != QTextToSpeech::Error;
#else
    return false;
#endif
}

bool VoiceAnnouncer::available() const
{
    return ttsReady() || !m_spdSay.isEmpty();
}

void VoiceAnnouncer::speak(const QString &text)
{
#ifdef AGOOJIYE_HAS_TTS
    if (ttsReady()) {
        m_tts->say(text);
        return;
    }
#endif
    if (m_spd && m_spd->state() == QProcess::NotRunning)
        m_spd->start(m_spdSay, { "-w", "-l", kLanguage, "-r", kRate, text });
}

void VoiceAnnouncer::stop()
{
#ifdef AGOOJIYE_HAS_TTS
    if (m_tts)
        m_tts->stop();
#endif
    if (m_spd && m_spd->state() != QProcess::NotRunning) {
        m_spd->kill();
        // Tuer le client ne vide pas la file du démon : il faut l'annuler.
        QProcess::startDetached(m_spdSay, { "-C" });
    }
}

void VoiceAnnouncer::setSpeaking(bool s)
{
    if (m_speaking == s)
        return;
    m_speaking = s;
    emit speakingChanged();
}
