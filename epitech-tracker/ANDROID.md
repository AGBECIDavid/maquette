# Application Android — guide du mainteneur

L'APK est construit par GitHub Actions (`.github/workflows/android.yml`), pas
en local : le SDK Android n'est pas nécessaire sur ta machine.

```
poussée sur main  →  APK en artefact du run         (pour toi)
tag v0.5.0        →  Release GitHub avec l'APK      (pour les testeurs)
```

## Clé de signature — à faire UNE fois, AVANT toute distribution

Android refuse de mettre à jour une application signée par une autre clé. Le
téléphone exige alors de désinstaller — et **désinstaller efface le cursus**
de l'utilisateur. La clé doit donc être la même pour toutes les versions
qu'un testeur recevra, de la première à la dernière.

Tant que la clé n'est pas configurée, le workflow produit un APK de **test**,
signé par une clé jetable différente à chaque build. Il est marqué `-TEST`, et
une publication sur tag refuse de partir sans la vraie clé.

### 1. Générer la clé

```bash
keytool -genkeypair -v \
  -keystore epitech-tracker.jks \
  -alias epitech-tracker \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Epitech Tracker"
```

`keytool` vient avec n'importe quel JDK (`sudo apt install openjdk-21-jdk-headless`).

### 2. Ajouter quatre secrets au dépôt

GitHub → **Settings → Secrets and variables → Actions → New repository secret**

| Nom | Valeur |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | sortie de `base64 -w0 epitech-tracker.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | le mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | `epitech-tracker` |
| `ANDROID_KEY_PASSWORD` | le mot de passe de la clé (souvent le même) |

### 3. Sauvegarder la clé ailleurs que sur ta machine

**Perdre la clé, c'est ne plus jamais pouvoir mettre à jour l'application**
chez les testeurs qui l'ont installée. Garde le `.jks` et ses mots de passe
dans un gestionnaire de mots de passe. Ne la mets jamais dans le dépôt : il
est public, et quiconque la détient peut publier une « mise à jour » que les
téléphones accepteront comme légitime (`android/.gitignore` refuse déjà les
`.jks`, `.keystore` et `.p12`).

## Publier une version

1. Monter la version dans `package.json` **et** `src/version.ts`.
2. Pousser sur `main`, vérifier que le run est vert.
3. Créer le tag :

   ```bash
   git tag v0.5.0 && git push origin v0.5.0
   ```

4. La Release apparaît dans l'onglet **Releases** du dépôt, APK attaché.
   C'est ce lien qu'on envoie aux testeurs.

Le `versionCode` Android est le numéro du run GitHub : il ne fait que croître,
ce qu'Android exige pour accepter une mise à jour.

## Ce qui diffère du site

Trois choses fonctionnent dans un navigateur et cassent dans la WebView d'un
APK. Elles sont traitées dans `src/platform.ts`, et seulement là :

| | Navigateur | APK |
|---|---|---|
| **Export JSON** | téléchargement | le lien `download` ne fait rien — on écrit le fichier puis on ouvre le **partage Android** (Drive, mail, Fichiers…) |
| **Liens externes** | nouvel onglet | `target="_blank"` est ignoré — on ouvre le **navigateur du téléphone** |
| **Bouton retour** | historique du navigateur | fermerait l'app depuis n'importe quel écran — il **remonte l'historique**, et ne quitte qu'au début |

L'export est le point le plus critique : c'est la **seule** sauvegarde. Un
export qui échouerait en silence dans l'APK serait le pire défaut possible.

**Les données de l'APK et celles du site sont séparées.** Ce sont deux
stockages différents. On passe de l'un à l'autre par Exporter / Importer.

## Plein écran et encoche

`viewport-fit=cover` fait passer l'application sous les barres système. Les
marges viennent de deux sources, et `index.css` prend la plus grande :
`env(safe-area-inset-*)` (WebView récentes) et `--safe-area-inset-*`
(injectée par Capacitor sur les WebView plus anciennes, où `env()` vaut zéro).

`SystemBars.style: 'DARK'` veut dire **icônes claires** sur fond sombre. La
valeur par défaut suivrait le thème du téléphone et afficherait, en mode clair,
des icônes noires sur notre fond `#0B1220` — invisibles.

## Icônes

Sources dans `assets/`, générées depuis le logo SVG. Déclinaisons Android
produites par `npx @capacitor/assets generate --android`.

⚠️ Cet outil ajoute un retrait de 16,7 % dans
`mipmap-anydpi-v26/ic_launcher*.xml`. Nos calques sont déjà dessinés pour la
zone sûre : les deux retraits s'additionnaient et réduisaient le logo à moins
de la moitié de l'icône. **Si l'outil est relancé, retirer ce retrait.**

## Tester sans téléphone Android

Impossible de lancer l'APK dans ce dépôt. Ce qui est vérifié automatiquement :
le build Gradle, la signature, et — sur le site — tout le reste. Ce qui ne
l'est **pas** : le comportement réel sur un téléphone. Le premier test sur un
vrai appareil doit couvrir, dans cet ordre, l'export (partage), un lien
externe, le bouton retour, et l'affichage sous l'encoche.
