# Conditions générales d'utilisation — projet

**CartePro**, dispositif du Ministère du Job et Bonheur (JEB/DNI/2026-002 v2.0).
Projet transmis à Mme Pontaillac. **Ne pas publier en l'état** : trois points appellent
une décision du cabinet (signalés « à trancher »).

## Article 1 — Objet et nature du dispositif

CartePro permet à un employeur de créditer ses salariés d'un budget utilisable chez les
partenaires référencés par le Ministère.

**CartePro n'est pas un service de paiement au sens de la réglementation bancaire.**
Dans sa version actuelle, il s'agit d'une **simulation fonctionnelle** : aucune valeur
réelle ne circule, aucun mouvement financier n'est exécuté. Cette mention figure sur
tous les écrans où un montant apparaît.

## Article 2 — Comptes

L'accès est ouvert aux salariés dont l'employeur a adhéré, aux établissements
partenaires validés par le Ministère, et aux agents habilités. L'adhésion d'un
partenaire est soumise à une validation manuelle ; un refus est motivé par écrit et
communiqué à l'établissement dans son espace.

## Article 3 — Utilisation du budget

Le bénéficiaire présente un code de paiement, valable **cinq minutes** et utilisable
**une seule fois**. Un code expiré se régénère sans démarche particulière.

### 3.1 Solde insuffisant

Un encaissement supérieur au solde disponible **est refusé en totalité**. Le dispositif
ne pratique ni paiement partiel, ni découvert, ni complément par un autre moyen : le
partenaire reçoit un refus explicite indiquant le solde disponible et le montant
demandé, et l'opération n'est pas enregistrée.

*Conforme au code : règle R2, testée par `tests/regles-metier.test.mjs`.*

### 3.2 Solde non consommé en fin de période

**À trancher — le code et le présent article divergent aujourd'hui.**

L'application, dans sa version actuelle, **ne fait jamais expirer un solde** : aucun
mécanisme de péremption n'existe dans le code. Deux issues, et une seule doit survivre :

1. **Le solde ne se périme pas.** Alors le présent article doit le dire, et l'employeur
   doit être informé que les sommes créditées restent dues indéfiniment.
2. **Le solde se périme** (fin d'année civile, ou douze mois après créditation, à
   définir). Alors le code doit être complété : mécanisme de péremption, information du
   bénéficiaire avant échéance, et sort des sommes non consommées.

Tant que le cabinet n'a pas tranché, publier une clause de péremption serait une clause
que le service ne respecte pas.

### 3.3 Caractère définitif des opérations

Une opération validée est **définitive** : elle n'est ni modifiée ni supprimée.

## Article 4 — Annulation d'une opération

Une opération peut être annulée par un **agent habilité de l'administration**, à la
demande du bénéficiaire ou du partenaire, ou de sa propre initiative en cas d'erreur
constatée.

L'annulation ne supprime pas l'opération : elle **ajoute une écriture de sens inverse**,
rattachée à l'opération compensée, portant le motif et le nom de l'agent. Le
bénéficiaire est recrédité du montant exact. Les deux écritures restent visibles dans
l'historique.

Ni le bénéficiaire ni le partenaire ne peuvent annuler une opération eux-mêmes.

*Conforme au code : `POST /transactions/{ref}/cancel`, règle R1, testée.*

**À trancher** : faut-il réserver ce pouvoir à certains agents, plutôt qu'à tout compte
d'administration ? Le code ne distingue pas aujourd'hui. Le registre RGPD recommande de
le restreindre.

## Article 5 — Réclamations

Le bénéficiaire peut saisir l'administration depuis son espace. Une réponse est
apportée dans le même fil. Si la réclamation est fondée, l'administration procède à une
régularisation, tracée comme telle et distincte d'une dotation employeur.

## Article 6 — Données personnelles

Le traitement est décrit dans la fiche de registre (article 30 RGPD). Les données sont
conservées treize mois. L'employeur n'a **jamais** accès au détail des dépenses de ses
salariés : il ne voit que le solde et les crédits qu'il a lui-même versés.

**À trancher** : l'effacement des écritures anciennes se fait par anonymisation et non
par suppression, pour ne pas rompre la piste d'audit. Cette limite au droit à
l'effacement doit être assumée ici, ou le mécanisme changé.

## Article 7 — Disponibilité

En cas de connectivité limitée chez un partenaire, l'encaissement est enregistré
localement puis transmis à la reconnexion. Il ne peut pas être compté deux fois. Le
bénéficiaire est débité au moment de la transmission, à la date de la capture.

## Article 8 — Modification des présentes conditions

Toute modification est portée à la connaissance des utilisateurs dans leur espace,
trente jours avant son entrée en vigueur.
