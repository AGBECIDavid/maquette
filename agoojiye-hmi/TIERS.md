# Composants tiers et licences

Ce que le projet embarque, télécharge ou utilise, et à quelles conditions.
**Ce fichier est un inventaire, pas un avis juridique** : avant une
distribution commerciale, faites-le relire.

**La licence du projet lui-même n'est pas choisie.** Le dépôt ne contient
aucun fichier `LICENSE` ; tant que c'est le cas, personne d'autre que ses
auteurs n'a le droit de le réutiliser. C'est une décision d'équipe, à prendre
avant de l'ouvrir ou de le livrer.

## Embarqué dans le dépôt

| Composant | Où | Licence | Obligation |
|---|---|---|---|
| Police **Inter** | `assets/fonts/inter/` | SIL Open Font License 1.1 | joindre le texte de la licence à toute redistribution ; ne pas vendre la police seule |
| Icônes **Phosphor** (v2.1) | `assets/fonts/phosphor/` | MIT | conserver la mention de droit d'auteur et le texte de la licence |
| Données **OpenStreetMap** | `map/source/gdiz.osm.json`, `map/gdiz.map.json` | ODbL 1.0 | mention « © contributeurs OpenStreetMap » visible sur la carte (elle l'est, `NavigationScreen.qml`) ; une base dérivée redistribuée reste sous ODbL |
| Images du véhicule | `assets/images/` | **à établir** | rendus tirés d'un modèle 3D et d'images produits par des outils de génération (Meshy, ChatGPT, d'après les noms de fichiers de la maquette d'origine) : vérifier les conditions d'usage commercial de ces outils |

Le texte des licences OFL et MIT n'est pas encore joint au dépôt : à ajouter
avec la licence du projet.

## Lié à l'exécution

| Composant | Rôle | Licence | Obligation |
|---|---|---|---|
| **Qt 6** (Core, Gui, Qml, Quick, Network, Multimedia, TextToSpeech, Test) | bibliothèque d'interface | LGPL v3 (ou licence commerciale) | liaison dynamique, comme ici ; sur un appareil livré, l'utilisateur doit pouvoir remplacer les bibliothèques Qt (clause « anti-tivoïsation » de la LGPL v3) — sinon, licence commerciale Qt |
| **speech-dispatcher** (`spd-say`) | voix de repli | LGPL / GPL | programme séparé, lancé comme tel |
| **gpsd** | position (branchement prévu) | BSD 2 clauses | — |

## Téléchargé par `voice.sh install`, jamais versionné

| Composant | Version épinglée | Licence | Remarque |
|---|---|---|---|
| **whisper.cpp** | `v1.9.5`, commit `d1be6fde` | MIT | compilé sur place |
| **llama.cpp** | `b11497`, commit `ff30363a` | MIT | compilé sur place |
| Modèle **Whisper** (`ggml-base.bin`, ou `tiny`/`small`) | — | MIT | poids publiés par OpenAI |
| Modèle **Qwen2.5-1.5B-Instruct** (GGUF) | — | Apache 2.0 | **le modèle par défaut** ; usage commercial permis |
| Modèle **Qwen2.5-3B-Instruct** (`VOICE_LLM=3b`) | — | Qwen Research License | **non commercial** : ne pas l'embarquer dans un véhicule en service |

Les failles connues de ces deux moteurs n'ont pas été passées en revue pour
les versions épinglées (AUDIT.md, « Ce qui reste ») : à faire avant d'embarquer,
et à refaire à chaque montée de version.

## Outils de développement seulement

Python 3 (bibliothèque standard), CMake, curl, git : rien n'en est redistribué.
