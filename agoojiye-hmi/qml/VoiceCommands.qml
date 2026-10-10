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
        { label: "Freinage d'urgence, alerte collision", why: "Ne se désactivent jamais à la voix" },
        { label: "Démarrage du moteur, klaxon", why: "Restent au conducteur" }
    ]

    // Le même interdit, côté code : si une phrase en relève, la réponse est
    // donnée ici, sans consulter le modèle de langage — un refus de sécurité ne
    // dépend pas de l'humeur d'un modèle. Chaque entrée : des mots isolés, ou des
    // expressions cherchées telles quelles, et ce qu'on dira ne pas pouvoir faire.
    readonly property var forbiddenVocab: [
        { words: ["frein", "freine", "freiner", "freins", "freinage", "freinez"], say: "freiner" },
        { words: ["accelere", "accelerer", "acceleration", "accelerateur", "accelerez", "fonce"], say: "accélérer" },
        { words: ["volant", "braque", "braquer"], say: "diriger la navette" },
        { words: ["recule", "reculer", "reculez"], phrases: ["marche arriere", "point mort"], say: "changer de rapport" },
        { phrases: ["change de vitesse", "passe la vitesse", "frein a main", "frein de stationnement"], say: "toucher à l'immobilisation" },
        { words: ["demarre", "demarrer", "demarrage", "allumage"],
          phrases: ["coupe le moteur", "eteins le moteur", "arrete le moteur", "coupe le contact", "mets le contact",
                    "allume la navette", "allume le vehicule", "allume la voiture", "allume le moteur",
                    "eteins la navette", "eteins le vehicule", "eteins la voiture"],
          say: "démarrer ou couper le moteur" },
        { words: ["regulateur"], phrases: ["maintien de voie", "freinage d urgence", "alerte collision"], say: "agir sur les aides à la conduite" },
        { phrases: ["haute tension"], say: "agir sur la haute tension" },
        { words: ["klaxon", "klaxonne", "klaxonner", "klaxonnes", "klaxonnez", "corne"], say: "klaxonner" }
    ]

    // La table décide ; elle ne parle pas. Chaque réponse est émise, et c'est
    // Main.qml qui la relie au haut-parleur — le même endroit où se branchera
    // le micro. Ainsi la logique se teste sans aucun périphérique audio.
    signal replied(string text)

    // Une question restée sans réponse, abandonnée par le minuteur. Distinct de
    // `replied` : la conversation doit l'inscrire, alors qu'elle inscrit déjà
    // elle-même les réponses qu'elle a provoquées.
    signal expired(string text)

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
          also: ["gps", "itineraire", "carte"],
          run: function () { AppState.go("nav"); return "Navigation." } },
        { id: "go-veh", group: "Écrans", phrases: ["véhicule", "état du véhicule"],
          run: function () { AppState.go("veh"); return "État du véhicule." } },
        { id: "go-conduite", group: "Écrans", phrases: ["conduite", "ouvre la conduite"],
          run: function () { AppState.go("conduite"); return "Conduite." } },
        { id: "go-adas", group: "Écrans", phrases: ["aides à la conduite"],
          run: function () { AppState.go("adas"); return "Aides à la conduite." } },
        { id: "go-media", group: "Écrans", phrases: ["musique", "média"],
          also: ["radio", "media"],
          run: function () { AppState.go("media"); return "Musique." } },
        { id: "go-phone", group: "Écrans", phrases: ["téléphone"],
          also: ["appel", "appeler"],
          run: function () { AppState.go("phone"); return "Téléphone." } },
        { id: "go-entretien", group: "Écrans", phrases: ["entretien"],
          run: function () { AppState.go("entretien"); return "Entretien." } },
        { id: "go-parametres", group: "Écrans", phrases: ["paramètres", "réglages"],
          run: function () { AppState.go("parametres"); return "Paramètres." } },
        { id: "back", group: "Écrans", phrases: ["retour", "reviens en arrière"],
          run: function () { AppState.back(); return "Retour." } },

        // ---- média ------------------------------------------------------
        { id: "play", group: "Média", phrases: ["lecture", "reprends la musique"],
          also: ["musique", "chanson", "morceau"],
          already: function () { return VehicleData.mediaPlaying },
          run: function () { VehicleData.mediaPlaying = true; return "Lecture." } },
        { id: "pause", group: "Média", phrases: ["pause", "arrête la musique"],
          also: ["musique", "chanson", "morceau"],
          already: function () { return !VehicleData.mediaPlaying },
          run: function () { VehicleData.mediaPlaying = false; return "Pause." } },
        { id: "vol-up", group: "Média", phrases: ["monte le son", "plus fort"],
          also: ["volume", "son", "fort"],
          already: function () { return AppState.mediaVolume >= 0.999 },
          run: function () { return root._setVolume(AppState.mediaVolume + 0.1) } },
        { id: "vol-down", group: "Média", phrases: ["baisse le son", "moins fort"],
          also: ["volume", "son", "bas"],
          already: function () { return AppState.mediaVolume <= 0.001 },
          run: function () { return root._setVolume(AppState.mediaVolume - 0.1) } },

        // ---- affichage --------------------------------------------------
        { id: "night-on", group: "Affichage", phrases: ["mode nuit"],
          also: ["nuit", "sombre", "obscur", "ecran"],
          already: function () { return AppState.nightMode },
          run: function () { AppState.nightMode = true; return "Mode nuit activé." } },
        { id: "night-off", group: "Affichage", phrases: ["mode jour"],
          also: ["jour", "clair", "ecran"],
          already: function () { return !AppState.nightMode },
          run: function () { AppState.nightMode = false; return "Mode jour activé." } },

        // ---- questions --------------------------------------------------
        // Une réponse vocale obéit à la même règle que l'affichage : une donnée
        // invalide ne se prononce pas. Dire « zéro kilomètre-heure » parce que
        // le capteur est muet, c'est annoncer un arrêt qui n'a pas lieu.
        { id: "ask-speed", group: "Questions", phrases: ["quelle est ma vitesse", "vitesse"],
          also: ["vitesse", "vite", "allure", "roule"],
          run: function () {
              if (!VehicleData.valid("speed"))
                  return root.unavailable
              return Math.round(VehicleData.speed) + " kilomètres-heure."
          } },
        { id: "ask-range", group: "Questions", phrases: ["quelle est mon autonomie", "autonomie"],
          also: ["autonomie", "rouler", "kilometre", "kilometres", "km", "reste", "tenir"],
          run: function () {
              if (!VehicleData.valid("battery") || !VehicleData.valid("consumption"))
                  return root.unavailable
              return "Autonomie estimée : " + VehicleData.range + " kilomètres."
          } },
        { id: "ask-battery", group: "Questions", phrases: ["niveau de batterie", "batterie"],
          also: ["batterie", "charge", "pourcentage"],
          run: function () {
              if (!VehicleData.valid("battery"))
                  return root.unavailable
              return "Batterie à " + VehicleData.batteryLevel + " pour cent."
          } },
        { id: "ask-alerts", group: "Questions", phrases: ["y a-t-il une alerte", "alertes"],
          also: ["alerte", "probleme", "souci", "panne", "defaut"],
          run: function () {
              var n = VehicleData.activeAlerts.length
              if (n === 0)
                  return "Aucune alerte."
              return (n === 1 ? "Une alerte : " : n + " alertes. La plus importante : ")
                     + VehicleData.topAlert.label + "."
          } },
        { id: "ask-time", group: "Questions", phrases: ["quelle heure est-il", "l'heure"],
          also: ["heure"],
          run: function () { return "Il est " + AppState.time.replace(":", " heures ") + "." } },

        // ---- modes de conduite : confirmation ---------------------------
        // Le mode change la réponse de l'accélérateur. Une phrase mal comprise
        // ne doit pas suffire à rendre la navette plus vive.
        { id: "mode-eco", group: "Conduite", phrases: ["mode éco", "mode économie"],
          also: ["eco", "economie", "economique"],
          confirm: true, ask: "Passer en mode éco ?",
          already: function () { return VehicleData.driveMode === "ECO" },
          run: function () { AppState.setDriveMode("eco"); return "Mode éco." } },
        { id: "mode-normal", group: "Conduite", phrases: ["mode normal"],
          also: ["normal"],
          confirm: true, ask: "Passer en mode normal ?",
          already: function () { return VehicleData.driveMode === "NORMAL" },
          run: function () { AppState.setDriveMode("normal"); return "Mode normal." } },
        { id: "mode-sport", group: "Conduite", phrases: ["mode sport"],
          also: ["sport", "sportif", "dynamique"],
          confirm: true, ask: "Passer en mode sport ?",
          already: function () { return VehicleData.driveMode === "SPORT" },
          run: function () { AppState.setDriveMode("sport"); return "Mode sport." } },

        // ---- aide à la conduite : asymétrie voulue ----------------------
        // Rallumer une aide ne demande rien ; l'éteindre demande un « oui ».
        // Le coût d'une erreur n'est pas le même dans les deux sens.
        { id: "ldw-on", group: "Conduite", phrases: ["active l'alerte de ligne", "active l'alerte de franchissement de ligne"],
          also: ["ligne", "franchissement"],
          already: function () { return AppState.adas.ldw },
          run: function () { AppState.toggleAdas("ldw"); return "Alerte de franchissement de ligne activée." } },
        { id: "ldw-off", group: "Conduite", phrases: ["désactive l'alerte de ligne", "désactive l'alerte de franchissement de ligne"],
          also: ["ligne", "franchissement"],
          confirm: true, ask: "Désactiver l'alerte de franchissement de ligne ?",
          already: function () { return !AppState.adas.ldw },
          run: function () { AppState.toggleAdas("ldw"); return "Alerte de franchissement de ligne désactivée." } },

        // ---- signalisation ----------------------------------------------
        // Signaler n'est pas conduire : un clignotant ne déplace pas la
        // navette, il prévient les autres. Il se commande donc librement — et
        // se coupe seul après le virage (voir VehicleSimulator).
        { id: "blink-right", group: "Signalisation",
          phrases: ["clignotant droit", "clignotant à droite", "mets le clignotant à droite",
                    "allume le clignotant à droite", "allume le clignotant droit", "mets le clignotant droit"],
          also: ["clignotant", "cligno", "virage", "droite"],
          already: function () { return VehicleData.turnSignal === "right" },
          run: function () { VehicleData.turnSignal = "right"; return "Clignotant droit." } },
        { id: "blink-left", group: "Signalisation",
          phrases: ["clignotant gauche", "clignotant à gauche", "mets le clignotant à gauche",
                    "allume le clignotant à gauche", "allume le clignotant gauche", "mets le clignotant gauche"],
          also: ["clignotant", "cligno", "virage", "gauche"],
          already: function () { return VehicleData.turnSignal === "left" },
          run: function () { VehicleData.turnSignal = "left"; return "Clignotant gauche." } },
        { id: "blink-off", group: "Signalisation",
          phrases: ["éteins le clignotant", "arrête le clignotant", "coupe le clignotant"],
          also: ["clignotant", "cligno"],
          already: function () { return VehicleData.turnSignal === "off" || VehicleData.turnSignal === "hazard" },
          run: function () { VehicleData.turnSignal = "off"; return "Clignotant éteint." } },
        { id: "hazard-on", group: "Signalisation",
          phrases: ["allume les warnings", "mets les warnings", "feux de détresse", "allume les feux de détresse"],
          also: ["warning", "warnings", "detresse"],
          already: function () { return VehicleData.turnSignal === "hazard" },
          run: function () { VehicleData.turnSignal = "hazard"; return "Feux de détresse allumés." } },
        { id: "hazard-off", group: "Signalisation",
          phrases: ["éteins les warnings", "coupe les warnings", "éteins les feux de détresse"],
          also: ["warning", "warnings", "detresse"],
          already: function () { return VehicleData.turnSignal !== "hazard" },
          run: function () { VehicleData.turnSignal = "off"; return "Feux de détresse éteints." } },

        // ---- éclairage ------------------------------------------------------
        // Voir et être vu : tout se commande librement. `also` liste des mots
        // qui désignent la commande sans figurer dans ses formules — ils
        // servent à vérifier qu'une commande proposée par le modèle de langage
        // a bien un rapport avec la phrase (voir `relevant()`).
        { id: "lights-on", group: "Éclairage",
          phrases: ["allume les phares", "allume le phare", "allume les feux", "mets les phares", "phares"],
          also: ["phare", "feux", "lumiere", "eclaire"],
          already: function () { return VehicleData.headlights === "on" },
          run: function () { VehicleData.headlights = "on"; return "Phares allumés." } },
        { id: "lights-off", group: "Éclairage",
          phrases: ["éteins les phares", "coupe les phares", "éteins les feux", "éteins le phare"],
          also: ["phare", "feux"],
          already: function () { return VehicleData.headlights === "off" },
          run: function () { VehicleData.headlights = "off"; VehicleData.highBeam = false; VehicleData.fogLights = false
                             return "Phares éteints." } },
        { id: "lights-auto", group: "Éclairage",
          phrases: ["phares automatiques", "mets les phares en automatique", "phares en auto"],
          also: ["phare", "feux", "automatique", "auto"],
          already: function () { return VehicleData.headlights === "auto" },
          run: function () { VehicleData.headlights = "auto"; return "Phares en automatique." } },
        // Les feux de route supposent les phares allumés : les demander les
        // allume, comme le fait le comodo.
        { id: "highbeam-on", group: "Éclairage",
          phrases: ["allume les feux de route", "feux de route", "pleins phares", "mets les pleins phares"],
          also: ["route", "plein", "pleins"],
          already: function () { return VehicleData.highBeam },
          run: function () { if (VehicleData.headlights === "off") VehicleData.headlights = "on"
                             VehicleData.highBeam = true; return "Feux de route allumés." } },
        { id: "highbeam-off", group: "Éclairage",
          phrases: ["éteins les feux de route", "coupe les pleins phares", "feux de croisement", "baisse les phares"],
          also: ["route", "plein", "pleins", "croisement", "eblouis"],
          already: function () { return !VehicleData.highBeam },
          run: function () { VehicleData.highBeam = false; return "Feux de croisement." } },
        { id: "fog-on", group: "Éclairage",
          phrases: ["allume les antibrouillards", "antibrouillards", "feux antibrouillard"],
          also: ["brouillard", "antibrouillard"],
          already: function () { return VehicleData.fogLights },
          run: function () { if (VehicleData.headlights === "off") VehicleData.headlights = "on"
                             VehicleData.fogLights = true; return "Antibrouillards allumés." } },
        { id: "fog-off", group: "Éclairage",
          phrases: ["éteins les antibrouillards", "coupe les antibrouillards"],
          also: ["brouillard", "antibrouillard"],
          already: function () { return !VehicleData.fogLights },
          run: function () { VehicleData.fogLights = false; return "Antibrouillards éteints." } },
        { id: "cabin-on", group: "Éclairage",
          phrases: ["allume le plafonnier", "allume la lumière", "lumière intérieure", "plafonnier"],
          also: ["lumiere", "plafonnier", "interieur", "lampe"],
          already: function () { return VehicleData.cabinLight },
          run: function () { VehicleData.cabinLight = true; return "Plafonnier allumé." } },
        { id: "cabin-off", group: "Éclairage",
          phrases: ["éteins le plafonnier", "éteins la lumière", "coupe la lumière"],
          also: ["lumiere", "plafonnier", "lampe"],
          already: function () { return !VehicleData.cabinLight },
          run: function () { VehicleData.cabinLight = false; return "Plafonnier éteint." } },

        // ---- visibilité -------------------------------------------------------
        { id: "wipers-on", group: "Visibilité",
          phrases: ["essuie-glace", "essuie-glaces", "lance l'essuie-glace", "lance les essuie-glaces",
                    "allume les essuie-glaces", "mets les essuie-glaces", "allume l'essuie-glace"],
          also: ["essuie", "glace", "glaces", "pluie", "pleut", "balai", "balais"],
          already: function () { return VehicleData.wipers === "normal" },
          run: function () { VehicleData.wipers = "normal"; return "Essuie-glaces en marche." } },
        { id: "wipers-fast", group: "Visibilité",
          phrases: ["essuie-glace rapide", "essuie-glaces plus vite", "essuie-glaces en rapide"],
          also: ["essuie", "glace", "glaces", "vite", "rapide", "rapidement"],
          already: function () { return VehicleData.wipers === "fast" },
          run: function () { VehicleData.wipers = "fast"; return "Essuie-glaces en rapide." } },
        { id: "wipers-slow", group: "Visibilité",
          phrases: ["essuie-glace intermittent", "essuie-glaces moins vite", "essuie-glaces lentement"],
          also: ["essuie", "glace", "glaces", "lent", "lentement", "intermittent", "doucement"],
          already: function () { return VehicleData.wipers === "intermittent" },
          run: function () { VehicleData.wipers = "intermittent"; return "Essuie-glaces en intermittent." } },
        { id: "wipers-auto", group: "Visibilité",
          phrases: ["essuie-glace automatique", "essuie-glaces en automatique"],
          also: ["essuie", "glace", "glaces", "automatique", "auto", "pluie"],
          already: function () { return VehicleData.wipers === "auto" },
          run: function () { VehicleData.wipers = "auto"; return "Essuie-glaces en automatique." } },
        { id: "wipers-off", group: "Visibilité",
          phrases: ["arrête l'essuie-glace", "arrête les essuie-glaces", "coupe les essuie-glaces",
                    "éteins les essuie-glaces"],
          also: ["essuie", "glace", "glaces", "balai", "balais"],
          already: function () { return VehicleData.wipers === "off" },
          run: function () { VehicleData.wipers = "off"; return "Essuie-glaces arrêtés." } },
        { id: "washer", group: "Visibilité",
          phrases: ["lave-glace", "nettoie le pare-brise", "lave le pare-brise"],
          also: ["lave", "nettoie", "pare", "brise", "sale", "propre"],
          run: function () { VehicleData.washing = true; return "Lave-glace." } },
        { id: "defog-on", group: "Visibilité",
          phrases: ["désembuage", "allume le désembuage", "désembue le pare-brise"],
          also: ["buee", "embue", "desembuage", "desembue", "pare", "brise"],
          already: function () { return VehicleData.defog },
          run: function () { VehicleData.defog = true; return "Désembuage en marche." } },
        { id: "defog-off", group: "Visibilité",
          phrases: ["éteins le désembuage", "arrête le désembuage"],
          also: ["buee", "desembuage"],
          already: function () { return !VehicleData.defog },
          run: function () { VehicleData.defog = false; return "Désembuage arrêté." } },

        // ---- verrouillage -------------------------------------------------------
        // Verrouiller est toujours permis ; déverrouiller en roulant ne l'est pas.
        { id: "lock", group: "Accès",
          phrases: ["verrouille les portes", "verrouille", "verrouille la navette", "ferme à clé"],
          also: ["verrou", "verrouille", "cle", "verrouillage"],
          already: function () { return VehicleData.locked },
          run: function () { VehicleData.locked = true; return "Navette verrouillée." } },
        { id: "unlock", group: "Accès",
          phrases: ["déverrouille les portes", "déverrouille", "déverrouille la navette"],
          also: ["verrou", "deverrouille", "cle", "verrouillage"],
          stoppedOnly: true,
          already: function () { return !VehicleData.locked },
          run: function () { VehicleData.locked = false; return "Navette déverrouillée." } },

        // ---- annonces aux passagers ------------------------------------------------
        // Une navette transporte du public : l'assistant parle aussi pour lui.
        { id: "announce-stop", group: "Annonces",
          phrases: ["annonce le prochain arrêt", "annonce l'arrêt", "prochain arrêt"],
          also: ["annonce", "arret", "station", "passagers"],
          run: function () { return "Mesdames et messieurs, prochain arrêt : " + VehicleData.nextStop + "." } },
        { id: "announce-departure", group: "Annonces",
          phrases: ["annonce le départ", "attention au départ", "annonce la fermeture"],
          also: ["annonce", "depart", "fermeture", "passagers", "tenez"],
          run: function () { return "Attention, départ imminent. Merci de vous tenir." } },

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
        return _dispatchCmd(cmd)
    }

    function _dispatchCmd(cmd) {
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

    // =========================================================================
    //  Entrées de la conversation
    // =========================================================================
    //
    //  En conversation, la phrase n'est plus une formule de la table : « tu peux
    //  me mettre en sport ? » arrive par le modèle de langage, qui ne rend qu'un
    //  *identifiant*. Ces entrées-là mènent aux mêmes règles que `handle()` —
    //  refus, confirmation, revérification au moment d'agir. Le modèle choisit
    //  quoi demander ; la table seule décide si cela se fait, et dit ce qui
    //  s'est réellement passé.

    // Exécute une commande désignée par son identifiant. Un identifiant hors
    // table — inventé, ou une action interdite — est traité comme une phrase
    // incomprise : il n'existe aucun chemin vers une action absente.
    function handleId(id, heard) {
        var cmd = _byId(id)
        var prefix = cancelPending() ? "Demande précédente annulée. " : ""
        var out = cmd === null ? { status: "unknown", reply: "Je n'ai pas compris." }
                               : _dispatchCmd(cmd)
        out.reply = prefix + out.reply
        return _finish(heard === undefined ? "" : heard, out)
    }

    // Réponse à la question en attente, quand la conversation a déjà établi
    // qu'il s'agit d'un oui ou d'un non (« oui vas-y », « non merci »).
    // Null s'il n'y avait pas de question : un « oui » sans objet ne fait rien.
    function answer(yes, heard) {
        if (pending === null)
            return null
        var asked = pending
        cancelPending()
        return _finish(heard, yes ? _execute(asked)
                                  : { status: "cancelled", reply: "Annulé." })
    }

    // Abandonne la question en attente. Vrai s'il y en avait une.
    function cancelPending() {
        if (pending === null)
            return false
        pending = null
        _confirmTimer.stop()
        return true
    }

    // La commande dont une phrase est exactement une formule, ou null.
    function match(text) { return _find(_normalize(text)) }

    // Repli sans modèle de langage : une formule de la table *contenue* dans la
    // phrase (« euh, ouvre la navigation s'il te plaît »). Volontairement
    // étroit — une phrase contenant une négation est écartée (« ne mets pas la
    // musique »), et seules les commandes sans garde-fou sont admises : un
    // ouvrant ou un changement de mode ne se déduit pas d'un fragment.
    function matchLoose(text) {
        var said = " " + _normalize(text) + " "
        // « plus » n'y figure pas : c'est aussi « plus fort ».
        if (/ (ne|n'|pas|jamais) /.test(said.replace(/n'/g, " n' ")))
            return null
        var best = null, bestLen = 0
        for (var i = 0; i < commands.length; i++) {
            var c = commands[i]
            if (c.stoppedOnly || c.confirm)
                continue
            for (var j = 0; j < c.phrases.length; j++) {
                var p = _normalize(c.phrases[j])
                if (p.length > bestLen && said.indexOf(" " + p + " ") !== -1) {
                    best = c; bestLen = p.length
                }
            }
        }
        return best
    }

    function normalize(s) { return _normalize(s) }

    // =========================================================================
    //  Vérifications indépendantes du modèle de langage
    // =========================================================================
    //
    //  Un petit modèle, s'il ne connaît pas la fonction demandée, désigne la
    //  commande qui lui « ressemble » plutôt que d'avouer. Ces fonctions le
    //  rattrapent par le texte même de la phrase — aucune ne lui fait confiance.

    // Mots sans valeur pour reconnaître une fonction : articles, pronoms, et
    // verbes d'action génériques (« allume », « mets »… valent pour tout).
    readonly property var _stopwords: [
        "le", "la", "les", "l", "un", "une", "des", "de", "du", "d", "au", "aux", "a", "en",
        "et", "ou", "sur", "pour", "par", "avec", "dans", "plus", "moins", "tres", "peu",
        "je", "tu", "il", "elle", "on", "nous", "vous", "me", "te", "se", "moi", "toi", "lui",
        "mon", "ma", "mes", "ton", "ta", "tes", "sa", "ses", "ce", "cet", "cette", "ca", "cela",
        "est", "es", "sont", "y", "t", "s", "n", "ne", "pas", "que", "qui", "quoi", "quel", "quelle",
        "allume", "allumer", "eteins", "eteindre", "mets", "mettre", "met", "coupe", "couper",
        "ouvre", "ouvrir", "ferme", "fermer", "active", "activer", "desactive", "desactiver",
        "lance", "lancer", "arrete", "arreter", "passe", "passer", "fais", "faire", "peux",
        "peut", "pourrais", "veux", "voudrais", "stp", "svp", "plait", "sil", "merci", "mode",
        "agoojiye", "salut", "bonjour", "hey", "ok", "dis", "allez", "vas", "va", "maintenant",
        // le véhicule lui-même : le nommer ne désigne aucune de ses fonctions
        "navette", "vehicule", "voiture", "bus", "camion"
    ]

    // Mots porteurs de sens, au singulier. Les mots génériques sont écartés
    // *avant* d'ôter la marque du pluriel : sinon « éteins » deviendrait
    // « étein », que la liste ne connaît pas, et passerait pour un mot-clé
    // commun à toutes les commandes qui éteignent quelque chose.
    function _words(text) {
        var stop = _stopwords
        return _normalize(text).replace(/'/g, " ").split(" ")
            .filter(function (w) { return w.length > 0 && stop.indexOf(w) === -1 })
            .map(function (w) { return w.length > 3 ? w.replace(/[sx]$/, "") : w })
            .filter(function (w) { return stop.indexOf(w) === -1 })
    }

    // Les mots qui désignent une commande : ceux de ses formules, moins les
    // mots génériques, plus ses synonymes (`also`).
    function keywords(cmd) {
        var out = []
        var src = cmd.phrases.concat(cmd.also || [])
        for (var i = 0; i < src.length; i++) {
            var ws = _words(src[i])
            for (var j = 0; j < ws.length; j++)
                if (out.indexOf(ws[j]) === -1)
                    out.push(ws[j])
        }
        return out
    }

    // Vrai si la phrase contient au moins un mot qui désigne la commande.
    // « Allume les phares » → mode nuit : aucun mot commun, la proposition du
    // modèle ne passe pas sans qu'on demande.
    function relevant(cmd, text) {
        var ws = _words(text)
        var ks = keywords(cmd)
        for (var i = 0; i < ws.length; i++)
            if (ks.indexOf(ws[i]) !== -1)
                return true
        return false
    }

    // Vrai si la phrase nomme au moins une fonction de la table. Sert à ne pas
    // prendre « accélère les essuie-glaces » pour une demande d'accélérer.
    function mentionsAllowed(text) {
        for (var i = 0; i < commands.length; i++)
            if (relevant(commands[i], text))
                return true
        return false
    }

    // Ce que la phrase demande d'interdit (« freiner », « klaxonner »…), ou ""
    // si rien. Ne s'applique qu'aux phrases qui ne nomment aucune fonction
    // permise.
    function forbiddenAsk(text) {
        if (mentionsAllowed(text))
            return ""
        var n = " " + _normalize(text).replace(/'/g, " ") + " "
        var ws = _words(text).concat(_normalize(text).replace(/'/g, " ").split(" "))
        for (var i = 0; i < forbiddenVocab.length; i++) {
            var f = forbiddenVocab[i]
            var hit = (f.words || []).some(function (w) { return ws.indexOf(w) !== -1 })
                      || (f.phrases || []).some(function (p) { return n.indexOf(" " + p + " ") !== -1 })
            if (hit)
                return f.say
        }
        return ""
    }

    // Refus d'une demande interdite, avec sa raison.
    function refuseForbidden(what, heard) {
        cancelPending()
        return _finish(heard, { status: "refused",
            reply: "Je ne peux pas " + what + " : la conduite et la sécurité restent entre vos mains." })
    }

    // Fonction qui n'existe pas sur la navette : on le dit, en nommant ce qui
    // a été compris, plutôt que de faire autre chose à la place.
    function refuseUnavailable(what, heard) {
        cancelPending()
        var w = String(what || "").trim().replace(/[.!?]+$/, "")
        return _finish(heard, { status: "unavailable",
            reply: (w !== "" ? "« " + w + " » : cette fonction" : "Cette fonction")
                   + " n'est pas disponible sur la navette." })
    }

    // Le modèle propose une commande sans rapport visible avec la phrase : on
    // ne l'exécute pas, on la demande. Une erreur de compréhension devient une
    // question à laquelle on répond « non », au lieu d'une action à défaire.
    function proposeGuess(cmd, heard) {
        var prefix = cancelPending() ? "Demande précédente annulée. " : ""
        var why = _refusal(cmd)
        if (why !== "")
            return _finish(heard, { status: "refused", reply: prefix + why })
        if (cmd.already && cmd.already())
            return _finish(heard, { status: "noop", reply: prefix + _alreadyReply(cmd) })
        pending = { id: cmd.id, run: cmd.run, stoppedOnly: cmd.stoppedOnly,
                    ask: "Vous voulez dire : " + cmd.phrases[0] + " ?" }
        _confirmTimer.restart()
        return _finish(heard, { status: "confirm", reply: prefix + pending.ask })
    }

    function ids() {
        return commands.map(function (c) { return c.id })
    }

    // La table, décrite pour le modèle de langage : un identifiant par ligne,
    // sa formule et ses garde-fous. Le modèle n'a pas à connaître les règles
    // pour les respecter — la table les applique — mais les connaître lui évite
    // de proposer en vain une ouverture en roulant.
    function describeForModel() {
        return commands.map(function (c) {
            var notes = []
            if (c.stoppedOnly) notes.push("à l'arrêt seulement")
            if (c.confirm) notes.push("demande confirmation")
            return "- " + c.id + " : « " + c.phrases.join(" », « ") + " »"
                   + (notes.length ? " (" + notes.join(", ") + ")" : "")
        }).join("\n")
    }

    function byId(id) { return _byId(id) }

    function _byId(id) {
        for (var i = 0; i < commands.length; i++)
            if (commands[i].id === id)
                return commands[i]
        return null
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
        case "blink-off": return VehicleData.turnSignal === "hazard"
                                 ? "Ce sont les feux de détresse : dites « éteins les warnings »."
                                 : "Aucun clignotant n'est allumé."
        case "hazard-off": return "Les feux de détresse sont déjà éteints."
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
            var entry = root._finish("", { status: "cancelled", reply: "Pas de réponse. Demande annulée." })
            root.expired(entry.reply)
        }
    }
}
