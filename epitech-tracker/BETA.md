# Guide du bêta-testeur

**👉 https://epitech-tracker.vercel.app**

Merci de tester **Epitech Tracker**. Voici ce qu'il faut savoir avant de
commencer, et comment faire remonter ce qui ne va pas.

## Où sont tes données — à lire en premier

**Tout reste dans ton navigateur.** Il n'y a pas de serveur : ce que tu saisis
ne part nulle part, et personne d'autre — y compris l'auteur de l'application —
ne peut le voir.

Trois conséquences concrètes :

- **Pas de mot de passe**, parce qu'il n'y aurait rien à protéger côté serveur.
  Le « profil » que tu crées est un tiroir local, pas un compte en ligne. Sur
  une machine partagée, quelqu'un d'autre peut ouvrir ton profil.
- **Vider les données de ton navigateur efface ton cursus.** Idem en navigation
  privée : tout disparaît à la fermeture.
- **Pense à exporter** régulièrement : *Paramètres → Exporter en JSON*. C'est
  aujourd'hui la seule sauvegarde possible.

Chaque testeur crée donc son propre profil, sur son propre navigateur. Vos
données ne se croisent jamais.

## Ce qu'on cherche

Pas seulement des plantages. Surtout :

1. **Des chiffres qui semblent faux.** Une progression, un total de crédits, un
   « il manque X crédits » qui ne correspond pas à ce que tu attendais. C'est le
   cœur de l'application : un chiffre faux la rend inutile.
2. **Des règles qui ne collent pas à Epitech.** L'application applique des
   règles listées dans *Paramètres → Règles de calcul appliquées*. Si l'une
   d'elles ne correspond pas à la réalité de ton cursus, dis-le — c'est
   l'information la plus précieuse qu'on puisse recevoir.
3. **Des endroits où tu ne sais pas quoi faire.** Un écran vide, un bouton que
   tu n'oses pas cliquer, un mot qui ne veut rien dire pour toi.
4. **Ce qui te manque** pour utiliser l'outil au quotidien plutôt qu'une fois.

## Un parcours de test en dix minutes

1. Crée ton profil, en choisissant ton niveau (TEK1 à TEK5). Coche « données
   d'exemple » pour explorer, ou décoche pour partir de ton vrai cursus.
2. Crée un Roadblock, un module dedans, deux ou trois projets.
3. Passe un projet à « Terminé », un autre à « Validé ». **Regarde les crédits :
   seul « Validé » en rapporte.** Est-ce que ça correspond à ta réalité ?
4. Mets une deadline dans le passé sur un projet : il doit apparaître en retard,
   au dashboard et dans les alertes.
5. Ouvre *Statistiques* : les graphiques et la projection « à ce rythme ».
6. Ouvre *Calendrier* : tes dates doivent y être.
7. Va dans *Paramètres* et essaie « Passer au niveau suivant ». Ton année
   précédente doit rester consultable par le sélecteur en haut.

## Signaler un problème

*Paramètres → **Signaler un problème*** ouvre un formulaire déjà rempli avec ta
version, ton navigateur et ton écran. Décris trois choses :

```
Ce que j'ai fait     →  les étapes, dans l'ordre
Ce que j'attendais   →  le résultat que tu croyais obtenir
Ce qui s'est passé   →  ce que l'écran a montré à la place
```

Si le problème touche tes chiffres ou tes données, joins le fichier de
*Paramètres → Exporter un diagnostic*. Il contient la version, ton navigateur,
les compteurs — **et l'intégralité de ton cursus, notes personnelles comprises**.
Relis-le avant de l'envoyer : c'est toi qui décides ce qui sort de ta machine.

**Cite toujours le numéro de version**, affiché en haut des Paramètres. Un bug
signalé sans version se cherche dans le mauvais code.

## Ce qui est normal en bêta

- Les données d'exemple sont **inventées** : ni les crédits, ni les seuils de
  Roadblock, ni les dates ne sont des chiffres officiels Epitech.
- Certaines règles sont des hypothèses en attente de confirmation. Elles sont
  listées dans le README du projet.
- L'application n'est **pas** affiliée à Epitech et ne remplace pas l'intranet.
