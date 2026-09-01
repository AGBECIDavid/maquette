set -e
[ -f package.json ] && [ -d src/app ] || { echo "✗ À lancer depuis front/"; exit 1; }

# ── Garde-fous : on n'efface rien qui ne soit pas déjà en sécurité ──────────
[ -z "$(git status --porcelain)" ] || { echo "✗ Des modifications ne sont pas commitées. Committez d'abord."; exit 1; }
git diff --quiet @{u} 2>/dev/null || { echo "✗ Votre branche n'est pas poussée. Faites 'git push' d'abord."; exit 1; }
TMPDIR="${TMPDIR:-/tmp}"
sauvegarde="sauvegarde-avant-refonte-$(date +%Y%m%d-%H%M)"
git branch "$sauvegarde"
echo "→ sauvegarde : branche $sauvegarde"

# ── On efface les coquilles, on garde la substance ─────────────────────────
# src/app et src/components ne contiennent que des ébauches ; src/types,
# src/lib, src/styles et src/mocks portent le travail réel — on n'y touche pas.
# Le favicon vit dans src/app chez Next : on le met de côté avant d'effacer.
if [ -f src/app/favicon.ico ]; then cp src/app/favicon.ico "$TMPDIR/favicon-refonte.ico"; fi
git rm -r -q --ignore-unmatch src/app src/components
mkdir -p src/app src/components src/styles
if [ -f "$TMPDIR/favicon-refonte.ico" ]; then mv "$TMPDIR/favicon-refonte.ico" src/app/favicon.ico; fi

# La feuille de style globale est importée par le layout racine : elle doit exister.
[ -s src/styles/tokens.css ] || cat > src/styles/tokens.css <<'EOF'
:root {
  /* Charte de l'État : le bleu institutionnel ne remplit jamais un bouton. */
  --bleu-institutionnel: #1b3a6b;
  --encre: #1b1b1b;
  --encre-secondaire: #636980;
  --fond: #ffffff;
  --fond-doux: #f5f6f8;
  --trait: #d8dbe2;
}
EOF
[ -s src/styles/globals.css ] || cat > src/styles/globals.css <<'EOF'
@import "./tokens.css";

*, *::before, *::after { box-sizing: border-box; }
body {
  margin: 0;
  color: var(--encre);
  background: var(--fond);
  font-family: Spectral, Georgia, serif;
}
EOF

# ── Générateurs ─────────────────────────────────────────────────────────────
composant() {   # composant <chemin.tsx> <Nom>
  [ -s "$1" ] && return 0
  printf 'export function %s() {\n  return null;\n}\n' "$2" > "$1"
}
route() {       # route <dossier> <Import> <chemin/relatif> <Titre>
  cat > "$1/page.tsx" <<EOF
import { $2 } from "$3";

export const metadata = { title: "$4" };

export default function Page() {
  return <$2 />;
}
EOF
}
ecran() {       # ecran <dossier> <Composant> <part1> <part2> …
  local d="$1" c="$2"; shift 2
  mkdir -p "$d"
  composant "$d/$c.tsx" "$c"
  for p in "$@"; do composant "$d/$p.tsx" "$p"; done
}
espace() {      # espace <dossier> <Rail>
  mkdir -p "$1"
  composant "$1/$2.tsx" "$2"
  cat > "$1/layout.tsx" <<EOF
import { $2 } from "./$2";

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className="espace">
      <$2 />
      <main>{children}</main>
    </div>
  );
}
EOF
  cat > "$1/loading.tsx" <<'EOF'
export default function Chargement() {
  return <p role="status">Chargement…</p>;
}
EOF
}

# ── Racine ──────────────────────────────────────────────────────────────────
cat > src/app/layout.tsx <<'EOF'
import "@/styles/globals.css";

export const metadata = {
  title: {
    default: "CartePro (simulation) — Ministère du Job et Bonheur",
    template: "%s — CartePro (simulation)",
  },
  description:
    "Démonstrateur du dispositif CartePro. Simulation fonctionnelle : aucune valeur réelle ne circule.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
EOF
cat > src/app/error.tsx <<'EOF'
"use client";

export default function Erreur({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <section role="alert">
      <h1>Une erreur est survenue</h1>
      <p>{error.message}</p>
      <button type="button" onClick={reset}>
        Réessayer
      </button>
    </section>
  );
}
EOF
cat > src/app/not-found.tsx <<'EOF'
export default function Introuvable() {
  return (
    <section>
      <h1>Page introuvable</h1>
      <p>Cette adresse ne correspond à aucun écran du dispositif.</p>
    </section>
  );
}
EOF
echo "  racine : layout, error (signature complète), not-found"

# ── Espace public ───────────────────────────────────────────────────────────
mkdir -p "src/app/(public)"
composant "src/app/(public)/EnTetePublique.tsx" "EnTetePublique"
composant "src/app/(public)/PiedDePage.tsx" "PiedDePage"
cat > "src/app/(public)/layout.tsx" <<'EOF'
import { EnTetePublique } from "./EnTetePublique";
import { PiedDePage } from "./PiedDePage";

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <EnTetePublique />
      <main>{children}</main>
      <PiedDePage />
    </>
  );
}
EOF
ecran "src/app/(public)/accueil" Accueil Banniere ChoixDuMinistre PartenairesDuLancement CommentCaMarche
route "src/app/(public)" Accueil "./accueil/Accueil" "Accueil"
ecran "src/app/(public)/partenaires" CataloguePublic RecherchePartenaires FiltreCategories ListePartenaires
route "src/app/(public)/partenaires" CataloguePublic "./CataloguePublic" "Partenaires référencés"
ecran "src/app/(public)/cgu" ConditionsGenerales
route "src/app/(public)/cgu" ConditionsGenerales "./ConditionsGenerales" "Conditions générales"
ecran "src/app/(public)/mentions-legales" MentionsLegales
route "src/app/(public)/mentions-legales" MentionsLegales "./MentionsLegales" "Mentions légales"
ecran "src/app/(public)/accessibilite" Accessibilite
route "src/app/(public)/accessibilite" Accessibilite "./Accessibilite" "Accessibilité"

# ── Authentification ────────────────────────────────────────────────────────
mkdir -p "src/app/(auth)"
cat > "src/app/(auth)/layout.tsx" <<'EOF'
export default function Layout({ children }: { children: React.ReactNode }) {
  return <main className="auth">{children}</main>;
}
EOF
ecran "src/app/(auth)/connexion" Connexion FormulaireConnexion ComptesDemonstration
route "src/app/(auth)/connexion" Connexion "./Connexion" "Connexion"
ecran "src/app/(auth)/inscription" Inscription ChoixDuProfil FormulaireSalarie FormulairePartenaire
route "src/app/(auth)/inscription" Inscription "./Inscription" "Créer un compte"

# ── Espace salarié ──────────────────────────────────────────────────────────
espace "src/app/(salarie)/salarie" RailSalarie
ecran "src/app/(salarie)/salarie/budget" Budget CarteSolde ActionsRapides ChoixDuMinistre DernieresOperations
route "src/app/(salarie)/salarie" Budget "./budget/Budget" "Mon budget"
ecran "src/app/(salarie)/salarie/paiement" Paiement CodeAffiche MinuteurValidite NumeroJeton PaiementAccepte
route "src/app/(salarie)/salarie/paiement" Paiement "./Paiement" "Payer"
ecran "src/app/(salarie)/salarie/historique" Historique FiltreMois ListeOperations DetailOperation
route "src/app/(salarie)/salarie/historique" Historique "./Historique" "Historique"
ecran "src/app/(salarie)/salarie/partenaires" PartenairesSalarie RecherchePartenaires FiltreCategories PlanPartenaires ListeResultats
route "src/app/(salarie)/salarie/partenaires" PartenairesSalarie "./PartenairesSalarie" "Partenaires"
ecran "src/app/(salarie)/salarie/demandes" Demandes ListeDemandes FormulaireDemande
route "src/app/(salarie)/salarie/demandes" Demandes "./Demandes" "Mes demandes"
ecran "src/app/(salarie)/salarie/demandes/[id]" FilDemande MessageDemande ReponseSalarie
route "src/app/(salarie)/salarie/demandes/[id]" FilDemande "./FilDemande" "Demande"

# ── Espace partenaire ───────────────────────────────────────────────────────
espace "src/app/(partenaire)/partenaire" RailPartenaire
# L'adhésion refusée n'est pas une URL : c'est un état du compte, porté par le layout.
composant "src/app/(partenaire)/partenaire/AdhesionRefusee.tsx" AdhesionRefusee
ecran "src/app/(partenaire)/partenaire/tableau-de-bord" TableauDeBordPartenaire TuilesRecettes GraphiqueQuatorzeJours DerniersEncaissements
route "src/app/(partenaire)/partenaire" TableauDeBordPartenaire "./tableau-de-bord/TableauDeBordPartenaire" "Tableau de bord"
ecran "src/app/(partenaire)/partenaire/encaissement" Encaissement EtapeJeton SaisieManuelle EtapeMontant FileAttente ModeEmploi
route "src/app/(partenaire)/partenaire/encaissement" Encaissement "./Encaissement" "Encaisser"
ecran "src/app/(partenaire)/partenaire/transactions" TransactionsPartenaire FiltrePeriode TableauEncaissements ExportCsv
route "src/app/(partenaire)/partenaire/transactions" TransactionsPartenaire "./TransactionsPartenaire" "Transactions"
ecran "src/app/(partenaire)/partenaire/catalogue" CataloguePartenaire RechercheCatalogue TableauCatalogue
route "src/app/(partenaire)/partenaire/catalogue" CataloguePartenaire "./CataloguePartenaire" "Catalogue"
ecran "src/app/(partenaire)/partenaire/compte" ComptePartenaire FicheEtablissement CarteSceau Reversements
route "src/app/(partenaire)/partenaire/compte" ComptePartenaire "./ComptePartenaire" "Mon compte"
ecran "src/app/(partenaire)/partenaire/inscription" InscriptionPartenaire FormulaireAdhesion RecapitulatifDemande
route "src/app/(partenaire)/partenaire/inscription" InscriptionPartenaire "./InscriptionPartenaire" "Demande d'adhésion"

# ── Espace administration ───────────────────────────────────────────────────
espace "src/app/(administration)/administration" RailAdministration
ecran "src/app/(administration)/administration/tableau-de-bord" TableauDeBordNational ChiffreCle TuilesNationales BandeauFlux VolumeHebdomadaire RepartitionGeographique RepartitionCategories
route "src/app/(administration)/administration" TableauDeBordNational "./tableau-de-bord/TableauDeBordNational" "Tableau de bord national"
ecran "src/app/(administration)/administration/validations" Validations CarteDemande DialogueRefus JournalDecisions
route "src/app/(administration)/administration/validations" Validations "./Validations" "Validations d'adhésion"
ecran "src/app/(administration)/administration/mise-en-avant" MiseEnAvant CarteMiseEnAvant TableauBascule DialogueMotMinistre
route "src/app/(administration)/administration/mise-en-avant" MiseEnAvant "./MiseEnAvant" "Sélection du Ministre"
ecran "src/app/(administration)/administration/salaries" Salaries RechercheSalaries TableauSalaries
route "src/app/(administration)/administration/salaries" Salaries "./Salaries" "Salariés bénéficiaires"
ecran "src/app/(administration)/administration/salaries/[id]" FicheSalarie SoldeEtCredits OperationsSalarie DialogueRegularisation DialogueStatut
route "src/app/(administration)/administration/salaries/[id]" FicheSalarie "./FicheSalarie" "Fiche salarié"
ecran "src/app/(administration)/administration/reclamations" Reclamations FiltreStatut FileReclamations
route "src/app/(administration)/administration/reclamations" Reclamations "./Reclamations" "Réclamations"
ecran "src/app/(administration)/administration/reclamations/[id]" FilReclamation FilMessages DossierBeneficiaire OperationVisee DialogueCloture
route "src/app/(administration)/administration/reclamations/[id]" FilReclamation "./FilReclamation" "Réclamation"
ecran "src/app/(administration)/administration/comptes" Comptes TableauPartenaires DialogueMotif
route "src/app/(administration)/administration/comptes" Comptes "./Comptes" "Comptes partenaires"
ecran "src/app/(administration)/administration/recharges" Recharges FormulaireRechargement ListeBeneficiaires DerniersMouvements
route "src/app/(administration)/administration/recharges" Recharges "./Recharges" "Rechargements"
ecran "src/app/(administration)/administration/registre" Registre ControleIntegrite TableauEcritures DialogueAnnulation
route "src/app/(administration)/administration/registre" Registre "./Registre" "Registre des transactions"
ecran "src/app/(administration)/administration/transactions" TransactionsNationales FiltresTransactions TableauNational
route "src/app/(administration)/administration/transactions" TransactionsNationales "./TransactionsNationales" "Transactions"
ecran "src/app/(administration)/administration/api" DocumentationApi TableauEndpoints ExempleAppel
route "src/app/(administration)/administration/api" DocumentationApi "./DocumentationApi" "API"

# ── Composants réellement partagés (deux espaces ou plus) ──────────────────
mkdir -p src/components/{ui,simulation,graphiques,formulaires}
for c in Bouton Carte Pastille Tableau Pagination Champ Fenetre EtatVide EtatErreur Chargement Icone Note; do
  composant "src/components/ui/$c.tsx" "$c"; done
for c in Montant MentionSimulation BandeauSimulation; do
  composant "src/components/simulation/$c.tsx" "$c"; done
for c in Colonnes BarresHorizontales Sparkline TuileStat; do
  composant "src/components/graphiques/$c.tsx" "$c"; done
for c in ChampMontant ChampSiren FormulaireMotif BoutonCopier; do
  composant "src/components/formulaires/$c.tsx" "$c"; done

echo
echo "✓ Refonte terminée"
echo "  écrans     : $(find src/app -name 'page.tsx' | wc -l) routes"
echo "  composants : $(find src/app src/components -name '*.tsx' ! -name 'page.tsx' ! -name 'layout.tsx' ! -name 'loading.tsx' | wc -l)"
echo "  sauvegarde : branche $sauvegarde"
