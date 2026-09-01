# Fiche de registre des activités de traitement

**Responsable de traitement** : Ministère du Job et Bonheur, Direction du Numérique et
de l'Innovation.
**Traitement** : CartePro — dispositif de titres d'avantages salariés dématérialisés.
**Référence** : JEB/DNI/2026-002 v2.0. **Établie le** : 1ᵉʳ septembre 2026.
**Statut** : projet, à valider par Mme Pontaillac avant mise en service.

> Le démonstrateur ne conserve aujourd'hui aucune donnée sur un serveur : l'état vit
> dans le navigateur de la personne qui l'utilise. La présente fiche décrit le
> traitement **tel qu'il sera** une fois la base en place, à partir du schéma cible
> (`docs/schema.sql`).

## 1. Finalités et données

| Finalité | Base légale | Personnes concernées | Tables et colonnes |
|---|---|---|---|
| Gestion du compte bénéficiaire | Exécution du contrat de travail / intérêt légitime de l'employeur | Salariés | `salarie` : `id`, `nom`, `courriel`, `mot_de_passe`, `employeur_id`, `statut`, `solde`, `beneficiaire_depuis` |
| Exécution et traçabilité des opérations | Obligation légale de traçabilité comptable | Salariés, partenaires | `ecriture` : `ref`, `nature`, `salarie_id`, `partenaire_id`, `montant`, `canal`, `empreinte*`, `ecrit_le` ; `code_paiement` : `jeton`, `salarie_id`, `emis_le`, `expire_le`, `consomme_le` |
| Créditation par l'employeur | Exécution du contrat | Salariés | `credit` : `salarie_id`, `employeur_id`, `montant`, `nature`, `libelle`, `motif`, `auteur`, `credite_le` |
| Référencement des partenaires | Mission d'intérêt public | Représentants des établissements | `partenaire` : `raison_sociale`, `siren`, `objet_social`, `adresse`, `ville`, `courriel`, `iban`, `statut` |
| Instruction des adhésions | Mission d'intérêt public | Représentants des établissements | `decision` : `cible`, `action`, `statut_*`, `motif`, `agent_id`, `agent_nom`, `prise_le` |
| Traitement des réclamations | Intérêt légitime / obligation de réponse | Salariés, agents | `reclamation`, `reclamation_message` : `corps`, `auteur`, `ecrit_le` |
| Pilotage du dispositif | Mission d'intérêt public | — | Agrégats calculés à la volée, sans stockage nominatif |

## 2. Destinataires

- Agents habilités de la Direction du Numérique et de l'Innovation (instruction,
  gestion des comptes, réclamations).
- L'employeur : **uniquement** le solde et les crédits qu'il a lui-même versés. Il
  n'accède pas au détail des dépenses de ses salariés — c'est la garantie centrale du
  dispositif, et elle est structurelle : aucun point d'entrée ne l'expose.
- Le partenaire : le nom du bénéficiaire au moment de l'encaissement, et rien d'autre.
- Aucun transfert hors Union européenne. Aucun sous-traitant à ce stade.

## 3. Durée de conservation

Treize mois, conformément à la consigne. Traduction retenue :

| Donnée | À 13 mois | Motif |
|---|---|---|
| `reclamation`, `reclamation_message` | **purge** | Aucune valeur au-delà du traitement de la demande |
| `code_paiement` | **purge à 30 jours** | Un code consommé ou expiré n'a plus d'usage ; le conserver 13 mois serait excessif |
| `ecriture` | **anonymisation** : `salarie_id` remplacé par un pseudonyme stable, la ligne et sa chaîne d'empreintes restant intactes | La suppression romprait le chaînage (R1) et détruirait la piste d'audit comptable |
| `salarie` (compte clôturé) | **purge** de `nom`, `courriel`, `mot_de_passe` ; l'identifiant technique subsiste | Le solde et l'historique agrégés restent cohérents sans identifier la personne |
| `decision` | **conservation** : `motif` et `agent_nom` sont la trace d'un acte administratif | Opposabilité de la décision |

**Arbitrage à valider** : l'anonymisation plutôt que la purge des écritures est le seul
moyen de tenir ensemble la durée de conservation et la règle d'immuabilité. Si Mme
Pontaillac préfère une purge, il faut renoncer au chaînage d'empreintes sur les
écritures anciennes, et le dire dans les CGU.

## 4. Données que nous ne collectons pas, et pourquoi

Le tri a été fait dans l'autre sens : partir de ce que le service exige, pas de ce
qu'il serait commode d'avoir.

- **Pas de date de naissance, pas de NIR, pas d'adresse personnelle** : rien dans le
  parcours n'en dépend.
- **Pas de géolocalisation.** L'écran « autour de moi » travaille sur les adresses
  déclarées des partenaires, pas sur la position du salarié.
- **Pas de coordonnées bancaires du salarié** : le dispositif ne verse jamais d'argent
  à une personne physique.
- **Pas de motif d'achat ni de détail d'article** : le partenaire transmet un montant,
  pas un panier.
- **Retiré en cours de conception** : le champ « téléphone » du salarié, présent dans
  une première version de la maquette. Aucune notification n'est envoyée par SMS ; le
  champ n'avait pas de finalité.

## 5. Mesures de sécurité

| Mesure | État |
|---|---|
| Chiffrement des échanges (HTTPS, HSTS) | à activer au déploiement (§5.1) |
| Mots de passe hachés (argon2id) | prévu au schéma, non implémenté dans le démonstrateur |
| Cloisonnement par rôle (salarié / partenaire / agent) | en place, y compris au niveau de l'API |
| Codes de paiement à usage unique, cinq minutes | en place (R4) |
| Écritures inaltérables, chaînées par empreinte | en place (R1) ; en base, garanti par déclencheur |
| Journalisation des décisions administratives | en place (`decision`) |
| Sauvegardes chiffrées, restauration testée | à mettre en place |

## 6. Droits des personnes

Accès, rectification, effacement, limitation, opposition : à exercer auprès du
délégué à la protection des données du Ministère. Le droit à l'effacement s'exerce
dans les limites de la piste d'audit comptable : les écritures sont anonymisées, non
supprimées (§3).

**Point ouvert** : le délégué à la protection des données n'est pas encore désigné pour
ce traitement. La déclaration ne peut pas être publiée sans son nom et son adresse.
