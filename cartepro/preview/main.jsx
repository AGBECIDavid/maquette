/* Point d'entrée du build monofichier : les mêmes écrans que l'application
   Next, avec un routeur par fragment d'URL au lieu du routeur de Next. C'est
   ce qui permet de publier une version cliquable en un seul fichier HTML, sans
   dupliquer une ligne d'interface. */

import { StrictMode, useCallback, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { AppProviders, useMounted } from "../lib/app.jsx";
import { Shell } from "../components/Shell.jsx";
import { Landing } from "../screens/Landing.jsx";
import { Login, Signup } from "../screens/Auth.jsx";
import { EmployeeSpace } from "../screens/Employee.jsx";
import { PartnerSpace } from "../screens/Partner.jsx";
import { AdminSpace } from "../screens/Admin.jsx";

const ROUTES = [
  [/^\/?$/,                      () => <Landing />],
  [/^\/connexion/,               () => <Login />],
  [/^\/inscription/,             p => <Signup initialRole={p.includes("role=partner") ? "partner" : "employee"} />],
  [/^\/salarie\/payer/,          () => <EmployeeSpace section="payer" />],
  [/^\/salarie\/historique/,     () => <EmployeeSpace section="historique" />],
  [/^\/salarie\/partenaires/,    () => <EmployeeSpace section="partenaires" />],
  [/^\/salarie\/demandes/,       () => <EmployeeSpace section="demandes" />],
  [/^\/salarie/,                 () => <EmployeeSpace section="accueil" />],
  [/^\/partenaire\/encaisser/,   () => <PartnerSpace section="encaisser" />],
  [/^\/partenaire\/transactions/,() => <PartnerSpace section="transactions" />],
  [/^\/partenaire\/catalogue/,   () => <PartnerSpace section="catalogue" />],
  [/^\/partenaire\/compte/,      () => <PartnerSpace section="compte" />],
  [/^\/partenaire/,              () => <PartnerSpace section="bord" />],
  [/^\/admin\/validations/,      () => <AdminSpace section="validations" />],
  [/^\/admin\/salaries/,         () => <AdminSpace section="salaries" />],
  [/^\/admin\/reclamations/,     () => <AdminSpace section="reclamations" />],
  [/^\/admin\/comptes/,          () => <AdminSpace section="comptes" />],
  [/^\/admin\/recharges/,        () => <AdminSpace section="recharges" />],
  [/^\/admin\/registre/,         () => <AdminSpace section="registre" />],
  [/^\/admin\/api/,              () => <AdminSpace section="api" />],
  [/^\/admin/,                   () => <AdminSpace section="bord" />]
];

const currentPath = () => (location.hash || "#/").slice(1) || "/";

function App() {
  const mounted = useMounted();
  const [path, setPath] = useState(currentPath);

  useEffect(() => {
    const onHash = () => { setPath(currentPath()); scrollTo({ top: 0 }); };
    addEventListener("hashchange", onHash);
    return () => removeEventListener("hashchange", onHash);
  }, []);

  const push = useCallback(p => { location.hash = "#" + p; }, []);

  if (!mounted) {
    return (
      <div className="splash" data-static="true" role="status" aria-label="Chargement de CartePro">
        <div className="splash__in">
          <div className="splash__mark"><span className="splash__ring" /><span className="splash__tile">CP</span></div>
          <div style={{ textAlign: "center", display: "grid", gap: 6, justifyItems: "center" }}>
            <div className="splash__name">CartePro</div>
            <div className="splash__sub">Ministère du Job et Bonheur</div>
          </div>
          <div className="splash__bar"><i /></div>
        </div>
      </div>
    );
  }

  const hit = ROUTES.find(([re]) => re.test(path)) || ROUTES[0];
  return (
    <AppProviders path={path} push={push}>
      <Shell>{hit[1](path)}</Shell>
    </AppProviders>
  );
}

createRoot(document.getElementById("cartepro-root")).render(<StrictMode><App /></StrictMode>);
