"use client";
/* Connexion et inscription. Deux portes distinctes, un même cadre. */

import { useEffect, useState } from "react";
import { Icon } from "../lib/icons.jsx";
import { useNav, useApi, useToast, useDB } from "../lib/app.jsx";
import { usePageTitle } from "../components/ui.jsx";
import { REGIONS } from "../lib/data.js";

const HOME = { employee: "/salarie", partner: "/partenaire", admin: "/admin" };

function Side({ title, lead, points }) {
  return (
    <div className="auth__side">
      <h2>{title}</h2>
      <p>{lead}</p>
      <div className="auth__list">
        {points.map(p => (
          <div key={p}><Icon name="check" /><span>{p}</span></div>
        ))}
      </div>
    </div>
  );
}

export function Login() {
  usePageTitle("Connexion");
  const { push } = useNav();
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async e => {
    e.preventDefault();
    if (!email.trim()) { toast("bad", "Adresse manquante", "Saisissez votre adresse électronique."); return; }
    setBusy(true);
    try {
      const s = await api.post("/auth/login", { email, password });
      toast("good", "Bienvenue " + s.name.split(" ")[0], "Session ouverte.");
      push(HOME[s.role]);
    } catch (err) { /* le message est déjà affiché */ }
    finally { setBusy(false); }
  };

  const comptes = [
    ["Salariée", db.employees[0].name, db.employees[0].email],
    ["Partenaire", db.partners[0].name, db.partners[0].contact],
    ["Agent du Ministère", db.admins[0].name, db.admins[0].email]
  ];

  return (
    <div className="auth">
      <Side
        title="Votre budget CartePro, où que vous soyez."
        lead="Une seule adresse, trois espaces : salarié, partenaire, administration. La plateforme reconnaît votre profil et vous ouvre le bon tableau de bord."
        points={["Solde et historique en temps réel",
                 "QR code de paiement à usage unique",
                 "Réclamation traitée directement par un agent",
                 "Aucune donnée bancaire demandée"]}
      />
      <div className="auth__form">
        <form className="auth__box" onSubmit={submit}>
          <h1>Connexion</h1>
          <p className="sub">Accédez à votre espace CartePro.</p>

          <label className="field">
            <span className="field__lb">Adresse électronique</span>
            <input className="input" type="email" autoComplete="username" value={email}
                   onChange={e => setEmail(e.target.value)} placeholder="prenom.nom@exemple.fr" />
          </label>
          <label className="field">
            <span className="field__lb">Mot de passe</span>
            <input className="input" type="password" autoComplete="current-password" value={password}
                   onChange={e => setPassword(e.target.value)} placeholder="••••••••" />
            <span className="field__hint">
              Démonstrateur : le mot de passe n&apos;est pas vérifié, seule l&apos;adresse identifie le compte.
            </span>
          </label>

          <button className="btn btn--primary btn--lg btn--block" type="submit" disabled={busy}>
            {busy ? "Connexion…" : "Se connecter"}
          </button>

          <div className="demoaccounts">
            <b>Comptes de démonstration</b>
            <div style={{ marginTop: 8 }}>
              {comptes.map(([role, name, mail]) => (
                <button key={mail} type="button" onClick={() => setEmail(mail)}>
                  <Icon name="user" />
                  <span><b>{name}</b> <span style={{ color: "var(--ink-4)" }}>· {role}</span></span>
                  <span className="mail">{mail}</span>
                </button>
              ))}
            </div>
          </div>

          <p className="auth__alt">
            Pas encore de compte ?{" "}
            <a href="#" onClick={e => { e.preventDefault(); push("/inscription"); }}>Créer un compte</a>
          </p>
        </form>
      </div>
    </div>
  );
}

export function Signup({ initialRole }) {
  usePageTitle("Créer un compte");
  const { push } = useNav();
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const [role, setRole] = useState(initialRole === "partner" ? "partner" : "employee");
  const [cats, setCats] = useState([]);
  const [f, setF] = useState({ name: "", email: "", password: "", code: "",
                               category: "", region: REGIONS[0],
                               address: "", city: "", siren: "", objetSocial: "" });

  useEffect(() => {
    let alive = true;
    api.get("/categories").then(r => {
      if (!alive) return;
      setCats(r.items);
      setF(v => (v.category ? v : { ...v, category: r.items[0] ? r.items[0].id : "" }));
    }).catch(() => {});
    return () => { alive = false; };
  }, [api]);
  const [busy, setBusy] = useState(false);
  const set = k => e => setF(v => ({ ...v, [k]: e.target.value }));

  const submit = async e => {
    e.preventDefault();
    if (!f.name.trim() || !f.email.trim()) {
      toast("bad", "Formulaire incomplet", "Le nom et l'adresse électronique sont obligatoires.");
      return;
    }
    if (role === "partner") {
      if (!/^\d{9}$/.test(f.siren.replace(/\s/g, ""))) {
        toast("bad", "SIREN invalide", "Neuf chiffres attendus, sans lettre ni séparateur.");
        return;
      }
      if (f.objetSocial.trim().length < 10) {
        toast("bad", "Objet social manquant", "Décrivez l'activité de l'établissement.");
        return;
      }
    }
    setBusy(true);
    try {
      const r = await api.post("/auth/register", { role, ...f });
      if (role === "employee") {
        toast("good", "Compte créé", "Vous êtes rattaché à " + r.employer + ".");
        push("/salarie");
      } else {
        toast("good", "Demande transmise", "Elle sera instruite par l'administration avant activation.");
        push("/partenaire");
      }
    } catch (err) { /* message déjà affiché */ }
    finally { setBusy(false); }
  };

  return (
    <div className="auth">
      <Side
        title={role === "employee" ? "Rejoignez le dispositif en deux minutes."
                                   : "Devenez partenaire référencé."}
        lead={role === "employee"
          ? "Votre employeur vous a remis un code d'adhésion. Il rattache votre compte à son organisation et déclenche vos dotations."
          : "L'adhésion au réseau CartePro est gratuite. Votre dossier est instruit manuellement par la Direction du Numérique et de l'Innovation avant activation."}
        points={role === "employee"
          ? ["Solde crédité par votre employeur",
             "Paiement par QR code chez tous les partenaires",
             "Historique complet et réclamations en ligne",
             "Aucune donnée bancaire demandée"]
          : ["Encaissement par scan ou saisie manuelle",
             "Tableau de bord des recettes et reversements",
             "Présence au catalogue national",
             "Validation manuelle sous 72 heures ouvrées"]}
      />
      <div className="auth__form">
        <form className="auth__box" onSubmit={submit}>
          <h1>Créer un compte</h1>
          <p className="sub">Choisissez le profil qui vous correspond.</p>

          <div className="rolepick" role="group" aria-label="Type de compte">
            <button type="button" aria-pressed={role === "employee"} onClick={() => setRole("employee")}>
              <b>Salarié</b><span>J&apos;ai un code employeur</span>
            </button>
            <button type="button" aria-pressed={role === "partner"} onClick={() => setRole("partner")}>
              <b>Partenaire</b><span>Je suis un commerçant</span>
            </button>
          </div>

          <label className="field">
            <span className="field__lb">{role === "employee" ? "Nom et prénom" : "Raison sociale"}</span>
            <input className="input" value={f.name} onChange={set("name")}
                   placeholder={role === "employee" ? "Amina Berthier" : "Boulangerie du Marché"} />
          </label>

          <label className="field">
            <span className="field__lb">Adresse électronique</span>
            <input className="input" type="email" value={f.email} onChange={set("email")}
                   placeholder={role === "employee" ? "prenom.nom@entreprise.fr" : "contact@etablissement.fr"} />
          </label>

          <label className="field">
            <span className="field__lb">Mot de passe</span>
            <input className="input" type="password" value={f.password} onChange={set("password")}
                   placeholder="8 caractères minimum" />
          </label>

          {role === "employee" ? (
            <label className="field">
              <span className="field__lb">Code employeur</span>
              <input className="input mono" value={f.code} onChange={set("code")} placeholder="VALLONIS-2026" />
              <span className="field__hint">
                Codes de démonstration : {db.employers.map(e => e.code).join(" · ")}
              </span>
            </label>
          ) : (
            <>
              <div className="grid g-2" style={{ gap: 12 }}>
                <label className="field">
                  <span className="field__lb">Catégorie</span>
                  <select className="select" value={f.category} onChange={set("category")}>
                    {cats.map(c => <option key={c.id} value={c.id}>{c.label}</option>)}
                  </select>
                </label>
                <label className="field">
                  <span className="field__lb">Région</span>
                  <select className="select" value={f.region} onChange={set("region")}>
                    {REGIONS.map(r => <option key={r}>{r}</option>)}
                  </select>
                </label>
              </div>
              <div className="grid g-2" style={{ gap: 12 }}>
                <label className="field">
                  <span className="field__lb">Adresse</span>
                  <input className="input" value={f.address} onChange={set("address")} placeholder="12 rue…" />
                </label>
                <label className="field">
                  <span className="field__lb">Ville</span>
                  <input className="input" value={f.city} onChange={set("city")} placeholder="Paris" />
                </label>
              </div>
              <label className="field">
                <span className="field__lb">SIREN</span>
                <input className="input mono" value={f.siren} onChange={set("siren")}
                       inputMode="numeric" maxLength={11} placeholder="404 833 048" />
                <span className="field__hint">
                  Neuf chiffres. La clé de contrôle est vérifiée à la saisie ; l&apos;existence au
                  répertoire Sirene sera vérifiée à l&apos;instruction.
                </span>
              </label>
              <label className="field">
                <span className="field__lb">Objet social</span>
                <textarea className="textarea" value={f.objetSocial} onChange={set("objetSocial")}
                          style={{ minHeight: 70 }}
                          placeholder="Activité déclarée de l'établissement, telle qu'elle figure au registre." />
                <span className="field__hint">
                  Il conditionne l&apos;éligibilité au dispositif : il est lu à l&apos;instruction.
                </span>
              </label>
            </>
          )}

          <button className="btn btn--primary btn--lg btn--block" type="submit" disabled={busy}>
            {busy ? "Envoi…" : role === "employee" ? "Créer mon compte" : "Transmettre la demande"}
          </button>

          <p className="auth__alt">
            Déjà inscrit ?{" "}
            <a href="#" onClick={e => { e.preventDefault(); push("/connexion"); }}>Se connecter</a>
          </p>
        </form>
      </div>
    </div>
  );
}
