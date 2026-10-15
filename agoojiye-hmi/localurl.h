#pragma once

#include <QHostAddress>
#include <QString>
#include <QUrl>
#include <QtGlobal>

// Adresse d'un moteur vocal, lue dans l'environnement.
//
// Les moteurs tournent sur la machine, et ce qu'ils renvoient pilote
// l'interface : une transcription, une commande proposée. Une adresse qui
// sortirait de la machine ferait d'un serveur distant la source de ces
// ordres, et enverrait la voix de l'habitacle sur le réseau. Seule la boucle
// locale est donc acceptée ; toute autre valeur est ignorée, avec un
// avertissement, au profit de l'adresse par défaut.
inline QString localServiceUrl(const char *variable, const QString &fallback)
{
    if (!qEnvironmentVariableIsSet(variable))
        return fallback;
    const QString value = qEnvironmentVariable(variable);
    const QUrl url(value, QUrl::StrictMode);
    const QString host = url.host();
    const bool loopback = url.isValid() && url.scheme() == QLatin1String("http")
                          && url.userInfo().isEmpty()
                          && (host == QLatin1String("localhost")
                              || QHostAddress(host).isLoopback());
    if (!loopback) {
        qWarning("%s=%s ignorée : seule la boucle locale (127.0.0.1, ::1, localhost) "
                 "est acceptée. Utilisation de %s.",
                 variable, qPrintable(value), qPrintable(fallback));
        return fallback;
    }
    // Sans la barre finale : l'appelant ajoute « /inference », « /health »…
    QString clean = url.toString(QUrl::StripTrailingSlash);
    return clean;
}
