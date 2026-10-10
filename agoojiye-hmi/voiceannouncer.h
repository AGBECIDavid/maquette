#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <qqmlintegration.h>

#ifdef AGOOJIYE_HAS_TTS
#include <QTextToSpeech>
#endif

class QProcess;

/*!
 * Annonce vocale de l'assistant de bord.
 *
 * Deux chemins possibles, essayés dans cet ordre :
 *
 *   1. **Qt TextToSpeech**, quand le module *et* son plugin de sortie sont
 *      installés. C'est le chemin propre : réglage du débit, du volume, état
 *      « en train de parler » remonté par le moteur.
 *
 *   2. **`spd-say`**, le client en ligne de commande de speech-dispatcher.
 *      Il existe parce que le premier chemin demande un plugin Qt
 *      (`libqtexttospeech_speechd.so`) qui manque sur beaucoup
 *      d'installations, alors que speech-dispatcher lui-même est déjà là.
 *      Si `spd-say` parle dans un terminal, l'assistant parlera.
 *
 * Sans aucun des deux, l'application compile et tourne à l'identique :
 * `speak()` ne fait rien, `available` reste faux, et l'interface s'appuie sur
 * son propre affichage (bulle + onde animée) pour rester lisible.
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
    ~VoiceAnnouncer() override;

    bool available() const;
    bool speaking() const { return m_speaking; }

    //! Prononce `text`. Sans moteur disponible, l'appel est ignoré.
    Q_INVOKABLE void speak(const QString &text);
    Q_INVOKABLE void stop();
    //! Coupe ce qui se dit, vide la file, et prononce `text` aussitôt. Réservé
    //! aux alertes critiques : une ceinture débouclée en roulant passe avant
    //! la fin d'une blague.
    Q_INVOKABLE void interrupt(const QString &text);

signals:
    void speakingChanged();

private:
    void setSpeaking(bool s);
    //! Vrai si Qt TextToSpeech a trouvé un moteur utilisable.
    bool ttsReady() const;

    bool m_speaking = false;

    // Phrases arrivées pendant qu'une autre était dite. En conversation, « Je
    // vous écoute » suivi aussitôt de la réponse est le cas normal : jeter la
    // seconde, c'est perdre la réponse.
    QStringList m_queue;
    void speakNext();

    // Repli : chemin de `spd-say`, vide s'il n'est pas installé.
    QString m_spdSay;
    QProcess *m_spd = nullptr;

#ifdef AGOOJIYE_HAS_TTS
    QTextToSpeech *m_tts = nullptr;
#endif
};
