#pragma once

#include <QObject>
#include <QString>
#include <qqmlintegration.h>

#ifdef AGOOJIYE_HAS_TTS
#include <QTextToSpeech>
#endif

/*!
 * Annonce vocale de l'assistant de bord.
 *
 * Qt TextToSpeech est une dépendance *optionnelle* : sans elle, l'application
 * compile et tourne à l'identique, `speak()` ne fait simplement rien et
 * `available` reste faux. L'interface s'appuie donc sur son propre affichage
 * (bulle + onde animée) pour rester lisible sur une cible sans synthèse vocale.
 */
class VoiceAnnouncer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool speaking READ speaking NOTIFY speakingChanged)

public:
    explicit VoiceAnnouncer(QObject *parent = nullptr);

    bool available() const;
    bool speaking() const { return m_speaking; }

    //! Prononce `text`. Sans moteur disponible, l'appel est ignoré.
    Q_INVOKABLE void speak(const QString &text);
    Q_INVOKABLE void stop();

signals:
    void speakingChanged();

private:
    void setSpeaking(bool s);

    bool m_speaking = false;
#ifdef AGOOJIYE_HAS_TTS
    QTextToSpeech *m_tts = nullptr;
#endif
};
