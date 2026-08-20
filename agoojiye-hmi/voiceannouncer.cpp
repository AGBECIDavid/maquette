#include "voiceannouncer.h"

#ifdef AGOOJIYE_HAS_TTS
#include <QLocale>
#endif

VoiceAnnouncer::VoiceAnnouncer(QObject *parent)
    : QObject(parent)
{
#ifdef AGOOJIYE_HAS_TTS
    m_tts = new QTextToSpeech(this);

    // Voix française si le système en propose une ; sinon on garde la voix par
    // défaut plutôt que de renoncer à parler.
    const QLocale fr(QLocale::French);
    for (const QLocale &loc : m_tts->availableLocales()) {
        if (loc.language() == QLocale::French) {
            m_tts->setLocale(loc);
            break;
        }
    }

    m_tts->setRate(-0.15);   // un peu posé, ton d'accueil
    m_tts->setPitch(0.0);
    m_tts->setVolume(0.9);

    connect(m_tts, &QTextToSpeech::stateChanged, this, [this](QTextToSpeech::State s) {
        setSpeaking(s == QTextToSpeech::Speaking);
    });
#endif
}

bool VoiceAnnouncer::available() const
{
#ifdef AGOOJIYE_HAS_TTS
    return m_tts && m_tts->state() != QTextToSpeech::Error;
#else
    return false;
#endif
}

void VoiceAnnouncer::speak(const QString &text)
{
#ifdef AGOOJIYE_HAS_TTS
    if (available())
        m_tts->say(text);
#else
    Q_UNUSED(text)
#endif
}

void VoiceAnnouncer::stop()
{
#ifdef AGOOJIYE_HAS_TTS
    if (m_tts)
        m_tts->stop();
#endif
}

void VoiceAnnouncer::setSpeaking(bool s)
{
    if (m_speaking == s)
        return;
    m_speaking = s;
    emit speakingChanged();
}
