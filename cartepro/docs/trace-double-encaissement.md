# Trace d'un double encaissement

Généré par `node tests/trace-double-encaissement.mjs`. Le scénario reproduit
un double scan en caisse : la même requête est envoyée deux fois.

État initial : solde 34,62 €, 114 écritures au registre.

---

## Premier appel

**POST /api/v1/transactions**

```json
{
  "token": "1f4a70a902f5e44d",
  "partnerId": "PRT-001",
  "amount": 1850,
  "channel": "qr",
  "idempotencyKey": "caisse-01:1f4a70a902f5e44d:1850"
}
```

**201 Created**

```json
{
  "ref": "TRX-000115",
  "at": "2026-09-01T14:51:08.386Z",
  "amount": 1850,
  "currency": "EUR",
  "status": "validated",
  "channel": "qr",
  "kind": "payment",
  "reverses": null,
  "reversedBy": null,
  "reason": null,
  "partner": {
    "id": "PRT-001",
    "name": "Poney Dream 78",
    "category": "loisirs",
    "city": "Saint-Rémy-lès-Chevreuse"
  },
  "employee": {
    "id": "SAL-0042",
    "name": "Amina Berthier"
  },
  "integrity": {
    "prev": "6a521e6b",
    "hash": "77c95428"
  }
}
```

## Second appel — requête identique, même clé d'idempotence

**POST /api/v1/transactions**

```json
{
  "token": "1f4a70a902f5e44d",
  "partnerId": "PRT-001",
  "amount": 1850,
  "channel": "qr",
  "idempotencyKey": "caisse-01:1f4a70a902f5e44d:1850"
}
```

**200 OK — la transaction existante est renvoyée, aucune écriture ajoutée**

```json
{
  "ref": "TRX-000115",
  "at": "2026-09-01T14:51:08.386Z",
  "amount": 1850,
  "currency": "EUR",
  "status": "validated",
  "channel": "qr",
  "kind": "payment",
  "reverses": null,
  "reversedBy": null,
  "reason": null,
  "partner": {
    "id": "PRT-001",
    "name": "Poney Dream 78",
    "category": "loisirs",
    "city": "Saint-Rémy-lès-Chevreuse"
  },
  "employee": {
    "id": "SAL-0042",
    "name": "Amina Berthier"
  },
  "integrity": {
    "prev": "6a521e6b",
    "hash": "77c95428"
  }
}
```

## État de la table `transactions` après les deux appels

| ref | nature | salarié | partenaire | montant | empreinte précédente | empreinte |
|---|---|---|---|---|---|---|
| `TRX-000113` | payment | SAL-0101 | PRT-001 | 58,39 € | `0aac2e7e` | `b2cbed2c` |
| `TRX-000114` | payment | SAL-0043 | PRT-003 | 17,88 € | `b2cbed2c` | `6a521e6b` |
| `TRX-000115` | payment | SAL-0042 | PRT-001 | 18,50 € | `6a521e6b` | `77c95428` |

## Vérification

| Contrôle | Attendu | Constaté |
|---|---|---|
| Identifiant renvoyé au second appel | `TRX-000115` | `TRX-000115` |
| Écritures ajoutées | 1 | 1 |
| Solde après les deux appels | 16,12 € | 16,12 € |
| Débit constaté | 18,50 € | 18,50 € |

Le second appel n'écrit rien et ne débite rien : il retrouve la transaction par sa
clé d'idempotence et la renvoie telle quelle (R3).
