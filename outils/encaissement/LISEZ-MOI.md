# L'encaissement partenaire

Le seul écran du partenaire où le métier est réellement en jeu : un code à
usage unique qui expire en cinq minutes, et une clé d'idempotence qui garantit
qu'un double clic ne débite jamais deux fois.

## Poser les fichiers

Depuis `front/` :

    cp -r /tmp/outils-maquette/outils/encaissement/src/. src/

Rien n'est écrasé sauf les trois ébauches `Encaissement.tsx`, `EtapeJeton.tsx`
et `EtapeMontant.tsx` du dossier `encaissement/`, qui ne contenaient
que `return null`.

## Ce qui est apporté

| Fichier | Rôle |
|---|---|
| `src/types/encaissement.ts` | Le vocabulaire, et `ErreurEncaissement` qui porte le code de refus |
| `src/lib/montant.ts` | Lecture et affichage des montants, en centimes entiers |
| `src/lib/services/encaissement.service.ts` | `resoudreJeton` et `encaisser` |
| `…/encaissement/EtapeJeton.tsx` | Étape 1 — le code présenté par le client |
| `…/encaissement/EtapeMontant.tsx` | Étape 2 — le montant, la clé, le compte à rebours |
| `…/encaissement/Encaissement.tsx` | La machine à trois états et le reçu |

## Les trois décisions qui portent tout le reste

**La clé d'idempotence est forgée à la caisse, une fois, et ne bouge plus.**
Elle vit dans un `useRef` d'`EtapeMontant`. Si le caissier double-clique, si
le réseau lâche après que le serveur a écrit, si la requête est rejouée depuis
la file hors ligne, le serveur reconnaît la clé et renvoie la transaction déjà
écrite. Un seul débit. La régénérer à chaque essai annulerait toute la
protection.

**L'argent est un entier de centimes, lu sur la chaîne.** Jamais
`parseFloat(x) * 100` : `29.7 * 100` vaut `2969.9999999999995`. On découpe
« 12,50 » en deux morceaux et on additionne.

**L'état est un type somme, pas un sac de champs.** À l'étape « montant » il y
a forcément un jeton résolu ; à l'étape « jeton » il n'y en a pas. Le
compilateur refuse alors d'écrire un écran qui demande un montant sans savoir
qui paie.

## Vérifié

`tsc --noEmit` et `next build` verts. Cinq tests sur la lecture des montants,
44 assertions, dont les pièges du flottant et quatorze saisies à refuser :

    node --test outils/encaissement/tests/montant.test.mjs

(le test importe le `.ts` directement ; il tourne sur Node 22+, ou après
transpilation.)

## Le seul fil qui pend

`Encaissement.tsx` porte `const PARTENAIRE = "PRT-DEMO"`. À remplacer par
l'établissement de la session dès qu'`auth.service.ts` l'expose.
