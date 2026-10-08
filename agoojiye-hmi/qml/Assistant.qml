pragma Singleton
import QtQuick

// Pas d'`import AgoojiyeHMI`, pour la même raison que VoiceCommands : les
// singletons voisins sont visibles par l'import du dossier, et un second
// singleton qui importe le module crée une attente circulaire au chargement.
// Ce fichier ne touche donc aucun type C++ : le micro (VoiceListener) et le
// haut-parleur (VoiceAnnouncer) lui sont reliés dans Main.qml.

// =============================================================================
//  ASSISTANT CONVERSATIONNEL
// =============================================================================
//
//   micro ─► VoiceListener ─► hear() ─┐
//                                     ├─► réveil ? ─► ask() ─┬─► VoiceCommands
//   clavier ────────────────► ask() ──┘                      │   (la table décide)
//                                                            │
//                                                            └─► modèle de langage
//                                                                (il propose)
//
//  On parle à la navette comme à quelqu'un : « Salut Agoojiye », puis ce
//  qu'on veut, avec ses mots. Trois chemins, du plus rapide au plus souple :
//
//   1. la phrase est une formule de la table   → exécutée sans attendre
//   2. le modèle de langage est là             → il comprend et propose une
//                                                commande, ou répond
//   3. il n'est pas là                         → repli prudent sur la table
//
//  Le modèle ne fait rien lui-même. Il rend au plus un *identifiant* de
//  commande, contraint par un schéma JSON à n'être qu'un identifiant de la
//  table. La table applique ensuite ses refus et ses confirmations, et c'est
//  sa réponse — ce qui s'est réellement passé — qui est prononcée. Un modèle
//  qui « croit » avoir ouvert une trappe en roulant ne peut ni l'ouvrir, ni le
//  faire dire.
// =============================================================================

QtObject {
    id: root

    // ---- configuration ----------------------------------------------------
    // Serveur de langage local (llama-server). Main.cpp le remplace par
    // AGOOJIYE_LLM_URL quand la variable existe.
    property string llmUrl: "http://127.0.0.1:8179"
    onLlmUrlChanged: checkModel()

    readonly property string name: "Agoojiye"

    // Après le réveil, on parle sans répéter le nom tant que la conversation
    // reste vivante. La fenêtre repart après chaque réponse *prononcée*.
    readonly property int awakeWindowMs: 12000

    // Un modèle qui ne répond pas en 15 s ne répondra pas utilement : on
    // retombe sur la table plutôt que de laisser le conducteur parler au vide.
    readonly property int modelTimeoutMs: 15000

    // ---- état -------------------------------------------------------------
    property bool awake: false
    property bool thinking: false
    property bool modelReady: false

    // Dernière phrase entendue sans le mot de réveil — ignorée, mais montrée à
    // l'écran : en démonstration, c'est ce qui explique un silence.
    property string ignored: ""

    // Fil de la conversation, le plus ancien en tête :
    //   { role: "user" | "assistant", text, status, via: "voix" | "clavier" }
    property var dialog: []
    readonly property int dialogLength: 40

    // Ce qu'il faut prononcer. VoiceCommands émet ses propres réponses ; ceci
    // ne porte que ce que l'assistant dit de lui-même.
    signal said(string text)

    // ---- mot de réveil ------------------------------------------------------
    readonly property var greetings: ["salut", "bonjour", "bonsoir", "hey", "he", "eh",
                                      "ok", "okay", "dis", "coucou", "allo", "hello"]
    readonly property var farewells: ["merci", "merci beaucoup", "c'est tout", "au revoir",
                                      "a plus", "bonne journee", "bonne route", "rien",
                                      "laisse tomber", "ca ira", "c'est parfait merci"]

    // =========================================================================
    //  Entrées
    // =========================================================================

    // Une phrase venue du micro. Hors conversation, elle doit commencer par le
    // nom ; sinon elle est ignorée — on ne répond pas à ce qu'on surprend.
    function hear(text) {
        var clean = String(text).trim()
        if (!/[a-zA-ZÀ-ÿ]/.test(clean))
            return

        var w = detectWake(clean)
        if (!awake && !w.found) {
            ignored = clean
            return
        }
        ignored = ""
        if (w.found && w.rest === "") {
            _openWindow()
            _push("user", clean, "", "voix")
            _say("Oui, je vous écoute.", "chat")
            return
        }
        _openWindow()
        ask(w.found ? w.rest : clean, "voix", clean)
    }

    // Appui-pour-parler : le bouton micro vaut « Salut Agoojiye ». Dans le vent
    // d'une navette ouverte, c'est souvent le chemin le plus sûr.
    function wake() {
        ignored = ""
        _openWindow()
        _say("Je vous écoute.", "chat")
    }

    function sleep() {
        awake = false
        _window.stop()
    }

    // Prolonge la conversation ; appelé quand une réponse a fini d'être dite.
    function keepAwake() {
        if (awake && !thinking)
            _window.restart()
    }

    // Une demande, déjà débarrassée du mot de réveil. `shown` est le texte à
    // afficher dans le fil (la phrase entière, nom compris).
    function ask(text, via, shown) {
        var said = String(text).trim()
        if (said === "")
            return
        // Une conversation se traite dans l'ordre. Pendant que le modèle
        // réfléchit, la phrase suivante attend son tour : sinon un « merci »
        // dit dans la foulée passerait avant la réponse qu'il remercie.
        if (thinking) {
            _inbox = _inbox.concat([ { text: said, via: via, shown: shown } ])
            return
        }
        _push("user", shown !== undefined ? shown : said, "", via || "clavier")
        var n = VoiceCommands.normalize(said)

        // ---- 1. une question attend un oui ou un non ------------------------
        if (VoiceCommands.pending !== null) {
            var yn = yesNo(n)
            if (yn !== 0) {
                _record(VoiceCommands.answer(yn > 0, said))
                return
            }
            // Toute autre phrase passe par la suite, qui abandonne la question.
        }

        // ---- 2. au revoir --------------------------------------------------
        if (VoiceCommands.pending === null && _isFarewell(n)) {
            _say(n.indexOf("merci") === 0 ? "Avec plaisir. Bonne route !" : "D'accord. Je reste là si besoin.", "chat")
            sleep()
            return
        }

        // ---- 3. formule exacte de la table : pas d'attente -------------------
        if (VoiceCommands.match(said) !== null) {
            _record(VoiceCommands.handle(said))
            return
        }

        // ---- 4. le modèle comprend la phrase libre --------------------------
        if (modelReady) {
            _askModel(said)
            return
        }

        // ---- 5. repli sans modèle -------------------------------------------
        _fallback(said)
    }

    // =========================================================================
    //  Reconnaissance du nom
    // =========================================================================
    //
    //  « Agoojiye » n'est dans aucun dictionnaire : un moteur l'écrira
    //  « Agoujie », « à Goujie », « Agoudjié ». On compare donc des squelettes
    //  phonétiques, pas des orthographes. Avec une salutation devant, deux
    //  écarts sont tolérés ; le nom seul doit être plus proche, parce qu'un
    //  début de phrase ordinaire ressemble plus vite à un nom qu'un « salut »
    //  suivi d'un nom.

    readonly property string _target: phonetic(name)

    function detectWake(text) {
        var t = VoiceCommands.normalize(text).split(" ").filter(function (x) { return x.length > 0 })
        var start = 0, greeted = false
        if (t.length > 0 && greetings.indexOf(t[0]) !== -1) {
            start = 1
            greeted = true
        }
        var limit = greeted ? 2 : 1
        for (var k = 1; k <= 3 && start + k <= t.length; k++) {
            var cand = phonetic(t.slice(start, start + k).join(""))
            if (cand.length >= 3 && _distance(cand, _target) <= limit)
                return { found: true, rest: t.slice(start + k).join(" ") }
        }
        return { found: false, rest: "" }
    }

    function phonetic(s) {
        return VoiceCommands.normalize(s)
            .replace(/[^a-z]/g, "")
            .replace(/h/g, "")
            .replace(/dj|dg/g, "j")
            .replace(/g(?=[eiy])/g, "j")
            .replace(/oo|ou/g, "u")
            .replace(/y/g, "i")
            .replace(/ie|ee/g, "i")
            .replace(/(.)\1+/g, "$1")
            .replace(/[estx]$/, "")
    }

    function _distance(a, b) {
        var d = []
        for (var i = 0; i <= a.length; i++)
            d[i] = [i]
        for (var j = 1; j <= b.length; j++)
            d[0][j] = j
        for (i = 1; i <= a.length; i++)
            for (j = 1; j <= b.length; j++)
                d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1,
                                   d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
        return d[a.length][b.length]
    }

    // =========================================================================
    //  Oui, non, au revoir — dits comme on les dit
    // =========================================================================
    //
    //  En conversation on ne répond pas « oui » mais « oui vas-y », « ouais »,
    //  « non merci », « surtout pas ». Le premier mot décide ; au-delà de six
    //  mots, ce n'est plus une réponse mais une nouvelle demande.
    //  Rend 1 (oui), -1 (non), 0 (ni l'un ni l'autre).

    function yesNo(n) {
        var t = n.split(" ")
        if (t.length > 6)
            return 0
        var no = ["non", "annule", "annuler", "laisse", "stop", "surtout", "pas", "nan"]
        var yes = ["oui", "ouais", "ouai", "ok", "okay", "d'accord", "dac", "vas", "allez",
                   "confirme", "confirmer", "valide", "exactement", "absolument",
                   "parfait", "carrement", "evidemment", "volontiers", "go"]
        if (no.indexOf(t[0]) !== -1)
            return -1
        if (yes.indexOf(t[0]) !== -1 || n === "bien sur")
            return 1
        return 0
    }

    function _isFarewell(n) {
        if (farewells.indexOf(n) !== -1)
            return true
        return n.indexOf("merci") === 0 && n.split(" ").length <= 4
    }

    // =========================================================================
    //  Modèle de langage
    // =========================================================================

    // Stable d'une requête à l'autre : llama-server garde en cache le début de
    // conversation identique, et seul le dernier message est alors calculé.
    // L'état du véhicule, qui change, va donc dans le dernier message et non ici.
    readonly property string systemPrompt:
        "Tu es " + name + ", l'assistant vocal embarqué d'une navette électrique à flancs ouverts. "
        + "Tu parles avec le conducteur, en français.\n\n"
        + "Tes réponses sont prononcées à voix haute : une ou deux phrases courtes, naturelles, "
        + "sans liste, sans emoji, sans mise en forme.\n\n"
        + "Tu réponds toujours par un objet JSON {\"command\": ..., \"reply\": ...}.\n"
        + "- \"command\" : l'identifiant d'une commande de la liste ci-dessous si le conducteur "
        + "demande cette action ou cette information, sinon null.\n"
        + "- \"reply\" : ce que tu dis. Quand tu choisis une commande, le système annonce lui-même "
        + "le résultat : \"reply\" reste alors très court.\n\n"
        + "Règles :\n"
        + "- Ne prétends jamais avoir fait une action : seul le système l'exécute et l'annonce.\n"
        + "- Pour la vitesse, la batterie, l'autonomie, les alertes ou l'heure, choisis la commande correspondante.\n"
        + "- Tu ne peux ni conduire, ni accélérer, ni freiner, ni changer de rapport, ni serrer ou "
        + "desserrer le frein de stationnement, ni agir sur la haute tension, le régulateur de vitesse, "
        + "le maintien de voie ou le freinage d'urgence. Si on te le demande, dis-le simplement, "
        + "avec \"command\": null.\n"
        + "- N'invente aucune valeur du véhicule : n'utilise que l'état fourni dans le message.\n"
        + "- Si la demande est ambiguë, pose une courte question.\n"
        + "- Pour une conversation générale, réponds brièvement et aimablement.\n\n"
        + "Commandes disponibles :\n" + VoiceCommands.describeForModel()

    // Le schéma ne laisse au modèle que deux sorties possibles pour « command » :
    // un identifiant de la table, ou null. llama-server le traduit en grammaire,
    // donc la contrainte s'applique pendant la génération — pas après coup.
    readonly property var responseSchema: ({
        type: "object",
        properties: {
            command: { anyOf: [ { type: "string", enum: VoiceCommands.ids() }, { type: "null" } ] },
            reply: { type: "string" }
        },
        required: ["command", "reply"],
        additionalProperties: false
    })

    // Derniers échanges transmis au modèle, pour « et la batterie ? ».
    property var _turns: []
    property var _inbox: []

    // Reprend la phrase suivante, une fois la précédente traitée.
    function _drain() {
        if (thinking || _inbox.length === 0)
            return
        var next = _inbox[0]
        _inbox = _inbox.slice(1)
        ask(next.text, next.via, next.shown)
    }
    property int _generation: 0
    property var _xhr: null
    property string _asked: ""

    function _askModel(text) {
        // Le numéro de génération rend caduque toute réponse antérieure, y
        // compris celle que déclenche l'annulation ci-dessous.
        var gen = ++_generation
        if (_xhr !== null)
            _xhr.abort()
        _asked = text
        thinking = true
        _window.stop()

        var messages = [ { role: "system", content: systemPrompt } ]
            .concat(_turns)
            .concat([ { role: "user", content: "État du véhicule : " + stateSummary() + "\n\nConducteur : " + text } ])

        var xhr = new XMLHttpRequest()
        _xhr = xhr
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || gen !== root._generation)
                return
            root._xhr = null
            root._modelTimer.stop()
            root.thinking = false
            var out = root._parseModel(xhr.status, xhr.responseText)
            if (out === null) {
                root.modelReady = false
                root._fallback(text)
            } else {
                root._applyModel(text, out)
            }
            root._drain()
        }
        xhr.open("POST", llmUrl + "/v1/chat/completions")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({
            model: "agoojiye",
            messages: messages,
            temperature: 0.3,
            max_tokens: 160,
            stream: false,
            cache_prompt: true,
            response_format: { type: "json_schema", json_schema: { name: "reponse", schema: responseSchema } },
            // Modèles « qui réfléchissent » (Qwen3…) : pas de raisonnement à voix
            // haute, il coûterait des secondes pour une phrase.
            chat_template_kwargs: { enable_thinking: false }
        }))
        _modelTimer.restart()
    }

    // Rend { command, reply } ou null si la réponse est inutilisable.
    function _parseModel(status, body) {
        if (status !== 200)
            return null
        try {
            var data = JSON.parse(body)
            var content = data.choices[0].message.content
            var out = JSON.parse(content)
            var reply = typeof out.reply === "string" ? out.reply.trim() : ""
            var cmd = typeof out.command === "string" ? out.command : null
            return { command: cmd, reply: reply }
        } catch (e) {
            return null
        }
    }

    function _applyModel(text, out) {
        var spoken
        if (out.command !== null) {
            // La table tranche, et sa réponse est la seule prononcée : c'est elle
            // qui sait si la trappe s'est ouverte ou a été refusée. La phrase du
            // modèle, écrite avant de le savoir, est écartée.
            var entry = VoiceCommands.handleId(out.command, text)
            _record(entry)
            spoken = entry.reply
        } else {
            spoken = out.reply !== "" ? out.reply : "Je n'ai pas compris."
            // Une conversation qui part ailleurs abandonne la question en attente,
            // comme le fait toute autre phrase.
            if (VoiceCommands.cancelPending())
                spoken = "Demande précédente annulée. " + spoken
            _say(spoken, "chat")
        }
        _remember(text, out.command, spoken)
    }

    function _remember(text, command, spoken) {
        var t = _turns.concat([
            { role: "user", content: text },
            { role: "assistant", content: JSON.stringify({ command: command, reply: spoken }) }
        ])
        _turns = t.slice(Math.max(0, t.length - 8))
    }

    // Sans modèle : une formule contenue dans la phrase, ou l'aveu honnête.
    function _fallback(text) {
        var cmd = VoiceCommands.matchLoose(text)
        if (cmd !== null) {
            _record(VoiceCommands.handleId(cmd.id, text))
            return
        }
        VoiceCommands.cancelPending()
        _say("Je n'ai pas compris. Essayez par exemple : ouvre la navigation, ou quelle est mon autonomie.", "unknown")
    }

    // Ce que le modèle sait du véhicule — rien de plus, et jamais une valeur
    // invalide : un capteur muet est décrit comme tel, sinon le modèle comblerait.
    function stateSummary() {
        var parts = []
        parts.push(VehicleData.valid("speed")
                   ? "vitesse " + Math.round(VehicleData.speed) + " km/h, " + (VehicleData.moving ? "en roulage" : "à l'arrêt")
                   : "vitesse indisponible (capteur muet)")
        parts.push("rapport " + VehicleData.driveGear)
        parts.push("batterie " + VehicleData.batteryLevel + " %")
        parts.push("autonomie " + VehicleData.range + " km")
        parts.push("mode de conduite " + VehicleData.driveMode)
        parts.push("température extérieure " + VehicleData.outsideTemp + " °C")
        parts.push("heure " + AppState.time)
        var open = VehicleData.openings.filter(function (o) { return o.open && o.label.indexOf("Accès") !== 0 })
        parts.push(open.length ? "ouvert : " + open.map(function (o) { return o.label.toLowerCase() }).join(", ") : "ouvrants fermés")
        parts.push(VehicleData.mediaPlaying ? "musique en lecture : " + VehicleData.trackTitle + " de " + VehicleData.trackArtist : "musique en pause")
        var alerts = VehicleData.activeAlerts
        parts.push(alerts.length ? "alertes : " + alerts.map(function (a) { return a.label }).join(", ") : "aucune alerte")
        parts.push("écran affiché : " + AppState.screen)
        return parts.join(" ; ") + "."
    }

    // ---- surveillance du serveur de langage --------------------------------
    function checkModel() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE)
                root.modelReady = xhr.status === 200
        }
        xhr.open("GET", llmUrl + "/health")
        xhr.send()
    }

    // =========================================================================
    //  Fil de conversation
    // =========================================================================

    function _push(role, text, status, via) {
        var d = dialog.concat([ { role: role, text: text, status: status || "", via: via || "" } ])
        dialog = d.slice(Math.max(0, d.length - dialogLength))     // réassignation : notifie
    }

    // Réponse de la table : déjà prononcée par VoiceCommands, seulement notée.
    function _record(entry) {
        if (entry !== null && entry !== undefined)
            _push("assistant", entry.reply, entry.status)
    }

    function _say(text, status) {
        _push("assistant", text, status)
        said(text)
    }

    function _openWindow() {
        awake = true
        _window.restart()
    }

    function clear() {
        dialog = []
        _turns = []
        _inbox = []
        ignored = ""
    }

    Component.onCompleted: VoiceCommands.expired.connect(function (text) {
        root._push("assistant", text, "cancelled")
    })

    property Timer _window: Timer {
        interval: root.awakeWindowMs
        onTriggered: root.awake = false
    }

    property Timer _modelTimer: Timer {
        interval: root.modelTimeoutMs
        onTriggered: {
            if (root._xhr === null)
                return
            // Génération d'abord : l'annulation réveille le gestionnaire de la
            // requête, qui doit la trouver caduque — sinon le repli aurait lieu
            // deux fois, et deux réponses seraient prononcées.
            root._generation++
            var xhr = root._xhr
            root._xhr = null
            xhr.abort()
            root.thinking = false
            root.modelReady = false
            root._fallback(root._asked)
            root._drain()
        }
    }

    // Tant que le modèle n'est pas prêt, on regarde toutes les 5 s : on peut
    // lancer `./voice.sh start` après l'interface, elle s'en apercevra.
    property Timer _health: Timer {
        interval: 5000
        running: !root.modelReady
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkModel()
    }
}
