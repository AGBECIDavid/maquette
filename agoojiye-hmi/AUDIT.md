# Audit technique et de sécurité — IHM AGOOJIYE

Audit du 10 novembre 2026, sur la branche `feat/carte-gdiz` (commit `82c6bcc`).
Corrections sur la branche `fix/audit`.

**Bilan : aucune faille critique ni élevée.** Sept problèmes moyens et neuf
faibles ; treize sont corrigés et vérifiés par la recette, les autres sont
listés en fin de document avec ce qui les bloque.

## 1. Périmètre

| | |
|---|---|
| Audité | `agoojiye-hmi/` : environ 18 500 lignes de C++, QML, JavaScript, shell et Python ; l'historique complet du dépôt (61 commits, toutes branches) pour la recherche de secrets |
| Non audité | le dépôt principal de l'équipe (inaccessible depuis l'environnement d'audit) ; `epitech-tracker/`, autre projet du même dépôt, dont seuls les secrets et les workflows ont été vérifiés |
| Non vérifiable ici | le matériel réel : fluidité sur la cible, micro, GPS ; les failles connues des moteurs vocaux aux versions épinglées |

### Ce qu'est le projet, et ce qui ne s'y applique pas

Une application embarquée Qt 6 / QML, sur un écran de bord. Elle n'a **ni
serveur, ni base de données, ni comptes, ni page web**. Les rubriques
classiques d'un audit web — injection SQL, IDOR, CORS, CSRF, XSS, sessions,
mots de passe, limitation de débit — sont sans objet.

La surface d'attaque réelle :

| Entrée | Qui la contrôle | Protection |
|---|---|---|
| La voix dans l'habitacle | conducteur, passagers, bruit | la table de commandes décide, jamais le modèle ; freins, allumage et sécurité refusés par le code |
| Les deux moteurs vocaux locaux (ports 8178 et 8179) | tout programme de la machine | écoute sur `127.0.0.1` seulement ; adresses limitées à la boucle locale ; réponses traitées comme des propositions |
| Les fichiers lus (carte, son de recette) | qui écrit sur le disque | validation à la lecture (corrigé, §3) |
| Les variables d'environnement | qui lance le programme | outils de recette absents du binaire de production (corrigé, §3) |
| Les scripts d'installation (`voice.sh`, `map.sh`) | Internet au moment de l'installation | sources épinglées par commit, modèles vérifiés par empreinte (corrigé, §3) |
| Le récepteur GPS | le matériel | position jamais inventée : estimée 30 s, puis déclarée perdue |

## 2. Méthode

- Lecture du code et des scripts ; recherche de secrets dans tout l'historique
  (jetons, clés privées, mots de passe, fichiers `.env`, magasins de clés).
- Compilation avec `-Wall -Wextra -Wshadow -Wconversion`.
- Exécution sous **AddressSanitizer** et **UBSan** de six parcours : les 40
  panneaux, un trajet guidé complet, la perte du GPS, la table vocale, la
  conversation, le relevé d'état.
- Entrées malformées : six cartes et cinq fichiers son corrompus.
- Examen du binaire (PIE, RELRO, protection de pile).

## 3. Constats et corrections

Gravité : **M** moyen, **F** faible. Aucun critique, aucun élevé.

### Corrigés

| # | Constat | Où | Correction | Vérifié par |
|---|---|---|---|---|
| M1 | **Faux « hors itinéraire ».** Une pénalité de 80 m, qui sert à choisir la bonne chaussée, était comptée dans l'écart mesuré : 85 m affichés pour une navette sur sa route. Pouvait déclencher un recalcul inutile. | `navigation.cpp`, `track()` | l'écart est la vraie distance au tronçon le plus proche ; la pénalité, ramenée à 30 m, ne sert plus qu'au choix | recette, étape 11 : départ à rebours du cap, écart < 10 m, 0 recalcul |
| M2 | **Outils de recette dans le binaire.** `HMI_ASSISTANT` (`@set:` écrit n'importe quelle valeur véhicule), `HMI_VOICE`, `HMI_NAV`, `HMI_FAULT`, `HMI_HV`, `AGOOJIYE_MAP`… lus à chaque démarrage. | `main.cpp`, `navigation.cpp` | `-DAGOOJIYE_PRODUCTION=ON` : ces outils sont **absents** du binaire ; une variable posée ne produit qu'un avertissement | étape 13 |
| M3 | **Simulateur actif par défaut.** Un oubli avant d'embarquer affichait des valeurs simulées à la place des vraies. | `VehicleSimulator.qml` | lié à la construction : ne démarre pas en production ; badge « DÉMO » dans la barre du haut tant qu'il tourne | étape 13, `--diagnostic` |
| M5 | **Téléchargements non vérifiés.** Modèles de plus d'un gigaoctet pris tels quels ; sources épinglées par étiquette, qu'on peut déplacer. | `voice.sh` | sources épinglées par commit (arrêt si l'étiquette ne concorde plus) ; modèles comparés à `voice/modeles.sha256` ; `pin`, `verify`, `VOICE_STRICT=1` | essai sur des fichiers de substitution : altération refusée |
| M6 | **Réponse libre du modèle prononcée telle quelle.** Sans commande exécutée, il pouvait dire « c'est fait, j'ai ouvert la porte ». | `Assistant.qml` | une réponse qui affirme une action est remplacée par « Je n'ai rien fait… » | étape 9 : faux modèle « menteur » |
| F1 | **Carte malformée → plantage** (indices de nœuds non contrôlés). | `mapdata.cpp` | indices, échelle, emprise et présence d'une route praticable vérifiés au chargement ; refus avec message | 10 cas unitaires ; étape 12 |
| F2 | **Fichier son malformé → lecture hors mémoire.** | `voicelistener.cpp`, `feedWav()` | chaque longueur annoncée est confrontée au fichier | étape 12 : six fichiers |
| F3 | **Aucun test unitaire.** | — | 31 cas Qt Test sur le moteur de carte (`tests/tst_mapdata.cpp`), validés par mutation | étape 1 bis |
| F4 | **Aucune intégration continue pour l'IHM.** | — | `.github/workflows/hmi.yml` lance `./test.sh` | **non vérifié** : voir §5 |
| F5 | **Aucune mention des composants tiers.** | — | `TIERS.md` | relecture |
| F6 | **Documentation périmée** (nombres de lignes, étapes de recette, passage en production). | `DOCUMENTATION.md`, `README.md`, `BACKEND.md` | mise à jour ; les nombres de lignes par fichier, qui périment à chaque commit, sont retirés | relecture |
| F9a | Ports fixes dans la recette (collision possible). | `test.sh` | ports libres demandés au système | recette |
| F9b | `voice.sh stop` tuait le numéro lu dans un fichier, quel que soit le programme. | `voice.sh` | ne tue que l'un de ses deux serveurs | essai : un processus étranger est épargné |

Mesure complémentaire, **non vérifiée** : l'écoute reste coupée 700 ms après
chaque phrase de l'assistant (voir M7).

### Ce qui était déjà sain

- Aucun secret dans le code ni dans l'historique.
- Aucune erreur mémoire sur les six parcours instrumentés.
- Aucun avertissement `-Wall -Wextra` dans le code du projet.
- Binaire : PIE, RELRO complet, protection de pile.
- Moteurs vocaux liés à `127.0.0.1` ; `spd-say` appelé avec `--`.

## 4. État des tests

`./test.sh`, treize étapes, sans écran : **toutes vertes** sur la branche
`fix/audit` (Ubuntu 24.04, Qt 6.4.2).

| Étape | Ce qu'elle vérifie |
|---|---|
| 1, 1 bis | construction ; 31 cas unitaires |
| 2 à 4 | 40 panneaux sans avertissement QML ; séquence de démarrage |
| 5 à 7 | cohérence physique ; chaîne d'alerte ; verrou haute tension |
| 8 à 10 | table vocale ; conversation ; annonces d'alerte |
| 11 | 1 406 itinéraires, trajet guidé, GPS perdu, départ à rebours |
| 12 | six fichiers son et une carte malformés |
| 13 | binaire de production |

L'étape 5 affiche une accélération maximale observée d'environ 1,9 m/s² pour
une borne du modèle de 1,80. C'est attendu : la valeur est mesurée entre deux
relevés, et le test tolère 2,1 pour absorber cet écart d'échantillonnage.

## 5. Ce qui reste

| # | Sujet | Pourquoi ce n'est pas fait | Prochaine action |
|---|---|---|---|
| M7 | **L'assistant n'écoute bien qu'avec un casque.** | la cause n'est pas établie ; elle se diagnostique sur une machine avec micro et haut-parleurs | essai réel après le délai de 700 ms ; sinon annulation d'écho PipeWire (DOCUMENTATION.md §6.7) |
| M4 | **Deux dépôts pour un même code.** La copie maquette → dépôt d'équipe écrase ce qu'un coéquipier y aurait modifié. | décision d'équipe | après fusion, désigner le dépôt d'équipe comme seule source |
| M5 | Empreintes des modèles non inscrites. | Hugging Face est injoignable depuis l'environnement d'audit | `./voice.sh verify`, comparer à la source, `./voice.sh pin` |
| F4 | Intégration continue jamais exécutée. | elle ne tourne que sur GitHub | regarder le premier passage ; le dépôt d'équipe a besoin de sa propre copie du workflow |
| F7 | **Qui parle n'est pas identifié.** Un passager peut dire « déverrouille » à l'arrêt. | choix de conception | à trancher par l'équipe ; sinon, réserver ces commandes au bouton micro du conducteur |
| F8 | Valeurs fictives : numéro de série, « 4G », wifi, média, téléphone. | pas de backend | à brancher avec le véhicule |
| F10 | **Valeurs de départ en production.** Sans backend, `VehicleData` affiche ses valeurs initiales (82 %, chaîne haute tension saine) comme si elles étaient mesurées. Constaté pendant la correction de M3. | c'est le rôle du backend, qui n'existe pas encore | déclarer chaque signal manquant jusqu'à sa première trame (BACKEND.md) |
| F11 | Failles connues de whisper.cpp et llama.cpp aux versions épinglées. | pas de base consultable ici | les passer en revue avant d'embarquer |
| F12 | Licence du projet ; textes des licences tierces ; conditions d'usage des images générées. | décision d'équipe | TIERS.md |
| F13 | PDF de documentation antérieur à la voix, à la carte et à l'audit. | la chaîne qui le produisait n'est pas dans le dépôt | le régénérer, ou le retirer |
| F14 | Textes non traduisibles (aucun `qsTr`) ; `qmllint` non configuré ; liste d'itinéraires reconstruite à chaque lecture. | sans effet aujourd'hui | au fil de l'eau |

## 6. Intégration dans le dépôt de l'équipe

L'IHM y vit déjà, dans `agoojiye-hmi/`, par deux demandes de fusion (assistant
vocal, puis carte). Il ne s'agit donc pas d'y déplacer le projet, mais de :

1. fusionner ces deux demandes, dans cet ordre ;
2. y porter la branche `fix/audit` par une troisième demande ;
3. copier `.github/workflows/hmi.yml` à la racine du dépôt d'équipe (le
   workflow vit hors de `agoojiye-hmi/`, la copie habituelle ne l'emporte pas) ;
4. cesser la double source (M4).

**Retour arrière :** chaque étape est une demande de fusion ; l'annuler (`git
revert` du commit de fusion) rend l'état précédent. Rien n'est supprimé du
dépôt d'équipe en dehors de `agoojiye-hmi/`.

Le plan détaillé — conflits de noms, scripts communs, conventions du dépôt
d'équipe — reste à écrire une fois ce dépôt consultable.
