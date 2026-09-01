-- ============================================================================
-- CartePro — schéma de base de données cible (PostgreSQL 16)
-- Référence JEB/DNI/2026-002 v2.0
--
-- Ce fichier est le schéma VISÉ. Le démonstrateur n'a pas encore de base : son
-- état vit dans le navigateur. Le livrable « schéma généré depuis la base
-- réelle » attendu au §8 ne pourra être produit qu'une fois la migration jouée
-- sur une instance ; ce fichier en est la source.
--
-- Les montants sont des entiers, en centimes. Aucun type flottant n'apparaît
-- dans une somme d'argent.
-- ============================================================================

CREATE TYPE compte_statut  AS ENUM ('active', 'pending', 'suspended', 'closed', 'rejected');
CREATE TYPE ecriture_nature AS ENUM ('payment', 'reversal');
CREATE TYPE reclamation_statut AS ENUM ('open', 'in_progress', 'resolved', 'rejected');

-- ── Référentiels ───────────────────────────────────────────────────────────

-- §6.3 : les catégories sont une table. En ajouter ou en retirer ne touche
-- aucune ligne d'interface.
CREATE TABLE categorie (
  id           text PRIMARY KEY,
  libelle      text NOT NULL,
  icone        text NOT NULL DEFAULT 'store',
  rang         int  NOT NULL DEFAULT 0
);

CREATE TABLE employeur (
  id           text PRIMARY KEY,
  raison_sociale text NOT NULL,
  siret        text NOT NULL,
  code_adhesion text NOT NULL UNIQUE,      -- remis aux salariés à l'inscription
  effectif     int  NOT NULL DEFAULT 0,
  contact      text,
  cree_le      timestamptz NOT NULL DEFAULT now()
);

-- ── Comptes ────────────────────────────────────────────────────────────────

CREATE TABLE salarie (
  id           text PRIMARY KEY,
  nom          text NOT NULL,
  courriel     citext NOT NULL UNIQUE,
  mot_de_passe text NOT NULL,              -- argon2id, jamais en clair
  employeur_id text NOT NULL REFERENCES employeur(id) ON DELETE RESTRICT,
  statut       compte_statut NOT NULL DEFAULT 'active',
  solde        bigint NOT NULL DEFAULT 0,
  beneficiaire_depuis date NOT NULL DEFAULT CURRENT_DATE,
  cree_le      timestamptz NOT NULL DEFAULT now(),
  -- R2 : dernière défense contre un solde négatif, même si la logique
  -- applicative se trompe (voir docs/note-concurrence.md).
  CONSTRAINT solde_positif CHECK (solde >= 0)
);
CREATE INDEX salarie_employeur_idx ON salarie (employeur_id);

CREATE TABLE partenaire (
  id           text PRIMARY KEY,
  raison_sociale text NOT NULL,
  siren        char(9) NOT NULL,           -- neuf chiffres, clé de Luhn vérifiée
  objet_social text NOT NULL,
  categorie_id text NOT NULL REFERENCES categorie(id) ON DELETE RESTRICT,
  adresse      text,
  ville        text NOT NULL,
  region       text NOT NULL,
  canal        text NOT NULL DEFAULT 'Sur place',
  courriel     citext NOT NULL UNIQUE,
  mot_de_passe text NOT NULL,
  iban         text,
  statut       compte_statut NOT NULL DEFAULT 'pending',
  -- « Choix du Ministre » : mise en avant pilotée depuis l'espace admin.
  mis_en_avant boolean NOT NULL DEFAULT false,
  mot_du_ministre text,
  cree_le      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT siren_neuf_chiffres CHECK (siren ~ '^[0-9]{9}$')
);
CREATE INDEX partenaire_statut_idx     ON partenaire (statut);
CREATE INDEX partenaire_categorie_idx  ON partenaire (categorie_id);
CREATE INDEX partenaire_avant_idx      ON partenaire (mis_en_avant) WHERE mis_en_avant;

CREATE TABLE agent (
  id           text PRIMARY KEY,
  nom          text NOT NULL,
  courriel     citext NOT NULL UNIQUE,
  mot_de_passe text NOT NULL,
  fonction     text NOT NULL,
  ministre     boolean NOT NULL DEFAULT false
);

-- ── Codes de paiement (R4) ─────────────────────────────────────────────────

CREATE TABLE code_paiement (
  jeton        text PRIMARY KEY,           -- signé côté serveur
  salarie_id   text NOT NULL REFERENCES salarie(id) ON DELETE CASCADE,
  emis_le      timestamptz NOT NULL DEFAULT now(),
  expire_le    timestamptz NOT NULL,       -- emis_le + 5 minutes
  consomme_le  timestamptz,                -- usage unique
  CONSTRAINT validite_bornee CHECK (expire_le > emis_le AND expire_le <= emis_le + interval '5 minutes')
);
CREATE INDEX code_salarie_idx ON code_paiement (salarie_id, expire_le DESC);

-- ── Registre des écritures (R1) ────────────────────────────────────────────
-- Aucune colonne n'est modifiable après insertion : le déclencheur ci-dessous
-- rejette tout UPDATE et tout DELETE. Une correction se fait par une écriture
-- de nature 'reversal' rattachée à celle qu'elle compense.

CREATE TABLE ecriture (
  ref          text PRIMARY KEY,
  nature       ecriture_nature NOT NULL DEFAULT 'payment',
  salarie_id   text NOT NULL REFERENCES salarie(id) ON DELETE RESTRICT,
  partenaire_id text NOT NULL REFERENCES partenaire(id) ON DELETE RESTRICT,
  montant      bigint NOT NULL CHECK (montant > 0),
  canal        text NOT NULL DEFAULT 'qr',
  compense     text REFERENCES ecriture(ref),   -- renseigné si nature = 'reversal'
  motif        text,                            -- motif de l'annulation
  empreinte_precedente char(8) NOT NULL,
  empreinte    char(8) NOT NULL,
  ecrit_le     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ecriture_salarie_idx    ON ecriture (salarie_id, ecrit_le DESC);
CREATE INDEX ecriture_partenaire_idx ON ecriture (partenaire_id, ecrit_le DESC);
CREATE UNIQUE INDEX ecriture_compense_idx ON ecriture (compense) WHERE compense IS NOT NULL;

CREATE OR REPLACE FUNCTION ecriture_immuable() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'R1 : une écriture validée ne peut être ni modifiée ni supprimée (ref %)',
    COALESCE(OLD.ref, NEW.ref);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ecriture_pas_de_update BEFORE UPDATE ON ecriture
  FOR EACH ROW EXECUTE FUNCTION ecriture_immuable();
CREATE TRIGGER ecriture_pas_de_delete BEFORE DELETE ON ecriture
  FOR EACH ROW EXECUTE FUNCTION ecriture_immuable();

-- R3 : l'idempotence est une contrainte d'unicité, pas une vérification
-- applicative — deux requêtes concurrentes portant la même clé ne peuvent pas
-- créer deux écritures.
CREATE TABLE idempotence (
  cle          text PRIMARY KEY,
  ecriture_ref text NOT NULL REFERENCES ecriture(ref),
  cree_le      timestamptz NOT NULL DEFAULT now()
);

-- ── Crédits ────────────────────────────────────────────────────────────────

CREATE TABLE credit (
  id           text PRIMARY KEY,
  salarie_id   text NOT NULL REFERENCES salarie(id) ON DELETE RESTRICT,
  employeur_id text REFERENCES employeur(id) ON DELETE SET NULL,
  montant      bigint NOT NULL CHECK (montant > 0),
  nature       text NOT NULL DEFAULT 'dotation',  -- 'dotation' | 'regularisation'
  libelle      text NOT NULL,
  motif        text,
  auteur       text NOT NULL,
  credite_le   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX credit_salarie_idx ON credit (salarie_id, credite_le DESC);

-- ── Décisions administratives ──────────────────────────────────────────────
-- Toute décision est horodatée, porte l'identifiant de l'agent et son motif.

CREATE TABLE decision (
  id           bigserial PRIMARY KEY,
  cible        text NOT NULL,              -- identifiant partenaire ou salarié
  action       text NOT NULL,              -- 'status' | 'featured' | 'cancel' | 'claim'
  statut_avant text,
  statut_apres text,
  motif        text,
  agent_id     text REFERENCES agent(id),
  agent_nom    text NOT NULL,
  prise_le     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT motif_obligatoire CHECK (
    statut_apres NOT IN ('rejected', 'suspended', 'closed')
    OR (motif IS NOT NULL AND length(btrim(motif)) >= 10)
  )
);
CREATE INDEX decision_cible_idx ON decision (cible, prise_le DESC);

-- ── Réclamations ───────────────────────────────────────────────────────────

CREATE TABLE reclamation (
  id           text PRIMARY KEY,
  salarie_id   text NOT NULL REFERENCES salarie(id) ON DELETE CASCADE,
  categorie    text NOT NULL,
  objet        text NOT NULL,
  ecriture_ref text REFERENCES ecriture(ref),
  statut       reclamation_statut NOT NULL DEFAULT 'open',
  ouverte_le   timestamptz NOT NULL DEFAULT now(),
  maj_le       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX reclamation_statut_idx ON reclamation (statut, maj_le DESC);

CREATE TABLE reclamation_message (
  id           bigserial PRIMARY KEY,
  reclamation_id text NOT NULL REFERENCES reclamation(id) ON DELETE CASCADE,
  emetteur     text NOT NULL,              -- 'employee' | 'admin'
  auteur       text NOT NULL,
  corps        text NOT NULL,
  ecrit_le     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX reclamation_message_idx ON reclamation_message (reclamation_id, ecrit_le);

-- ── Cardinalités ───────────────────────────────────────────────────────────
--   employeur 1 ──< n salarie
--   categorie 1 ──< n partenaire
--   salarie   1 ──< n code_paiement
--   salarie   1 ──< n ecriture        partenaire 1 ──< n ecriture
--   ecriture  1 ──0..1 ecriture       (une écriture compense au plus une autre)
--   salarie   1 ──< n credit          salarie    1 ──< n reclamation
--   reclamation 1 ──< n reclamation_message
--   agent     1 ──< n decision
