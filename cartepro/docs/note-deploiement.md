# Note de déploiement

## Critère de recette

L'application doit démarrer intégralement sur la machine de qui récupère le dépôt,
avec les seules instructions ci-dessous. Aucun compte tiers, aucun service managé,
aucune clé à demander.

```bash
git clone <dépôt> && cd cartepro
npm install
cp .env.example .env.local     # aucune valeur n'est obligatoire pour le démonstrateur
npm run dev                    # http://localhost:3000
```

Vérification en trois commandes :

```bash
npm test                       # les cinq règles métier (§3)
npm run build                  # export statique dans out/
curl -s localhost:3000/health  # {"status":"ok","version":"2.0.0","simulation":true}
```

## Ce que le démonstrateur n'a pas encore

L'état vit dans le navigateur (`localStorage`), pas dans une base. La couche API est
simulée dans `lib/api.js`, mais elle parle en chemins REST et en codes HTTP : la
brancher sur un vrai backend consiste à remplacer le corps de `API.call` par un
`fetch`, sans toucher aux écrans. Le schéma cible est dans `docs/schema.sql`.

## Cible de production

| Élément | Choix | Motif |
|---|---|---|
| Exécution | Node 22 LTS, `next start` derrière un reverse proxy | pas de dépendance à un hébergeur |
| Base | PostgreSQL 16, sur la même machine ou un serveur de l'administration | §5.2 : aucune base hébergée |
| Fichiers | système de fichiers local, sauvegardé | §5.2 : pas de stockage objet managé |
| Courriel | relais SMTP de l'administration | §5.2 : pas de service commercial |
| Cartographie | fond de plan schématique, ou tuiles servies par l'IGN | §5.2 : pas d'API cartographique commerciale |
| TLS | terminaison au reverse proxy, HSTS activé | §5.1 |

AWS, GCP et Azure sont exclus par la doctrine « cloud de confiance » : l'application
n'utilise aucun SDK propriétaire, et rien dans le code ne suppose un fournisseur.

## Secrets

Aucun secret n'est versionné. `.env.example` liste les variables attendues avec des
valeurs vides ; `SESSION_SECRET` et `PAYMENT_TOKEN_SECRET` se génèrent avec
`openssl rand -base64 32`. Le dépôt contient un `.gitignore` couvrant `.env*.local`.

## Supervision

`GET /health` renvoie l'état applicatif, la version et le mode de stockage. En
production, y ajouter l'état de la connexion à la base et la dernière migration
appliquée, et le brancher sur la sonde de l'hébergeur.
