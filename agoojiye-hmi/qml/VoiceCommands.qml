pragma Singleton
import QtQuick

// Pas d'`import AgoojiyeHMI` ici, comme dans VehicleData et VehicleSimulator :
// AppState importe déjà le module, et deux singletons du module qui
// l'importent chacun explicitement s'attendent l'un l'autre au chargement
// (« Cyclic dependency detected »). Les singletons voisins restent visibles par
// l'import implicite du dossier ; les types C++ du module, eux, ne le sont pas
// — d'où le signal `replied` plutôt qu'un appel direct à VoiceAnnouncer.

// =============================================================================
//  ASSISTANT VOCAL — TABLE DES COMMANDES
// =============================================================================
//
//   micro ──► reconnaissance ──► VoiceCommands ──► AppState / VehicleData
//             (Vosk, à venir)    (ce fichier)      (les mêmes chemins que
//                                                   le tactile)
//
//  La voix est un périphérique d'entrée, pas une couche. Chaque commande
//  appelle les fonctions que l'interface tactile appelle déjà : si la voix se
//  creusait son propre chemin vers l'état, les règles de sécurité existeraient
//  en deux exemplaires, et deux exemplaires finissent toujours par diverger.
//
//  Cette table est la source unique de ce que l'assistant comprend. La
//  grammaire transmise au moteur de reconnaissance en est *déduite*
//  (`grammar()`) : une commande qu'on ne sait pas exécuter ne peut pas
//  davantage être reconnue, et les deux listes ne peuvent pas diverger parce
//  qu'il n'y en a qu'une.
//
//  Vocabulaire fermé, délibérément. Un moteur limité à ces phrases ne peut pas
//  « entendre » une commande qui n'existe pas : l'erreur de reconnaissance la
//  plus dangereuse devient impossible plutôt que rare.
// =============================================================================
//
//  Ce qui ne se commande JAMAIS à la voix — et qui, pour cette raison, n'est
//  pas désactivé ici mais absent :
//
//   · direction, accélération, freinage, rapport engagé
//   · frein de stationnement
//   · chaîne haute tension (aucun défaut ne s'acquitte à la voix)
//   · régulateur de vitesse : il agit sur l'allure du véhicule
//   · maintien de voie : il agit sur la direction
//   · freinage d'urgence et alerte de collision : ni l'un ni l'autre ne se
//     désactive à la voix
//
//  Une fonction qu'on ne peut pas nommer ne peut pas être déclenchée par une
//  phrase mal comprise, ni par un passager.
// =============================================================================

QtObject {
    id: root

    // Liste affichée par l'interface pour dire ce qui est exclu, et pourquoi.
    // Elle documente la table, elle ne la pilote pas : rien ici ne se lit
    // comme une commande.
    readonly property var forbidden: [
        { label: "Direction, accélération, freinage", why: "Conduite du véhicule" },
        { label: "Rapport engagé, frein de stationnement", why: "Immobilisation" },
        { label: "Chaîne haute tension", why: "Aucun défaut ne s'acquitte à la voix" },
        { label: "Régulateur, maintien de voie", why: "Agissent sur l'allure et la direction" },
        { label: "Freinage d'urgence, alerte collision", why: "Ne se désactivent jamais à la voix" }
    ]

    // La table décide ; elle ne parle pas. Chaque réponse est émise, et c'est
    // Main.qml qui la relie au haut-parleur — le même endroit où se branchera
    // le micro. Ainsi la logique se teste sans aucun périphérique audio.
    signal replied(string text)

    // Lu par ce branchement. La recette coupe la voix : un test qui parle sur
    // le poste d'un développeur est un test qu'on cesse de lancer.
    property bool speakReplies: true

    // Une confirmation n'a de sens que dans la foulée de la question. Un « oui »
    // prononcé deux minutes plus tard, dans une autre conversation, ne doit pas
    // exécuter ce qu'on avait oublié avoir demandé.
    readonly property int confirmWindowMs: 8000

    // Commande en attente de confirmation, null sinon.
    property var pending: null

    // Derniers échanges, le plus récent en tête. Pour l'écran d'essai.
    property var history: []
    readonly property int historyLength: 6

    readonly property var yesWords: ["oui", "confirme", "valide", "d'accord"]
    readonly property var noWords: ["non", "annule", "laisse tomber"]

    // =========================================================================
    //  La table
    // =========================================================================
    //
    //  phrases      ce que le moteur peut reconnaître ; la première est la forme
    //               canonique affichée à l'écran
    //  stoppedOnly  refusée tant que la navette roule
    //  confirm      demande un « oui » avant d'agir
    //  already()    facultatif — vrai si l'action ne changerait rien ; on le dit
    //               plutôt que de demander confirmation pour rien
    //  ask          la question posée quand `confirm` est vrai
    //  run()        agit, et rend la phrase de retour

    property var commands: [
        // ---- aller à un écran -------------------------------------------
        { id: "go-dash", group: "Écrans", phrases: ["accueil", "va à l'accueil", "tableau de bord"],
          run: function () { AppState.go("dash"); return "Accueil." } },
        { id: "go-nav", group: "Écrans", phrases: ["navigation", "ouvre la navigation", "carte"],
          run: function () { AppState.go("nav"); return "Navigation." } },
        { id: "go-veh", group: "Écrans", phrases: ["véhicule", "état du véhicule"],
          run: function () { AppState.go("veh"); return "État du véhicule." } },
        { id: "go-conduite", group: "Écrans", phrases: ["conduite", "ouvre la conduite"],
          run: function () { AppState.go("conduite"); return "Conduite." } },
        { id: "go-adas", group: "Écrans", phrases: ["aides à la conduite"],
          run: function () { AppState.go("adas"); return "Aides à la conduite." } },
        { id: "go-media", group: "Écrans", phrases: ["musique", "média"],
          run: function () { AppState.go("media"); return "Musique." } },
        { id: "go-phone", group: "Écrans", phrases: ["téléphone"],
          run: function () { AppState.go("phone"); return "Téléphone." } },
        { id: "go-entretien", group: "Écrans", phrases: ["entretien"],
          run: function () { AppState.go("entretien"); return "Entretien." } },
        { id: "go-parametres", group: "Écrans", phrases: ["paramètres", "réglages"],
          run: function () { AppState.go("parametres"); return "Paramètres." } },
        { id: "back", group: "Écrans", phrases: ["retour", "reviens en arrière"],
          run: function () { AppState.back(); return "Retour." } },

        // ---- média ------------------------------------------------------
        { id: "play", group: "Média", phrases: ["lecture", "reprends la musique"],
          already: function () { return VehicleData.mediaPlaying },
          run: function () { VehicleData.mediaPlaying = true; return "Lecture." } },
        { id: "pause", group: "Média", phrases: ["pause", "arrête la musique"],
          already: function () { return !VehicleData.mediaPlaying },
          run: function () { VehicleData.mediaPlaying = false; return "Pause." } },
        { id: "vol-up", group: "Média", phrases: ["monte le son", "plus fort"],
          already: function () { return AppState.mediaVolume >= 0.999 },
          run: function () { return root._setVolume(AppState.mediaVolume + 0.1) } },
        { id: "vol-down", group: "Média", phrases: ["baisse le son", "moins fort"],
          already: function () { return AppState.mediaVolume <= 0.001 },
          run: function () { return root._setVolume(AppState.mediaVolume - 0.1) } },

        // ---- affichage --------------------------------------------------
        { id: "night-on", group: "Affichage", phrases: ["mode nuit"],
          already: function () { return AppState.nightMode },
          run: function () { AppState.nightMode = true; return "Mode nuit activé." } },
        { id: "night-off", group: "Affichage", phrases: ["mode jour"],
          already: function () { return !AppState.nightMode },
          run: function () { AppState.nightMode = false; return "Mode jour activé." } },

        // ---- questions --------------------------------------------------
        // Une réponse vocale obéit à la même règle que l'affichage : une donnée
        // invalide ne se prononce pas. Dire « zéro kilomètre-heure » parce que
        // le capteur est muet, c'est annoncer un arrêt qui n'a pas lieu.
        { id: "ask-speed", group: "Questions", phrases: ["quelle est ma vitesse", "vitesse"],
          run: function () {
              if (!VehicleData.valid("speed"))
                  return root.unavailable
              return Math.round(VehicleData.speed) + " kilomètres-heure."
          } },
        { id: "ask-range", group: "Questions", phrases: ["quelle est mon autonomie", "autonomie"],
          run: function () {
              if (!VehicleData.valid("batteryLevel") || !VehicleData.valid("consumption"))
                  return root.unavailable
              return "Autonomie estimée : " + VehicleData.range + " kilomètres."
          } },
        { id: "ask-battery", group: "Questions", phrases: ["niveau de batterie", "batterie"],
          run: function () {
              if (!VehicleData.valid("batteryLevel"))
                  return root.unavailable
              return "Batterie à " + VehicleData.batteryLevel + " pour cent."
          } },
        { id: "ask-alerts", group: "Questions", phrases: ["y a-t-il une alerte", "alertes"],
          run: function () {
              var n = VehicleData.activeAlerts.length
              if (n === 0)
                  return "Aucune alerte."
              return (n === 1 ? "Une alerte : " : n + " alertes. La plus importante : ")
                     + VehicleData.topAlert.label + "."
          } },
        { id: "ask-time", group: "Questions", phrases: ["quelle heure est-il", "l'heure"],
          run: function () { return "Il est " + AppState.time.replace(":", " heures ") + "." } },

        // ---- modes de conduite : confirmation ---------------------------
        // Le mode change la réponse de l'accélérateur. Une phrase mal comprise
        // ne doit pas suffire à rendre la navette plus vive.
        { id: "mode-eco", group: "Conduite", phrases: ["mode éco", "mode économie"],
          confirm: true, ask: "Passer en mode éco ?",
          already: function () { return VehicleData.driveMode === "ECO" },
          run: function () { AppState.setDriveMode("eco"); return "Mode éco." } },
        { id: "mode-normal", group: "Conduite", phrases: ["mode normal"],
          confirm: true, ask: "Passer en mode normal ?",
          already: function () { return VehicleData.driveMode === "NORMAL" },
          run: function () { AppState.setDriveMode("normal"); return "Mode normal." } },
        { id: "mode-sport", group: "Conduite", phrases: ["mode sport"],
          confirm: true, ask: "Passer en mode sport ?",
          already: function () { return VehicleData.driveMode === "SPORT" },
          run: function () { AppState.setDriveMode("sport"); return "Mode sport." } },

        // ---- aide à la conduite : asymétrie voulue ----------------------
        // Rallumer une aide ne demande rien ; l'éteindre demande un « oui ».
        // Le coût d'une erreur n'est pas le même dans les deux sens.
        { id: "ldw-on", group: "Conduite", phrases: ["active l'alerte de ligne", "active l'alerte de franchissement de ligne"],
          already: function () { return AppState.adas.ldw },
          run: function () { AppState.toggleAdas("ldw"); return "Alerte de franchissement de ligne activée." } },
        { id: "ldw-off", group: "Conduite", phrases: ["désactive l'alerte de ligne", "désactive l'alerte de franchissement de ligne"],
          confirm: true, ask: "Désactiver l'alerte de franchissement de ligne ?",
          already: function () { return !AppState.adas.ldw },
          run: function () { AppState.toggleAdas("ldw"); return "Alerte de franchissement de ligne désactivée." } },

        // ---- ouvrants : à l'arrêt seulement -----------------------------
        // Ouvrir est refusé en roulant ; fermer ne l'est jamais. Empêcher de
        // refermer une trappe ouverte par erreur serait absurde.
        { id: "flap-open", group: "Ouvrants", phrases: ["ouvre la trappe de charge"],
          stoppedOnly: true,
          already: function () { return root._isOpen("Trappe de charge") },
          run: function () { VehicleData.setOpening("Trappe de charge", true); return "Trappe de charge ouverte." } },
        { id: "flap-close", group: "Ouvrants", phrases: ["ferme la trappe de charge"],
          already: function () { return !root._isOpen("Trappe de charge") },
          run: function () { VehicleData.setOpening("Trappe de charge", false); return "Trappe de charge fermée." } },
        { id: "door-open", group: "Ouvrants", phrases: ["ouvre la porte conducteur"],
          stoppedOnly: true,
          already: function () { return root._isOpen("Porte conducteur") },
          run: function () { VehicleData.setOpening("Porte conducteur", true); return "Porte conducteur ouverte." } },
        { id: "door-close", group: "Ouvrants", phrases: ["ferme la porte conducteur"],
          already: function () { return !root._isOpen("Porte conducteur") },
          run: function () { VehicleData.setOpening("Porte conducteur", false); return "Porte conducteur fermée." } },
        // Le compartiment batterie cumule les deux garde-fous : il donne accès
        // au pack haute tension.
        { id: "pack-open", group: "Ouvrants", phrases: ["ouvre le compartiment batterie"],
          stoppedOnly: true, confirm: true, ask: "Ouvrir le compartiment batterie ?",
          already: function () { return root._isOpen("Compartiment batterie") },
          run: function () { VehicleData.setOpening("Compartiment batterie", true); return "Compartiment batterie ouvert." } },
        { id: "pack-close", group: "Ouvrants", phrases: ["ferme le compartiment batterie"],
          already: function () { return !root._isOpen("Compartiment batterie") },
          run: function () { VehicleData.setOpening("Compartiment batterie", false); return "Compartiment batterie fermé." } }
    ]

    readonly property string unavailable: "Donnée indisponible : le capteur ne répond pas."

    // =========================================================================
    //  Ce que le moteur de reconnaissance reçoit
    // =========================================================================

    // Toutes les phrases reconnaissables, réponses de confirmation comprises,
    // plus « [unk] » : sans cette entrée, un moteur à grammaire restreinte
    // force n'importe quel bruit vers la phrase la plus proche — une toux
    // deviendrait « mode sport ».
    function grammar() {
        var out = []
        for (var i = 0; i < commands.length; i++)
            out = out.concat(commands[i].phrases)
        return out.concat(yesWords, noWords, ["[unk]"])
    }

    // =========================================================================
    //  Traitement d'une phrase
    // =========================================================================
    //
    //  Rend { status, heard, reply }. `status` vaut :
    //    executed   l'action a eu lieu
    //    noop       elle n'aurait rien changé, et c'est dit
    //    confirm    une question attend un oui ou un non
    //    cancelled  la demande en attente est abandonnée
    //    refused    l'état du véhicule l'interdit
    //    unknown    phrase hors table

    function handle(text) {
        var heard = String(text === undefined ? "" : text).trim()
        var said = _normalize(heard)

        // ---- une confirmation est attendue ----------------------------------
        if (pending !== null) {
            var asked = pending
            pending = null
            _confirmTimer.stop()
            if (_listHas(yesWords, said))
                return _finish(heard, _execute(asked))
            if (_listHas(noWords, said))
                return _finish(heard, { status: "cancelled", reply: "Annulé." })
            // Toute autre phrase abandonne la question. Garder une demande en
            // suspens pendant qu'on en traite une autre, c'est laisser un « oui »
            // ultérieur répondre à la mauvaise question.
            var next = _dispatch(said)
            next.reply = "Demande précédente annulée. " + next.reply
            return _finish(heard, next)
        }

        return _finish(heard, _dispatch(said))
    }

    function _dispatch(said) {
        if (_listHas(yesWords, said) || _listHas(noWords, said))
            return { status: "unknown", reply: "Aucune question en attente." }

        var cmd = _find(said)
        if (cmd === null)
            return { status: "unknown", reply: "Je n'ai pas compris." }

        var why = _refusal(cmd)
        if (why !== "")
            return { status: "refused", reply: why }

        if (cmd.already && cmd.already())
            return { status: "noop", reply: _alreadyReply(cmd) }

        if (cmd.confirm) {
            pending = cmd
            _confirmTimer.restart()
            return { status: "confirm", reply: cmd.ask }
        }

        return _execute(cmd)
    }

    // L'autorisation est vérifiée ici, *au moment d'agir* — pas seulement au
    // moment de la demande. Entre « ouvre le compartiment batterie » et le
    // « oui », la navette a pu se mettre à rouler.
    function _execute(cmd) {
        var why = _refusal(cmd)
        if (why !== "")
            return { status: "refused", reply: why }
        return { status: "executed", reply: cmd.run() }
    }

    // Raison du refus, chaîne vide si la commande est permise.
    function _refusal(cmd) {
        if (AppState.hvDiagnosticOpen)
            return "Diagnostic haute tension en cours. L'assistant reprendra après."
        if (AppState.booting)
            return "L'assistant sera disponible à la fin du démarrage."
        if (cmd.stoppedOnly && VehicleData.moving)
            return "Impossible en roulant. Arrêtez la navette d'abord."
        return ""
    }

    function _alreadyReply(cmd) {
        switch (cmd.id) {
        case "vol-up": return "Le volume est déjà au maximum."
        case "vol-down": return "Le volume est déjà coupé."
        case "play": return "La musique joue déjà."
        case "pause": return "La musique est déjà en pause."
        }
        return "C'est déjà le cas."
    }

    function _finish(heard, outcome) {
        var entry = { heard: heard, status: outcome.status, reply: outcome.reply }
        var h = [entry].concat(history)
        history = h.slice(0, historyLength)          // réassignation : notifie
        replied(outcome.reply)
        return entry
    }

    // ---- correspondance ----------------------------------------------------
    // Correspondance exacte, après normalisation. Pas de recherche floue : avec
    // une grammaire restreinte, le moteur ne rend que des phrases de la table,
    // et une tolérance ici ne servirait qu'à accepter ce qu'il n'a pas dit.
    function _find(said) {
        for (var i = 0; i < commands.length; i++)
            for (var j = 0; j < commands[i].phrases.length; j++)
                if (_normalize(commands[i].phrases[j]) === said)
                    return commands[i]
        return null
    }

    function _listHas(list, said) {
        for (var i = 0; i < list.length; i++)
            if (_normalize(list[i]) === said)
                return true
        return false
    }

    // Minuscules, sans accents, sans ponctuation, espaces resserrés. Les
    // accents sont retirés pour que l'essai au clavier accepte « vehicule »
    // comme « véhicule » ; le moteur de reconnaissance, lui, les rend toujours.
    function _normalize(s) {
        var map = { "à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e",
                    "ë": "e", "î": "i", "ï": "i", "ô": "o", "ö": "o", "ù": "u",
                    "û": "u", "ü": "u", "ç": "c", "œ": "oe", "’": "'" }
        var out = ""
        var low = String(s).toLowerCase()
        for (var i = 0; i < low.length; i++) {
            var c = low.charAt(i)
            out += map[c] !== undefined ? map[c] : c
        }
        // Le trait d'union compte comme une espace : un moteur peut rendre
        // « y a t il » là où la table écrit « y a-t-il ».
        return out.replace(/[?!.,;:\-]/g, " ")
                  .replace(/'\s+/g, "'")
                  .replace(/\s+/g, " ")
                  .trim()
    }

    // ---- utilitaires d'action ------------------------------------------------
    function _setVolume(v) {
        AppState.mediaVolume = Math.max(0, Math.min(1, Math.round(v * 10) / 10))
        return "Volume à " + Math.round(AppState.mediaVolume * 100) + " pour cent."
    }

    function _isOpen(label) {
        for (var i = 0; i < VehicleData.openings.length; i++)
            if (VehicleData.openings[i].label === label)
                return VehicleData.openings[i].open
        return false
    }

    property Timer _confirmTimer: Timer {
        interval: root.confirmWindowMs
        onTriggered: {
            if (root.pending === null)
                return
            root.pending = null
            root._finish("", { status: "cancelled", reply: "Pas de réponse. Demande annulée." })
        }
    }
}
