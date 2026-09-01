# Note de concurrence

**Le risque.** Deux encaissements simultanés sur le même bénéficiaire, dont la somme
dépasse le solde, peuvent tous deux lire le même solde avant que l'un ait débité :
chacun se croit finançable et le solde passe sous zéro (violation de R2).

**Ce qui est en place ici.** Les requêtes d'encaissement sont sérialisées par
bénéficiaire (`withLock("employee:" + id)` dans `lib/api.js`) : la seconde attend que
la première ait lu, vérifié et débité. Le test `R5` de `tests/regles-metier.test.mjs`
lance deux encaissements concurrents de 40 € sur un solde de 50 € et vérifie qu'un
seul aboutit, que l'autre est refusé en 402, et qu'une seule écriture est passée.

**Ce qu'il faudra en production.** Le verrou applicatif ne survit pas à plusieurs
instances : il faut le déplacer dans la base. Trois réponses valables, à combiner :

1. `SELECT balance FROM employees WHERE id = $1 FOR UPDATE` au début de la
   transaction — le second appel attend la fin du premier ;
2. une contrainte `CHECK (balance >= 0)` sur la colonne, qui fait échouer l'écriture
   même si la logique applicative se trompe — la base devient la dernière défense ;
3. l'isolation `SERIALIZABLE` sur la transaction d'encaissement, avec reprise sur
   erreur de sérialisation.

La contrainte (2) est la plus importante : c'est la seule qui tienne encore le jour où
un script, une migration ou un futur endpoint contourne le chemin nominal.

**Ce qui reste à faire.** L'idempotence (R3) est aujourd'hui portée par une table en
mémoire ; en base, elle doit devenir une contrainte d'unicité sur la clé
d'idempotence, de sorte que deux requêtes concurrentes portant la même clé ne puissent
pas créer deux écritures, même sans verrou.
