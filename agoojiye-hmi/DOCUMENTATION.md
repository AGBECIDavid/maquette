# AGOOJIYE HMI — Documentation logicielle

Documentation complète de la partie logicielle de la navette électrique
AGOOJIYE : ce qui est utilisé, comment on lance, comment ça fonctionne, et sur
quoi ça tourne.

Trois documents se partagent le sujet, sans se répéter :

| Document | Répond à |
|---|---|
| [README.md](README.md) | *Je viens de cloner, je fais quoi ?* — démarrage en trois commandes |
| **DOCUMENTATION.md** (ce fichier) | *Comment c'est fait, et pourquoi ?* — technologies, architecture, exécution |
| [BACKEND.md](BACKEND.md) | *Comment je branche le vrai véhicule ?* — inventaire des propriétés, trois méthodes de branchement |

---

## 1. Ce que c'est

Une interface homme-machine (IHM) embarquée pour une **navette électrique
ouverte** : le tableau de bord que le conducteur a sous les yeux. Elle affiche
la vitesse, l'énergie, l'état des organes, la navigation, le média, les aides à
la conduite, et elle contrôle la chaîne haute tension au démarrage.

Ce n'est **pas une application web déguisée**. C'est un binaire natif qui
s'ouvre en plein écran, sans navigateur, sans serveur, sans réseau, et qui doit
afficher une image correcte à la seconde où le véhicule est mis sous tension.

### Ce que le logiciel garantit

Trois propriétés sont tenues par la structure du code, pas par la vigilance du
développeur :

1. **Une valeur affichée vient toujours d'une seule source.** Aucun écran ne
   calcule une donnée métier.
2. **Une donnée absente s'affiche `- -`, jamais une valeur inventée.** Un
   capteur muet lève une alerte de lui-même.
3. **Un défaut d'isolement haute tension interdit le démarrage**, et ce refus
   ne se contourne par aucun chemin de l'interface.

---

## 2. Sur quoi ça tourne

### Cible embarquée

| | |
|---|---|
| Système | Linux embarqué (Yocto, Buildroot, Debian embarqué…) |
| Processeur | ARM 64 bits ou x86-64 |
| Affichage | 1600 × 900 logique, plein écran |
| Accélération graphique | **non requise** |
| Réseau | non requis au fonctionnement |
| Audio | micro et haut-parleur pour l'assistant vocal (facultatif) |
| Mémoire | 2 Go libres pour les moteurs vocaux (facultatif) |

La ligne la plus importante de ce tableau est **« accélération graphique : non
requise »**. La cible n'a pas forcément de GPU utilisable, et le rendu peut
tomber en logiciel (`llvmpipe`, `QT_QUICK_BACKEND=software`). Toute la
conception graphique découle de cette contrainte — voir §6.6.

Plateformes Qt utilisables selon l'intégration : `eglfs` (plein écran direct sur
le framebuffer, le cas embarqué classique), `wayland`, `xcb`, ou `offscreen`
pour la recette automatisée.

### Poste de développement

| | |
|---|---|
| Système | Linux (Debian, Ubuntu, Kali testés) |
| Compilateur | GCC ou Clang, **C++17** |
| CMake | ≥ 3.16 |
| Qt | **Qt 6** (6.5 ou plus récent) |

macOS et Windows compilent en principe — rien dans le code n'est spécifique à
Linux — mais seule la ligne Linux est utilisée et vérifiée. Le repli vocal
`spd-say`, lui, est spécifique à Linux.

---

## 3. Les technologies, et pourquoi celles-là

| Technologie | Rôle | Pourquoi elle |
|---|---|---|
| **Qt 6 / QML** | Toute l'interface | Standard de fait de l'IHM embarquée automobile. Déclaratif, animations intégrées, empreinte maîtrisée. |
| **Qt Quick** | Moteur de rendu | Rendu scène-graphe, capable de tomber en logiciel sans changer une ligne de code. |
| **C++17** | Point d'entrée, polices, outillage de recette | Le minimum : Qt charge le QML, et le C++ n'intervient que là où QML ne peut pas. |
| **CMake** | Construction | `qt_add_qml_module` compile le QML *et* les ressources dans le binaire. |
| **Canvas 2D (QML)** | Halos, arc de batterie, vignette | Dessin à la main, sans shader — le seul moyen d'obtenir la même image avec ou sans GPU. |
| **Phosphor Icons** (police) | Toutes les icônes | Une police, pas des images : n'importe quelle taille reste nette, et le jeu complet pèse 3 Mo. |
| **Inter** (police) | Tout le texte | Dessinée pour les écrans, lisible aux petites tailles et de loin. |
| **Qt TextToSpeech** | Assistant vocal | Chemin propre quand le module et son plugin sont installés. |
| **`spd-say`** (speech-dispatcher) | Repli vocal | Existe parce que le plugin Qt manque sur beaucoup d'installations. |
| **Qt Multimedia** | Micro de l'assistant | Capture audio portable ; facultatif — sans lui, l'assistant reste au clavier. |
| **Qt Network** | Dialogue avec les moteurs vocaux | HTTP local, sans bibliothèque tierce. |
| **whisper.cpp** (`whisper-server`) | Reconnaissance de la parole | Whisper en C++, sur processeur, hors ligne ; français correct dès le modèle `base`. |
| **llama.cpp** (`llama-server`) | Compréhension des phrases libres | Modèle de langage local, sortie contrainte par schéma JSON pendant la génération. |
| **Qwen2.5 1,5B Instruct** | Le modèle de langage | Petit, multilingue, rapide sur processeur ; licence Apache 2.0. |
| **Bash** | `run.sh`, `test.sh`, `voice.sh` | Aucune dépendance à installer pour construire, lancer et tester. |
| **Python 3** (bibliothèque standard) | Faux moteurs de la recette | Testent l'interface sans télécharger 1,2 Go de modèles. |

### Ce qui n'est **pas** utilisé, volontairement

- **Aucun `ShaderEffect`, aucun `ShaderEffectSource`.** Ils disparaissent sans
  message d'erreur en rendu logiciel — l'écran serait juste vide sur la cible.
- **Aucune bibliothèque tierce dans l'interface**, aucun gestionnaire de paquets
  (npm, conan, vcpkg). Le dépôt cloné se construit avec Qt et un compilateur.
  Les moteurs vocaux sont des **programmes à part**, compilés par `voice.sh` et
  joints en HTTP local : l'interface ne lie rien d'eux.
- **Aucun accès réseau** au fonctionnement. Les cartes et pochettes d'album sont
  des images embarquées, et l'assistant vocal ne parle qu'à `127.0.0.1`.
- **Aucune base de données.** L'état vit en mémoire, la persistance viendra du
  véhicule.

---

## 4. Installer, construire, lancer

### 4.1 Dépendances

Debian / Ubuntu / Kali :

```bash
sudo apt install build-essential cmake \
                 qt6-base-dev qt6-declarative-dev \
                 qml6-module-qtquick qml6-module-qtquick-controls \
                 qml6-module-qtquick-shapes qml6-module-qtquick-window
```

Pour l'assistant vocal (facultatif) :

```bash
sudo apt install speech-dispatcher          # fournit spd-say — suffit
sudo apt install qt6-speech-speechd-plugin  # chemin Qt natif, si disponible
```

Vérification : si `spd-say -l fr "Bienvenue"` parle dans un terminal, l'assistant
parlera dans l'application.

Pour que l'assistant **entende** (micro) :

```bash
sudo apt install qt6-multimedia-dev          # puis ./run.sh --clean
```

### 4.2 Lancer

```bash
git clone git@github.com:AGBECIDavid/maquette.git
cd maquette/agoojiye-hmi
./run.sh
```

`run.sh` configure, construit, puis lance. Il nomme toute dépendance manquante
avec la commande qui l'installe.

Si Qt vient de l'installeur officiel plutôt que du système :

```bash
CMAKE_PREFIX_PATH=$HOME/Qt/6.8.3/gcc_64 ./run.sh
```

### 4.3 Options de `run.sh`

```bash
./run.sh --build     # construit seulement, ne lance pas
./run.sh --clean     # repart d'un dossier de build vide
./run.sh --help      # liste tout
```

### 4.4 Rejouer un scénario

Le scénario se passe **en argument**, pas en variable d'environnement : il n'y a
aucun nom à retenir.

```bash
./run.sh 00000        # chaîne haute tension saine (défaut)
./run.sh 01000        # batterie de traction en défaut → écran rouge, contournable
./run.sh 10000        # isolement châssis en défaut → démarrage refusé
./run.sh 11111        # toute la chaîne au tapis

./run.sh tyre         # pression des pneus
./run.sh belt         # ceinture non bouclée
./run.sh battery      # batterie critique
./run.sh sensor       # capteur de vitesse muet
./run.sh fault        # défaut système

./run.sh 01000 tyre   # les deux se combinent
```

Un argument mal tapé est **refusé** avec la liste des valeurs valides, plutôt
qu'absorbé en silence : au niveau du shell, une faute de frappe est délibérée.

### 4.5 Construire à la main

`run.sh` n'est qu'une commodité. Le projet est un projet CMake ordinaire :

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
./build/agoojiye-hmi
```

### 4.6 Ce que produit la construction

**Un seul fichier exécutable**, `build/agoojiye-hmi`. Le QML, les polices et les
images sont compilés *dedans* par `qt_add_qml_module` : il n'y a pas de dossier
de ressources à déployer à côté, pas de chemin relatif à respecter. Copier le
binaire sur la cible suffit — avec les bibliothèques Qt, qui restent des
dépendances partagées.

Détails de construction qui comptent :

- **Les singletons QML** (`Theme`, `AppState`, `VehicleData`, `VehicleSimulator`)
  sont déclarés par `set_source_files_properties(... QT_QML_SINGLETON_TYPE TRUE)`,
  **avant** `qt_add_qml_module`. Après, la propriété est ignorée sans erreur et
  l'application échoue au chargement.
- **Le préfixe de ressources est `qrc:/AgoojiyeHMI/`**, fixé par `URI AgoojiyeHMI`.
- **Qt TextToSpeech est cherché en `QUIET`** : absent, la construction réussit à
  l'identique et `AGOOJIYE_HAS_TTS` n'est pas défini.

### 4.7 Les moteurs vocaux

Une fois pour toutes (≈ 5 min de compilation, 1,2 Go de téléchargement) :

```bash
./voice.sh install
```

Puis, à chaque démonstration :

```bash
./run.sh --voix          # lance les moteurs, puis l'interface
```

ou séparément : `./voice.sh start`, `./voice.sh status`, `./voice.sh stop`.

`./voice.sh test` vérifie la chaîne sans micro : une voix de synthèse dit
« Salut Agoojiye, quelle est mon autonomie ? », whisper la transcrit, le modèle
la comprend. Si ce test passe et que l'interface reste sourde, le problème est
le micro, pas les moteurs.

| Réglage | Valeurs | Effet |
|---|---|---|
| `VOICE_ASR` | `tiny` · **`base`** · `small` | `small` reconnaît mieux, 3 fois plus lent |
| `VOICE_LLM` | **`1.5b`** · `3b` | `3b` converse mieux ; licence non commerciale |
| `VOICE_THREADS` | nombre | cœurs par moteur (4 par défaut) |

---

## 5. Structure du dépôt

```
agoojiye-hmi/
├── CMakeLists.txt          construction, ressources, singletons
├── main.cpp                point d'entrée + outillage de recette (208 l.)
├── voiceannouncer.{h,cpp}  voix de l'assistant, deux chemins + file d'attente
├── voicelistener.{h,cpp}   oreille : micro, détection de parole, whisper-server
├── voice.sh                installe et lance les moteurs vocaux
├── voice/
│   └── fake_servers.py     faux moteurs pour la recette
├── run.sh                  construire et lancer, scénarios en argument
├── test.sh                 test de fumée en 9 étapes, sans écran
├── qml/
│   ├── Main.qml            coque : barres, écrans, couches (141 l.)
│   ├── Theme.qml           couleurs et polices, singleton (49 l.)
│   ├── AppState.qml        état d'interface, singleton (204 l.)
│   ├── VehicleData.qml     ← POINT DE BRANCHEMENT DU BACKEND (357 l.)
│   ├── VehicleSimulator.qml source simulée, singleton (309 l.)
│   ├── VoiceCommands.qml   table des commandes vocales, singleton
│   ├── Assistant.qml       conversation : réveil, dialogue, modèle
│   ├── Icons.js            table des points de code Phosphor
│   ├── components/         18 briques réutilisées (1 587 l.)
│   └── screens/            11 écrans + 2 couches (4 910 l.)
└── assets/
    ├── fonts/              Phosphor (2) + Inter (4) — 3,3 Mo
    └── images/             rendus du véhicule, cartes, pochettes — 1,8 Mo
```

Environ **8 600 lignes** de QML, C++ et JavaScript.

---

## 6. Comment ça fonctionne

### 6.1 Trois couches, une seule direction

```
  ┌──────────────────────┐
  │  VehicleSimulator    │   LA SOURCE
  │  (ou le vrai bus CAN)│   produit des valeurs, n'affiche rien
  └──────────┬───────────┘
             │  écrit
             ▼
  ┌──────────────────────┐
  │     VehicleData      │   L'ÉTAT
  │  singleton QML       │   détient, dérive, qualifie
  └──────────┬───────────┘
             │  lu (jamais écrit)
             ▼
  ┌──────────────────────┐
  │ 11 écrans, 2 couches │   L'INTERFACE
  │    17 composants     │   affiche, ne calcule rien de métier
  └──────────────────────┘
```

**La règle tient en une phrase : aucune valeur métier n'est écrite dans un
écran.** C'est ce qui rend le branchement du vrai véhicule indolore — on coupe
le simulateur (`running: false`), on alimente `VehicleData`, et aucun écran ne
change. Les trois méthodes de branchement sont dans [BACKEND.md](BACKEND.md).

C'est aussi ce qui permet de corriger une incohérence **à la source** plutôt
qu'écran par écran : « rouler avec le frein de stationnement serré » n'est pas
corrigé quelque part, c'est **irreprésentable**, parce qu'un seul fichier décide
des deux valeurs.

`AppState` est la quatrième pièce, à côté et non dedans : il porte l'état
**d'interface** (quel écran est ouvert, quelles options l'utilisateur a
basculées) et rien du véhicule.

### 6.2 Le démarrage, et le verrou haute tension

La séquence de démarrage est une **couche**, pas un écran. Elle n'a pas de clé
de navigation, donc aucun bouton ne peut la rejouer — c'est une propriété
structurelle, pas une convention.

```
  mise sous tension
        │
        ▼
  ┌─────────────────┐
  │ étape « hv »    │  contrôle des 5 organes haute tension
  └────┬───────┬────┘
       │       │
    sain    au moins un défaut
       │       │
       ▼       ▼
  ┌─────────┐ ┌──────────────────────┐
  │ « bord »│ │ HvDiagnosticScreen   │  plein cadre, rouge
  │ « pret »│ │ les 5 organes listés │
  └───┬─────┘ └──────────┬───────────┘
      │                 │
      ▼           défaut bloquant ? ──oui──► l'écran ne s'efface pas
  tableau de bord       │
                       non
                        │
                        ▼
                  « Continuer malgré tout » → tableau de bord
```

**Les cinq organes contrôlés**, dans l'ordre du motif :

| Position | Organe | Bloquant |
|---|---|---|
| 1 | NON-Contact Châssis — Circuit HT (isolement) | **oui** |
| 2 | Batterie de traction | non |
| 3 | BMS | non |
| 4 | OBC | non |
| 5 | Moteur | non |

`0` = conforme, `1` = en défaut. Un défaut d'isolement bloque : un circuit haute
tension en contact avec la caisse met les passagers sous tension, et aucun
confort d'usage ne justifie de passer outre.

Quatre détails de sûreté valent d'être connus :

- Le bouton **« Passer »** saute la mise en scène, **pas le contrôle**. S'il
  reste un défaut, il conduit au diagnostic. Le lien est d'ailleurs masqué
  pendant l'étape haute tension.
- Le refus est vérifié dans **`AppState.dismissHvDiagnostic()`**, pas dans
  l'écran — pour qu'aucun autre appelant ne puisse le contourner.
- L'écran de diagnostic montre **les cinq organes**, pas seulement ceux en
  défaut : savoir ce qui a été contrôlé et jugé sain fait partie du diagnostic.
- « Relancer le diagnostic » **réinterroge** la chaîne, il n'efface rien.

### 6.3 La navigation

Sept destinations permanentes dans la barre du bas, décrites une seule fois dans
`AppState.navSections` :

| # | Destination | Clé | Écrans rattachés |
|---|---|---|---|
| 1 | Accueil | `dash` | `dash` |
| 2 | Navigation | `nav` | `nav` |
| 3 | Véhicule | `veh` | `veh`, `entretien` |
| 4 | Conduite | `conduite` | `conduite` |
| 5 | ADAS | `adas` | `adas` |
| 6 | Média | `media` | `media`, `mediaNow` |
| 7 | Paramètres | `parametres` | `parametres` |

Les principes tenus :

- **Toute destination est à un seul appui**, depuis n'importe où. On ne repasse
  jamais par l'accueil.
- **Un écran secondaire garde allumé le bouton de sa section.** Le lecteur média
  allume « Média » ; l'entretien allume « Véhicule ». L'utilisateur sait toujours
  où il est.
- **`AppState.go()` est le seul point d'entrée.** Il ne connaît que des écrans,
  donc la séquence de démarrage lui est inaccessible par construction.
- **Les sections des barres latérales sont mémorisées.** Partir ailleurs et
  revenir retombe sur la section qu'on avait ouverte, pas sur la première.
- Le menu « toutes les applications » n'occupe pas un des sept boutons : il
  s'ouvre depuis la barre du haut, comme un tiroir.

### 6.4 Les alertes et la qualité des signaux

Deux mécanismes qu'un tableau de bord doit avoir, et qui sont souvent absents
d'une maquette.

**Qualité du signal.** Chaque mesure porte un état : `OK`, `STALE` (périmée) ou
`MISSING` (absente).

```qml
VehicleData.valid("speed")            // false si le capteur est muet
VehicleData.reading("speed", v, 0)    // "48" si valide, "- -" sinon
```

Une valeur absente s'affiche **`- -`**. Elle n'est jamais remplacée par la
dernière valeur connue, ni par zéro : un conducteur qui lit `0 km/h` croit être
à l'arrêt.

**Alertes dérivées.** `VehicleData.activeAlerts` est **calculé**, jamais poussé :
il n'existe aucun moyen de lever une alerte qui ne corresponde pas à un état
réel, ni d'oublier de l'éteindre. Trois niveaux — `CRITICAL`, `WARNING`, `INFO` —
et un ordre d'émission fixe, qui décide aussi quelle alerte le bandeau retient
(`topAlert` = la première) : frein de stationnement, ceinture, haute tension,
défaut système, batterie, pneus, dépassement de vitesse, signaux manquants,
ouvrants.

Le bandeau `AlertBanner` **prend sa place dans la colonne** au lieu de se poser
par-dessus l'écran : recouvrir une commande au moment précis où le conducteur la
cherchait est pire que de décaler l'affichage de quelques dizaines de pixels.

### 6.5 La simulation

`VehicleSimulator` occupe exactement la place du futur lien véhicule. Il ne fait
pas bouger des chiffres au hasard — une valeur qui saute trahit la maquette
immédiatement.

Le modèle respecte :

| Grandeur | Valeur | Effet |
|---|---|---|
| Accélération max | 1,1 m/s² | la vitesse ne se téléporte jamais |
| Freinage max | 1,8 m/s² | freinage confortable, pas un mur |
| Masse | 1 450 kg | bilan d'énergie crédible |
| Résistance au roulement | 0,014 | — |
| Traînée | 2,6 m² × Cx | carrosserie ouverte |
| Rendement traction | 0,86 | — |
| Rendement régénération | 0,55 | — |
| Charges auxiliaires | 0,8 kW | écran, éclairage, pompes |

Le scénario joué est celui d'une navette en service : **arrêt → roulage →
ralentissement → arrêt**, en boucle.

**Le pas d'intégration est le temps réellement écoulé**, pas la cadence visée. Un
minuteur Qt n'est pas ponctuel : sous charge, en rendu logiciel ou après un
ramasse-miettes, il arrive en retard. Supposer 100 ms fixes ferait dériver le
véhicule simulé du monde réel — d'autant plus que la cible est modeste. Le pas
est plafonné à 0,35 s : après une longue interruption on ne rattrape pas d'un
bond.

Un mode `deterministic` fixe les durées de phase, pour que la recette mesure le
code et non un tirage au sort.

### 6.6 Le rendu : pourquoi tout est dessiné à la main

`Glow`, `BatteryArc`, `Vignette` sont peints en **Canvas 2D**, et les fonds sont
des dégradés QML. Il n'y a pas un seul shader dans le projet.

C'est délibéré. Un `ShaderEffect` sur une cible sans accélération matérielle ne
produit pas une erreur : il **disparaît en silence**. Un halo absent passe
inaperçu en revue et saute aux yeux dans le véhicule. En dessinant à la main, le
rendu est identique partout — simplement plus ou moins rapide.

Le thème est centralisé dans `Theme.qml` : bleu de marque `#3b82f6` sur fond
navy très sombre, vert pour ce qui va bien, orange et rouge pour ce qui ne va
pas. **`HvDiagnosticScreen` est le seul écran qui n'utilise pas le bleu de
marque** — le rouge y est la couleur porteuse, parce qu'il ne dit pas autre
chose.

### 6.7 L'assistant vocal

On parle à la navette comme à quelqu'un : **« Salut Agoojiye »**, puis ce
qu'on veut, avec ses mots. Elle répond à voix haute, fait ce qui est faisable,
et dit pourquoi quand ce ne l'est pas. Tout tourne **sur la machine** : aucune
phrase ne part sur Internet.

```
  micro ─► VoiceListener ─► whisper-server ─► Assistant ─┬─► VoiceCommands ─► AppState
          (C++ : détection     (reconnaissance,  (réveil,  │   (la table          VehicleData
           de parole, coupé     local)            dialogue) │    décide)
           quand il parle)                                  │
                                                            └─► llama-server
                                                                (comprend, propose)
          VoiceAnnouncer ◄── réponses ◄──────────────────────────────┘
```

Une phrase suit trois chemins possibles, du plus rapide au plus souple :

1. **Formule exacte de la table** (« mode sport ») → exécutée sans attendre.
2. **Phrase libre** (« tu peux me mettre en sport ? ») → le modèle de langage
   comprend et propose **un identifiant de commande**, ou répond lui-même si
   on bavarde (« raconte-moi une blague »).
3. **Modèle absent** → repli prudent : une formule contenue dans la phrase,
   jamais pour une ouverture ni un changement de mode.

Les choix qui tiennent l'ensemble :

- **Le modèle propose, la table décide.** Un schéma JSON imposé pendant la
  génération ne laisse au modèle que deux sorties : un identifiant de la table,
  ou rien. La table applique ensuite ses refus et ses confirmations, et c'est
  **sa** réponse — ce qui s'est réellement passé — qui est prononcée. Un modèle
  qui « croit » ouvrir une trappe en roulant ne peut ni l'ouvrir, ni le dire.
- **Ce qui ne se commande jamais à la voix est absent de la table**, pas
  désactivé : conduite, frein de stationnement, chaîne haute tension,
  régulateur, freinage d'urgence. Aucun identifiant ne les désigne, donc aucun
  modèle ne peut les demander.
- **La voix est un périphérique d'entrée, pas une couche.** Chaque commande
  appelle les fonctions que le tactile appelle déjà.
- **L'autorisation se revérifie au moment d'agir.** Un « oui » prononcé après
  que la navette s'est mise à rouler ne rouvre rien.
- **On ne répond pas à ce qu'on surprend.** Sans le nom, une phrase est
  ignorée. « Agoojiye » n'étant dans aucun dictionnaire, il est reconnu par son
  **squelette phonétique** (« Agoujie », « à Goujie », « Agoudjié » passent ;
  « Algérie », « à gauche » non).
- **Sourd pendant qu'il parle**, sinon il s'entendrait dans les haut-parleurs.
- **Dans l'ordre.** Une phrase dite pendant que le modèle réfléchit attend son
  tour : « merci » ne passe pas avant la réponse qu'il remercie.

Après le réveil, la conversation reste ouverte 12 s après chaque réponse
*prononcée* : on enchaîne sans répéter le nom (« et la batterie ? »).
« Merci » la referme. Le **bouton micro** de la barre d'état vaut « Salut
Agoojiye » — utile quand le vent couvre la voix.

Une **bulle** montre la conversation par-dessus l'écran en cours ; *Paramètres
→ Assistant vocal* en montre le fil entier, permet d'écrire à l'assistant, et
indique l'état des trois maillons (micro, reconnaissance, compréhension).

**Les moteurs** s'installent et se lancent par `./voice.sh` (§4.7). Sans eux,
l'interface tourne à l'identique ; l'assistant reste utilisable au clavier et
pour les formules exactes.

**Le vrai risque est matériel** : la navette est ouverte, donc exposée au vent
et au bruit de roulement. La détection de parole suit le bruit de fond plutôt
qu'un seuil fixe, mais un micro directionnel orienté vers le conducteur
comptera plus que le choix du modèle.

Détail des niveaux de commande, ajout d'une commande, protocole des moteurs :
[BACKEND.md](BACKEND.md).

**Pour la sortie**, deux chemins, essayés dans cet ordre :

1. **Qt TextToSpeech**, quand le module *et* son plugin de sortie
   (`libqtexttospeech_speechd.so`) sont installés.
2. **`spd-say -w -l fr -r -15`** via `QProcess`, le client en ligne de commande
   de speech-dispatcher.

Le second existe parce que le premier demande un plugin qui manque sur beaucoup
d'installations, alors que speech-dispatcher lui-même est souvent déjà là. C'est
la cause du symptôme classique : **`spd-say` parle dans le terminal mais
l'application reste muette** — le module Qt est trouvé, son plugin de sortie ne
l'est pas.

Sans aucun des deux, l'application compile et tourne à l'identique : `speak()` ne
fait rien, `available` reste faux, et l'interface s'appuie sur son affichage
(bulle + onde animée) pour rester lisible. Le destructeur tue le processus et
appelle `spd-say -C` : fermer l'application coupe la voix.

---

## 7. Les écrans

11 écrans et 2 couches, 39 panneaux atteignables au total (un écran à barre latérale compte
une entrée par section).

| Écran | Clé | Sections de la barre latérale |
|---|---|---|
| **Tableau de bord** | `dash` | — (écran de référence : vitesse, énergie, alertes) |
| **Navigation** | `nav` | — (carte, itinéraire, prochaine manœuvre) |
| **Véhicule** | `veh` | Aperçu · Ouvrants et accès · Pression des pneus · Énergie · Températures · Informations |
| **Entretien** | `entretien` | — (sous-écran de Véhicule) |
| **Conduite** | `conduite` | Modes de conduite · Régénération · Traction · Direction · Suspension · Freinage |
| **ADAS** | `adas` | Aides à la conduite · Régulateur de vitesse · Sécurité · Stationnement · Vision · Alerte conducteur |
| **Média** | `media` | Musique · Radio · Bluetooth · USB · Apple CarPlay · Android Auto |
| **Lecture en cours** | `mediaNow` | Lecture · Playlists · Sources · Paramètres audio |
| **Paramètres** | `parametres` | Général · Affichage · Son · Véhicule · Système · Assistant vocal |
| **Téléphone** | `phone` | — |
| **Menu** | `menu` | — (tiroir « toutes les applications ») |
| **Démarrage** | *(aucune)* | couche, pas écran |
| **Diagnostic HT** | *(aucune)* | couche, pas écran |

Les modes de conduite sont ECO, NORMAL, SPORT — poussés vers `VehicleData` et
non gardés dans l'interface, pour que le backend les voie.

---

## 8. Tester

### 8.1 Le test de fumée

```bash
./test.sh
```

Pas besoin d'écran : Qt tourne en mode *offscreen*. **À lancer avant chaque
`git push`.**

Neuf étapes :

| # | Étape | Échoue si |
|---|---|---|
| 1 | Construction | la compilation échoue |
| 2 | Parcours de l'interface | Qt émet **le moindre avertissement QML** |
| 3 | Présence des panneaux | un des 39 panneaux ne produit pas de capture |
| 4 | Séquence de démarrage | la séquence ne se joue pas jusqu'au bout |
| 5 | Cohérence physique sur 30 s | frein de stationnement en roulant, rapport P en roulant, autonomie négative, accélération hors bornes (mesurée sur l'horloge du modèle), ou les 3 phases pas toutes vues |
| 6 | Chaîne d'alerte | une panne injectée ne remonte pas au bandeau |
| 7 | Verrou haute tension | un motif est mal rapporté, ou l'isolement n'est pas bloquant |
| 8 | Assistant vocal | une commande hors table est acceptée, un ouvrant s'ouvre en roulant, un « oui » agit après que la navette a démarré, ou un capteur muet est annoncé comme une valeur |
| 9 | Conversation | le son n'est pas découpé et compris phrase par phrase, l'assistant répond sans avoir été appelé, le dialogue avec le modèle sort des règles de la table, ou un modèle qui ment obtient l'action ou fait prononcer son mensonge |

L'étape 2 est celle qui attrape les vraies régressions : **une dépendance
circulaire ou une propriété inconnue ne casse pas la compilation**, elle fait
s'effondrer une mise en page en silence.

Pour regarder le résultat :

```bash
./test.sh --keep /tmp/captures
```

### 8.2 Relever l'état véhicule en CSV

```bash
HMI_TRACE=30 ./build/agoojiye-hmi > trace.csv
```

Une ligne toutes les 200 ms, 18 colonnes, puis l'application se ferme. Cet outil
existe pour que la simulation se vérifie **comme une donnée** plutôt qu'en
regardant l'écran : « le frein de stationnement n'est jamais serré en roulant »
est une comparaison de colonnes ici, et une opinion autrement.

La colonne **`tick`** porte l'instant du calcul du modèle qui a produit la
ligne ; **`wall`**, celui du relevé. Sans elle, une
accélération se déduirait de l'intervalle *visé* entre deux relevés — or le
relevé peut lui aussi arriver en retard, et le contrôle accuserait la physique
d'un défaut qui n'appartient qu'à l'échantillonnage.

### 8.3 Variables d'environnement de recette

| Variable | Effet |
|---|---|
| `HMI_HV=<5 chiffres>` | applique un motif haute tension |
| `HMI_FAULT=<mot>` | injecte une panne : `belt`, `tyre`, `battery`, `sensor`, `fault` |
| `HMI_TRACE=<s>` | relevé CSV pendant N secondes, puis quitte (force le mode déterministe) |
| `HMI_SCREENSHOT_DIR=<dir>` | parcourt les 39 panneaux, une capture chacun, puis quitte |
| `HMI_VOICE="a\|b\|…"` | rejoue des phrases comme si elles avaient été reconnues ; `@vitesse=N` change la vitesse entre deux |
| `HMI_BOOT_FRAMES=<dir>` | capture la séquence de démarrage image par image |
| `HMI_ASSISTANT="a\|b\|…"` | rejoue des phrases entendues, mot de réveil compris ; `@clavier:texte`, `@vitesse=N`, `@etat` |
| `HMI_VOICE_WAV=fichier.wav` | fait passer un enregistrement par le chemin du micro |
| `AGOOJIYE_NO_MIC=1` | n'ouvre pas le micro (la recette le pose toujours) |
| `AGOOJIYE_ASR_URL`, `AGOOJIYE_LLM_URL` | adresses des moteurs vocaux (`127.0.0.1:8178` et `:8179` par défaut) |

Les arguments de `run.sh` ne font que poser `HMI_HV` et `HMI_FAULT` pour vous.

### 8.4 Ce qui n'est pas encore mesuré

**La fluidité d'animation sur le matériel réel n'a jamais été mesurée.** Toutes
les exécutions de recette passent par `QT_QPA_PLATFORM=offscreen`, qui ne dit
rien du nombre d'images par seconde sur la cible. C'est la première chose à faire
dès qu'un exemplaire du matériel est disponible : `QSG_RENDER_TIMING=1` et une
lecture du temps par image.

---

## 9. Passer en production

Une liste courte, à vérifier avant d'embarquer :

- [ ] **`VehicleSimulator.running` à `false`.** Sinon il continuera d'écraser les
      valeurs venues du bus, en silence.
- [ ] `VehicleData` alimenté par la vraie source — voir [BACKEND.md](BACKEND.md),
      §« Les trois façons de brancher ».
- [ ] `hvTestPattern` remplacé par le résultat du contrôle réel des cinq organes.
- [ ] Qualité des signaux réellement pilotée : `setQuality(nom, "MISSING")` quand
      une trame CAN manque, faute de quoi `- -` ne s'affichera jamais.
- [ ] Points encore en dur passés en revue (liste dans `BACKEND.md`, §« Points
      encore en dur ») : navigation, média, téléphone, entretien.
- [ ] Plateforme Qt choisie (`eglfs` en général) et curseur masqué.
- [ ] Fluidité mesurée sur la cible (§8.4).
- [ ] Moteurs vocaux compilés **sur la cible** (`voice.sh` optimise pour le
      processeur qui compile), lancés comme services, et latence mesurée en
      roulant.
- [ ] Micro choisi et essayé **dans la navette en mouvement**.
- [ ] `./test.sh` au vert.

---

## 10. Dépannage

| Symptôme | Cause | Remède |
|---|---|---|
| CMake ne trouve pas Qt 6 | Qt hors du système | `CMAKE_PREFIX_PATH=$HOME/Qt/6.8.3/gcc_64 ./run.sh` |
| `module "AgoojiyeHMI" is not installed` | singleton déclaré après `qt_add_qml_module` | déplacer les `set_source_files_properties` **avant** |
| Écran noir, aucune erreur | un `ShaderEffect` a été introduit | le remplacer par du Canvas 2D (§6.6) |
| `spd-say` parle, l'application non | plugin de sortie Qt manquant | `sudo apt install qt6-speech-speechd-plugin`, ou laisser le repli faire son travail |
| `./test.sh` échoue en étape 5 sans changement de code | relevé trop court pour voir les 3 phases | `HMI_TRACE` force déjà le mode déterministe ; vérifier qu'il est bien lu |
| Argument de `run.sh` refusé | faute de frappe | `./run.sh --help` liste les valeurs valides |
| `./run.sh: no such file or directory` | mauvais dossier | se placer dans `agoojiye-hmi/` |
| L'assistant n'entend rien | micro absent, coupé, ou Qt Multimedia manquant | *Paramètres → Assistant vocal* : l'état des trois maillons dit lequel |
| Il entend mais ne répond pas | le nom n'a pas été reconnu | la page de l'assistant affiche « entendu sans Salut Agoojiye » ; parler plus près, ou bouton micro |
| Il ne comprend que les formules exactes | modèle de langage arrêté | `./voice.sh status`, puis `./voice.sh start` |
| Réponses lentes (> 3 s) | machine modeste | `VOICE_ASR=tiny`, ou plus de cœurs avec `VOICE_THREADS` |

---

## 11. Pour aller plus loin

- [README.md](README.md) — démarrage rapide, trois choses à savoir avant de
  toucher au code
- [BACKEND.md](BACKEND.md) — inventaire complet des propriétés de `VehicleData`,
  trois méthodes de branchement, points encore en dur
- `./run.sh --help` — tous les scénarios de démonstration
- `qml/VehicleSimulator.qml` — le modèle physique, commenté ligne à ligne
