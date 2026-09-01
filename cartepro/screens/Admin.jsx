"use client";
/* Espace administration : pilotage national, instruction des adhésions,
   gestion des comptes salariés et traitement des réclamations. */

import { useEffect, useMemo, useState } from "react";
import { Icon } from "../lib/icons.jsx";
import { eur, eurShort, nfr, dateFR, ilYA, centimes, initiales } from "../lib/format.js";
import { catLabel, catIco, STATUS, CLAIM_STATUS, CLAIM_CATEGORIES, REGIONS } from "../lib/data.js";
import { useApi, useToast, useDB, useSession, useNav, useModal } from "../lib/app.jsx";
import { Pager, Note, Empty, StatTile, ColumnChart, BarList, Pill, Sparkline, Sim, SimBar, usePageTitle } from "../components/ui.jsx";
import { Fil, OfficialBadge } from "./Employee.jsx";

const SECTIONS = [
  ["bord",         "chart",  "Tableau de bord",  "/admin"],
  ["validations",  "shield", "Validations",      "/admin/validations"],
  ["vitrine",      "spark",  "Choix du Ministre","/admin/vitrine"],
  ["salaries",     "users",  "Salariés",         "/admin/salaries"],
  ["reclamations", "chat",   "Réclamations",     "/admin/reclamations"],
  ["comptes",      "store",  "Comptes partenaires", "/admin/comptes"],
  ["recharges",    "wallet", "Rechargements",    "/admin/recharges"],
  ["registre",     "lock",   "Registre",         "/admin/registre"],
  ["api",          "key",    "API",              "/admin/api"]
];

export function AdminSpace({ section = "bord" }) {
  const session = useSession();
  const { push } = useNav();
  const db = useDB();

  if (!session || session.role !== "admin") {
    return (
      <div className="stage stage--narrow" style={{ paddingTop: 60 }}>
        <div className="card"><div className="card__bd" style={{ textAlign: "center" }}>
          <h2 style={{ marginBottom: 8 }}>Espace réservé aux agents</h2>
          <p style={{ color: "var(--ink-3)", marginBottom: 18 }}>
            Connectez-vous avec un compte de la Direction du Numérique et de l&apos;Innovation.
          </p>
          <button className="btn btn--primary" type="button" onClick={() => push("/connexion")}>
            Se connecter
          </button>
        </div></div>
      </div>
    );
  }

  const pend = db.partners.filter(p => p.status === "pending").length;
  const claims = db.claims.filter(c => c.status === "open" || c.status === "in_progress").length;

  return (
    <div className="workspace">
      <aside className="rail">
        <div className="rail__group">
          <p className="rail__label">Administration</p>
          {SECTIONS.map(([id, ico, label, href]) => (
            <button key={id} className="navitem" type="button" onClick={() => push(href)}
                    aria-current={section === id ? "true" : undefined}>
              <span className="navitem__ico"><Icon name={ico} /></span>{label}
              {id === "validations" && pend ? <span className="navitem__badge">{pend}</span> : null}
              {id === "reclamations" && claims ? <span className="navitem__badge">{claims}</span> : null}
            </button>
          ))}
        </div>
      </aside>
      <div className="stage">
        {section === "bord" ? <Bord />
          : section === "validations" ? <Validations agent={session.who} />
          : section === "vitrine" ? <Vitrine agent={session.who} />
          : section === "salaries" ? <Salaries agent={session.who} />
          : section === "reclamations" ? <Reclamations agent={session.who} />
          : section === "comptes" ? <Comptes agent={session.who} />
          : section === "recharges" ? <Recharges agent={session.who} />
          : section === "registre" ? <Registre agent={session.who} />
          : <ApiView />}
      </div>
    </div>
  );
}

/* ---- Tableau de bord national --------------------------------------------- */
function Bord() {
  usePageTitle("Tableau de bord national");
  const api = useApi();
  const db = useDB();
  const [s, setS] = useState(null);
  const [table, setTable] = useState(false);

  useEffect(() => {
    let alive = true;
    api.get("/admin/stats").then(r => { if (alive) setS(r); }).catch(() => {});
    return () => { alive = false; };
  }, [api, db.txns.length, db.partners.length]);

  const now = Date.now();
  const weeks = useMemo(() => {
    const out = [];
    for (let i = 11; i >= 0; i--) {
      const end = now - i * 7 * 864e5, start = end - 7 * 864e5;
      const rows = db.txns.filter(t => t.at >= start && t.at < end);
      const d = new Date(start);
      out.push({ label: "Semaine du " + dateFR(start), count: rows.length,
                 value: rows.reduce((a, t) => a + t.amount, 0),
                 tick: i % 2 === 0 ? d.getDate() + "/" + (d.getMonth() + 1) : "" });
    }
    return out;
  }, [db.txns, now]);

  if (!s) return <div className="empty">Chargement des indicateurs…</div>;

  const regions = Object.entries(s.byRegion).sort((a, b) => b[1] - a[1])
    .map(([label, value]) => ({ label, value }));
  const cats = Object.entries(s.byCategory).sort((a, b) => b[1] - a[1])
    .map(([id, value]) => ({ label: catLabel(id), value }));
  const evol = s.volume30prev ? Math.round((s.volume30 - s.volume30prev) / s.volume30prev * 100) : 0;

  const recent = db.txns.slice(-14).reverse().map(t => {
    const p = db.partners.find(x => x.id === t.partnerId);
    return (
      <span className="ticker__i" key={t.ref}>
        <span className="dot" />
        <span className="mono" style={{ color: "var(--ink-4)" }}>{t.ref}</span>
        {p ? p.name : "—"}
        <span className="amt">{eur(t.amount)}</span>
        <span style={{ color: "var(--ink-4)" }}>{p ? p.city : ""}</span>
      </span>
    );
  });

  return (
    <>
      <div className="pagehead">
        <div><h1>Tableau de bord national</h1>
          <p>Volumétrie du dispositif CartePro, tous employeurs et tous partenaires confondus.</p></div>
        <div className="pagehead__act">
          <Pill kind="info">Données au {dateFR(Date.now(), true)}</Pill>
        </div>
      </div>

      <SimBar>
        <b>Volumétrie de simulation.</b> Les montants agrégés ci-dessous proviennent d&apos;un jeu
        de démonstration ; ils ne représentent aucun flux financier réel.
      </SimBar>

      <div className="grid g-main" style={{ marginBottom: 16 }}>
        <section className="card"><div className="card__bd"
          style={{ display: "flex", gap: 28, alignItems: "flex-end", flexWrap: "wrap" }}>
          <div>
            <div className="stat__lb">Volume échangé depuis l&apos;ouverture <Sim /></div>
            <div className="hero-fig num">{eur(s.volume, { maximumFractionDigits: 0 })}</div>
            <div className={"stat__d stat__d--" + (evol >= 0 ? "up" : "down")}>
              <Icon name={evol >= 0 ? "up" : "down"} />
              <b>{evol >= 0 ? "+" : ""}{evol} %</b> sur 30 jours glissants
            </div>
          </div>
          <div style={{ flex: 1, minWidth: 220 }}>
            <Sparkline values={weeks.map(w => w.value / 100)} />
          </div>
        </div></section>
        <StatTile label="Transactions" value={nfr(s.count)} note={nfr(s.count30) + " sur 30 jours"} />
      </div>

      <div className="grid g-4" style={{ marginBottom: 16 }}>
        <StatTile label="Partenaires actifs" value={nfr(s.partnersActive)}
                  note={s.partnersPending ? s.partnersPending + " demande(s) en attente" : "Aucune demande en attente"} />
        <StatTile label="Salariés bénéficiaires" value={nfr(s.employees)}
                  note={s.employeesSuspended ? s.employeesSuspended + " compte(s) non actif(s)" : "Tous les comptes sont actifs"} />
        <StatTile label="Encours non dépensé" value={eur(s.outstanding)} note="Solde cumulé des bénéficiaires" />
        <StatTile label="Réclamations ouvertes" value={nfr(s.claimsOpen)}
                  note={s.reversals ? s.reversals + " annulation(s) au registre" : "Aucune annulation"} />
      </div>

      <div className="ticker" tabIndex={0} aria-label="Dernières transactions enregistrées">
        <span className="ticker__lb">Flux des encaissements</span>
        <div className="ticker__win"><div className="ticker__track">{recent}{recent}</div></div>
      </div>

      <div className="grid g-main" style={{ marginTop: 16 }}>
        <section className="card">
          <div className="card__hd"><h3>Volume hebdomadaire</h3>
            <span className="sub">12 dernières semaines</span>
            <span className="act">
              <button className="btn btn--ghost" type="button" onClick={() => setTable(v => !v)}>
                {table ? "Voir le graphique" : "Voir les données"}
              </button>
            </span>
          </div>
          <div className="card__bd">
            {table ? (
              <div className="tblwrap"><table className="tbl">
                <thead><tr><th>Semaine</th><th className="r">Transactions</th><th className="r">Volume</th></tr></thead>
                <tbody>{weeks.map(w => (
                  <tr key={w.label}><td>{w.label}</td>
                    <td className="r num">{w.count}</td><td className="r num">{eur(w.value)}</td></tr>
                ))}</tbody>
              </table></div>
            ) : (
              <ColumnChart rows={weeks} height={220} fmtTick={eurShort} fmtPeak={r => eurShort(r.value)}
                aria="Volume hebdomadaire des transactions"
                tip={r => `${r.label}\n${eur(r.value)} · ${r.count} transactions`} />
            )}
          </div>
        </section>
        <section className="card">
          <div className="card__hd"><h3>Répartition géographique</h3><span className="sub">volume par région</span></div>
          <div className="card__bd"><BarList rows={regions} fmt={eurShort} /></div>
          <div className="card__ft">{regions.length} régions actives sur {REGIONS.length}</div>
        </section>
      </div>

      <section className="card" style={{ marginTop: 16 }}>
        <div className="card__hd"><h3>Répartition par catégorie de partenaire</h3></div>
        <div className="card__bd"><BarList rows={cats} fmt={eurShort} /></div>
      </section>
    </>
  );
}

/* ---- Validations d'adhésion ----------------------------------------------- */
function Validations({ agent }) {
  usePageTitle("Validations d'adhésion");
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const pend = db.partners.filter(p => p.status === "pending");
  const hist = db.audit.filter(a => a.action === "status").slice(0, 8);

  const modal = useModal();

  const valider = async p => {
    try {
      await api.patch("/partners/" + p.id, { status: "active", author: agent.name, authorId: agent.id });
      toast("good", "Adhésion validée", p.name + " peut désormais encaisser.");
    } catch (e) { /* message déjà affiché */ }
  };

  /* Un refus sans motif écrit n'est pas opposable au partenaire : le formulaire
     l'exige, et l'API le refuse aussi (§2.3, Pontaillac). */
  const refuser = p => {
    let motive = "";
    modal.open("Refuser l'adhésion — " + p.name, (
      <>
        <Note kind="warn">
          Le motif est communiqué à l&apos;établissement dans son espace, avec la date de la
          décision et le nom de l&apos;agent instructeur. Il est conservé au journal.
        </Note>
        <label className="field" style={{ marginTop: 14 }}>
          <span className="field__lb">Motif du refus (obligatoire, dix caractères minimum)</span>
          <textarea className="textarea" autoFocus
                    placeholder="Ex. SIREN non vérifiable au répertoire Sirene ; objet social hors champ du dispositif."
                    onChange={e => { motive = e.target.value; }} />
        </label>
      </>
    ), (
      <>
        <button className="btn" type="button" onClick={modal.close}>Renoncer</button>
        <button className="btn btn--danger" type="button" onClick={async () => {
          if (motive.trim().length < 10) {
            toast("bad", "Motif trop court", "Dix caractères au minimum : le partenaire doit comprendre la décision.");
            return;
          }
          modal.close();
          try {
            await api.patch("/partners/" + p.id,
              { status: "rejected", note: motive.trim(), author: agent.name, authorId: agent.id });
            toast("info", "Adhésion refusée", p.name + " — motif transmis à l'établissement.");
          } catch (e) { /* message déjà affiché */ }
        }}>Refuser l&apos;adhésion</button>
      </>
    ));
  };

  return (
    <>
      <div className="pagehead"><div><h1>Validations d&apos;adhésion</h1>
        <p>Toute demande d&apos;adhésion est instruite manuellement avant activation (§2.2). Un
          établissement non validé ne peut encaisser aucune transaction.</p></div></div>

      {pend.length ? (
        <div className="grid g-2">
          {pend.map(p => (
            <section className="card" key={p.id}>
              <div className="card__hd">
                <span className="pitem__ico"><Icon name={catIco(p.category)} /></span>
                <div><h3>{p.name}</h3>
                  <span className="sub">{catLabel(p.category)} · {p.city}</span></div>
                <span className="act"><Pill kind="warn">En attente</Pill></span>
              </div>
              <div className="card__bd" style={{ fontSize: 13, display: "flex", flexDirection: "column", gap: 6 }}>
                <div><span style={{ color: "var(--ink-3)" }}>Adresse </span>{p.address || "—"}, {p.city}</div>
                <div><span style={{ color: "var(--ink-3)" }}>SIREN </span>
                  <span className="mono">{p.siren || "—"}</span>
                  {p.siren ? <span style={{ color: "var(--good)", marginLeft: 6 }}>clé valide</span> : null}</div>
                <div><span style={{ color: "var(--ink-3)" }}>Objet social </span>{p.objetSocial || "—"}</div>
                <div><span style={{ color: "var(--ink-3)" }}>Contact </span>{p.contact || "—"}</div>
                <div><span style={{ color: "var(--ink-3)" }}>Déposée le </span>{dateFR(p.createdAt, true)}</div>
              </div>
              <div className="card__ft" style={{ display: "flex", gap: 8 }}>
                <button className="btn btn--primary" type="button" onClick={() => valider(p)}>
                  <Icon name="check" /> Valider l&apos;adhésion
                </button>
                <button className="btn" type="button" onClick={() => refuser(p)}>Refuser…</button>
              </div>
            </section>
          ))}
        </div>
      ) : (
        <section className="card"><Empty icon="check">Aucune demande en attente d&apos;instruction.</Empty></section>
      )}

      <section className="card" style={{ marginTop: 16 }}>
        <div className="card__hd"><h3>Décisions récentes</h3></div>
        <div className="tblwrap">
          <table className="tbl">
            <thead><tr><th>Date</th><th>Cible</th><th>Décision</th><th>Motif</th><th>Agent</th></tr></thead>
            <tbody>
              {hist.length ? hist.map((a, i) => {
                const cible = db.partners.find(p => p.id === a.target)
                           || db.employees.find(e => e.id === a.target);
                return (
                  <tr key={i}>
                    <td className="num">{dateFR(a.at, true)}</td>
                    <td>{cible ? cible.name : a.target}</td>
                    <td><Pill kind={(STATUS[a.to] || STATUS.closed).pill.replace("pill--", "")}>
                      {(STATUS[a.to] || {}).label || a.to}</Pill></td>
                    <td style={{ color: "var(--ink-3)", maxWidth: 340 }}>{a.note || "—"}</td>
                    <td style={{ color: "var(--ink-3)" }}>{a.actor}</td>
                  </tr>
                );
              }) : <tr><td colSpan="5"><Empty>Aucune décision enregistrée</Empty></td></tr>}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

/* ---- Le Choix du Ministre --------------------------------------------------
   Le ministre veut désigner lui-même les partenaires mis en avant, « sans
   passer par votre équipe » (annotation §2.1). L'écran est donc une bascule
   directe, avec un mot qui s'affiche tel quel côté salarié et sur la page
   publique. */
function Vitrine({ agent }) {
  usePageTitle("Le Choix du Ministre");
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const modal = useModal();
  const actifs = db.partners.filter(p => p.status === "active");
  const mis = actifs.filter(p => p.featured);

  const retirer = async p => {
    try {
      await api.patch("/partners/" + p.id + "/featured", { featured: false, author: agent.name });
      toast("info", "Retiré de la vitrine", p.name + " n'apparaît plus dans le Choix du Ministre.");
    } catch (e) { /* message déjà affiché */ }
  };

  const mettreEnAvant = p => {
    let note = p.ministerNote || "";
    modal.open("Mettre en avant — " + p.name, (
      <>
        <Note>
          Le partenaire apparaîtra dans « Le Choix du Ministre » sur l&apos;accueil des salariés
          et sur la page publique. Le mot ci-dessous est repris tel quel, signé de votre nom.
        </Note>
        <label className="field" style={{ marginTop: 14 }}>
          <span className="field__lb">Le mot du ministre (facultatif, 160 caractères)</span>
          <textarea className="textarea" defaultValue={note} autoFocus maxLength={160}
                    placeholder="Ex. Parfait pour souder une équipe et renouer avec la nature."
                    onChange={e => { note = e.target.value; }} />
        </label>
      </>
    ), (
      <>
        <button className="btn" type="button" onClick={modal.close}>Annuler</button>
        <button className="btn btn--primary" type="button" onClick={async () => {
          modal.close();
          try {
            await api.patch("/partners/" + p.id + "/featured",
              { featured: true, note, author: agent.name });
            toast("good", "Mis en avant", p.name + " apparaît désormais dans le Choix du Ministre.");
          } catch (e) { /* message déjà affiché */ }
        }}>Mettre en avant</button>
      </>
    ));
  };

  return (
    <>
      <div className="pagehead">
        <div><h1>Le Choix du Ministre</h1>
          <p>Les partenaires mis en avant sur la page publique et sur l&apos;accueil des salariés.
            La modification est immédiate, sans intervention technique.</p></div>
        <div className="pagehead__act"><Pill kind="info">{mis.length} sur {actifs.length} partenaires</Pill></div>
      </div>

      {mis.length ? (
        <div className="grid g-3" style={{ marginBottom: 20 }}>
          {mis.map(p => (
            <section className="card pickcard" key={p.id}>
              <div className="card__bd">
                <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
                  <span className="pitem__ico"><Icon name={catIco(p.category)} /></span>
                  <div style={{ minWidth: 0 }}>
                    <b style={{ fontSize: 14 }}>{p.name}</b>
                    <div style={{ fontSize: 12, color: "var(--ink-3)" }}>
                      {catLabel(p.category)} · {p.city}
                    </div>
                  </div>
                  <span style={{ marginLeft: "auto" }} className="pick__star" title="Mis en avant">★</span>
                </div>
                {p.ministerNote ? <p className="quote" style={{ marginTop: 12 }}>« {p.ministerNote} »</p> : null}
              </div>
              <div className="card__ft" style={{ display: "flex", gap: 8 }}>
                <button className="btn" type="button" onClick={() => mettreEnAvant(p)}>Modifier le mot</button>
                <button className="btn btn--ghost" type="button" onClick={() => retirer(p)}>Retirer</button>
              </div>
            </section>
          ))}
        </div>
      ) : (
        <section className="card" style={{ marginBottom: 20 }}>
          <Empty icon="spark">Aucun partenaire mis en avant pour l&apos;instant.</Empty>
        </section>
      )}

      <section className="card">
        <div className="card__hd"><h3>Tous les partenaires actifs</h3>
          <span className="sub">une bascule par ligne</span></div>
        <div className="tblwrap">
          <table className="tbl">
            <thead><tr><th>Établissement</th><th>Catégorie</th><th>Ville</th>
              <th>Le mot du ministre</th><th></th></tr></thead>
            <tbody>
              {actifs.map(p => (
                <tr key={p.id}>
                  <td><b>{p.name}</b>{p.featured ? <span className="pick__star"> ★</span> : null}</td>
                  <td>{catLabel(p.category)}</td>
                  <td style={{ color: "var(--ink-3)" }}>{p.city}</td>
                  <td style={{ color: "var(--ink-3)", maxWidth: 320 }}>
                    {p.ministerNote || <span style={{ color: "var(--ink-4)" }}>—</span>}
                  </td>
                  <td className="r">
                    {p.featured ? (
                      <button className="btn btn--ghost" type="button" onClick={() => retirer(p)}>Retirer</button>
                    ) : (
                      <button className="btn" type="button" onClick={() => mettreEnAvant(p)}>
                        <Icon name="spark" /> Mettre en avant
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

/* ---- Salariés : la relation directe administration ↔ bénéficiaire ---------- */
function Salaries({ agent }) {
  usePageTitle("Salariés bénéficiaires");
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const modal = useModal();
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [res, setRes] = useState(null);
  const [openId, setOpenId] = useState(null);

  useEffect(() => {
    let alive = true;
    api.get("/employees", { query, page, size: 8 }).then(r => { if (alive) setRes(r); }).catch(() => {});
    return () => { alive = false; };
  }, [api, query, page, db.employees.length, db.txns.length, db.topups.length]);

  const changerStatut = async (id, status) => {
    try {
      const e = await api.patch("/employees/" + id, { status });
      toast(status === "active" ? "good" : "info", "Compte mis à jour",
        e.name + " — " + STATUS[status].label.toLowerCase() + ".");
    } catch (err) { /* message déjà affiché */ }
  };

  const regulariser = employee => {
    let montant = "", motif = "";
    modal.open("Régularisation — " + employee.name, (
      <>
        <Note>
          Une régularisation crédite le solde du bénéficiaire sans passer par l&apos;employeur.
          Elle est tracée au journal et visible par le salarié dans son historique.
        </Note>
        <label className="field" style={{ marginTop: 14 }}>
          <span className="field__lb">Montant à créditer</span>
          <input className="input input--big num" inputMode="decimal" placeholder="0,00" autoFocus
                 onChange={e => { montant = e.target.value; }} />
        </label>
        <label className="field">
          <span className="field__lb">Motif</span>
          <input className="input" placeholder="Ex. double débit constaté le 12 août"
                 onChange={e => { motif = e.target.value; }} />
        </label>
      </>
    ), (
      <>
        <button className="btn" type="button" onClick={modal.close}>Annuler</button>
        <button className="btn btn--primary" type="button" onClick={async () => {
          const cts = centimes(montant);
          if (!cts) { toast("bad", "Montant invalide", "Saisissez un montant supérieur à zéro."); return; }
          modal.close();
          try {
            await api.post("/topups", { employerId: employee.employerId, employeeIds: [employee.id],
              amount: cts, kind: "regularisation", label: "Régularisation", actor: agent.name, note: motif });
            toast("good", "Régularisation créditée", employee.name + " · " + eur(cts));
          } catch (e) { /* message déjà affiché */ }
        }}>Créditer</button>
      </>
    ));
  };

  if (openId) {
    const e = db.employees.find(x => x.id === openId);
    if (!e) { setOpenId(null); return null; }
    return <FicheSalarie employee={e} onBack={() => setOpenId(null)}
                         onStatus={changerStatut} onRegularise={() => regulariser(e)} />;
  }

  return (
    <>
      <div className="pagehead">
        <div><h1>Salariés bénéficiaires</h1>
          <p>Comptes, soldes et suites données aux demandes. C&apos;est ici que l&apos;administration
            agit directement sur un bénéficiaire, sans passer par son employeur.</p></div>
      </div>

      <section className="card">
        <div className="card__hd">
          <input className="input" type="search" placeholder="Rechercher un salarié…" style={{ maxWidth: 280 }}
                 value={query} onChange={e => { setQuery(e.target.value); setPage(1); }} />
          <span className="sub">{res ? res.total : 0} bénéficiaires</span>
        </div>
        <div className="tblwrap">
          <table className="tbl">
            <thead><tr>
              <th>Salarié</th><th>Employeur</th><th className="r">Solde</th>
              <th>Statut</th><th>Demandes</th><th></th>
            </tr></thead>
            <tbody>
              {res && res.items.map(e => {
                const claims = db.claims.filter(c => c.employeeId === e.id
                  && (c.status === "open" || c.status === "in_progress")).length;
                return (
                  <tr key={e.id}>
                    <td><b>{e.name}</b>
                      <div style={{ fontSize: 11.5, color: "var(--ink-4)" }}>{e.email}</div></td>
                    <td>{e.employer}</td>
                    <td className="r num"><b>{eur(e.balance)}</b></td>
                    <td><Pill kind={STATUS[e.status].pill.replace("pill--", "")}>{STATUS[e.status].label}</Pill></td>
                    <td>{claims ? <Pill kind="warn">{claims} ouverte{claims > 1 ? "s" : ""}</Pill>
                                : <span style={{ color: "var(--ink-4)" }}>—</span>}</td>
                    <td className="r">
                      <button className="btn btn--ghost" type="button" onClick={() => setOpenId(e.id)}>
                        Ouvrir la fiche <Icon name="right" />
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <div className="card__ft"><div className="pager"><Pager meta={res} onPage={setPage} /></div></div>
      </section>
    </>
  );
}

function FicheSalarie({ employee, onBack, onStatus, onRegularise }) {
  const db = useDB();
  const { push } = useNav();
  const txns = db.txns.filter(t => t.employeeId === employee.id).slice(-8).reverse();
  const tops = db.topups.filter(t => t.employeeId === employee.id).slice(0, 6);
  const claims = db.claims.filter(c => c.employeeId === employee.id);
  const depense = db.txns.filter(t => t.employeeId === employee.id).reduce((s, t) => s + t.amount, 0);
  const credite = db.topups.filter(t => t.employeeId === employee.id).reduce((s, t) => s + t.amount, 0);

  return (
    <>
      <div className="pagehead">
        <div>
          <button className="btn btn--ghost" type="button" onClick={onBack} style={{ marginBottom: 8 }}>
            <Icon name="left" /> Tous les salariés
          </button>
          <h1>{employee.name}</h1>
          <p>{employee.email} · {(db.employers.find(x => x.id === employee.employerId) || {}).name} ·
            {" "}bénéficiaire depuis le {employee.since}</p>
        </div>
        <div className="pagehead__act">
          <Pill kind={STATUS[employee.status].pill.replace("pill--", "")}>{STATUS[employee.status].label}</Pill>
          <button className="btn" type="button" onClick={onRegularise}>
            <Icon name="wallet" /> Régulariser
          </button>
          {employee.status === "active" ? (
            <button className="btn" type="button" onClick={() => onStatus(employee.id, "suspended")}>
              Suspendre
            </button>
          ) : (
            <button className="btn btn--primary" type="button" onClick={() => onStatus(employee.id, "active")}>
              Réactiver
            </button>
          )}
          {employee.status !== "closed" ? (
            <button className="btn btn--ghost" type="button" onClick={() => onStatus(employee.id, "closed")}>
              Clôturer
            </button>
          ) : null}
        </div>
      </div>

      <div className="grid g-4" style={{ marginBottom: 16 }}>
        <StatTile label="Solde disponible" value={eur(employee.balance)} />
        <StatTile label="Total crédité" value={eur(credite)} note="dotations et régularisations" />
        <StatTile label="Total dépensé" value={eur(depense)} />
        <StatTile label="Réclamations" value={claims.length}
                  note={claims.filter(c => c.status === "open" || c.status === "in_progress").length + " en cours"} />
      </div>

      <div className="grid g-main">
        <section className="card">
          <div className="card__hd"><h3>Dernières opérations</h3></div>
          <div className="tblwrap">
            <table className="tbl">
              <thead><tr><th>Référence</th><th>Date</th><th>Partenaire</th><th className="r">Montant</th></tr></thead>
              <tbody>
                {txns.length ? txns.map(t => {
                  const p = db.partners.find(x => x.id === t.partnerId);
                  return (
                    <tr key={t.ref}>
                      <td className="mono">{t.ref}</td>
                      <td className="num">{dateFR(t.at, true)}</td>
                      <td>{p ? p.name : "—"}</td>
                      <td className="r num">−{eur(t.amount)}</td>
                    </tr>
                  );
                }) : <tr><td colSpan="4"><Empty>Aucune opération</Empty></td></tr>}
              </tbody>
            </table>
          </div>
        </section>

        <div style={{ display: "grid", gap: 16 }}>
          <section className="card">
            <div className="card__hd"><h3>Crédits reçus</h3></div>
            <div className="card__bd" style={{ padding: "8px 0" }}>
              {tops.map(t => (
                <div className="txnrow" key={t.id} style={{ padding: "9px 18px" }}>
                  <span className="txnrow__ico txnrow__ico--in"><Icon name="wallet" /></span>
                  <span className="txnrow__m">
                    <span className="txnrow__t" style={{ display: "block" }}>
                      {t.kind === "regularisation" ? "Régularisation" : t.label}
                    </span>
                    <span className="txnrow__s">{dateFR(t.at)} · {t.note || t.actor}</span>
                  </span>
                  <span className="txnrow__a txnrow__a--in num">+{eur(t.amount)}</span>
                </div>
              ))}
            </div>
          </section>

          <section className="card">
            <div className="card__hd"><h3>Réclamations</h3>
              <span className="act">
                <button className="btn btn--ghost" type="button" onClick={() => push("/admin/reclamations")}>
                  Ouvrir la file
                </button>
              </span>
            </div>
            <div className="card__bd" style={{ padding: 0 }}>
              {claims.length ? claims.map(c => (
                <div className="claimrow" key={c.id} style={{ cursor: "default" }}>
                  <span className="claimrow__m">
                    <span className="claimrow__t" style={{ display: "block" }}>{c.subject}</span>
                    <span className="claimrow__s" style={{ display: "block" }}>
                      {c.id} · {ilYA(c.updatedAt)}
                    </span>
                  </span>
                  <Pill kind={CLAIM_STATUS[c.status].pill.replace("pill--", "")}>
                    {CLAIM_STATUS[c.status].label}
                  </Pill>
                </div>
              )) : <Empty icon="chat">Aucune réclamation</Empty>}
            </div>
          </section>
        </div>
      </div>
    </>
  );
}

/* ---- Réclamations : instruction et réponse -------------------------------- */
function Reclamations({ agent }) {
  usePageTitle("Réclamations");
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const modal = useModal();
  const [filtre, setFiltre] = useState("open");
  const [openId, setOpenId] = useState(null);
  const [reply, setReply] = useState("");

  const rows = db.claims.slice().sort((a, b) => b.updatedAt - a.updatedAt)
    .filter(c => filtre === "all" ? true
      : filtre === "open" ? (c.status === "open" || c.status === "in_progress")
      : c.status === filtre);

  const courant = openId ? db.claims.find(c => c.id === openId) : null;

  const repondre = async () => {
    if (!reply.trim()) return;
    try {
      await api.post("/claims/" + courant.id + "/messages",
        { from: "admin", author: agent.name, body: reply });
      setReply("");
      toast("good", "Réponse envoyée", "Le salarié la verra dans son espace.");
    } catch (e) { /* message déjà affiché */ }
  };

  const cloturer = (status) => {
    const employee = db.employees.find(e => e.id === courant.employeeId);
    let montant = "", note = "";
    modal.open(status === "resolved" ? "Clôturer et régulariser" : "Rejeter la réclamation", (
      <>
        <Note kind={status === "resolved" ? "good" : "warn"}>
          {status === "resolved"
            ? "Un montant saisi ici est crédité immédiatement au solde du salarié et tracé comme régularisation. Laissez vide pour clôturer sans mouvement."
            : "Le salarié verra le motif du rejet dans son fil. La réclamation sera close ; il pourra en ouvrir une nouvelle."}
        </Note>
        {status === "resolved" ? (
          <label className="field" style={{ marginTop: 14 }}>
            <span className="field__lb">Régularisation (facultative)</span>
            <input className="input input--big num" inputMode="decimal" placeholder="0,00"
                   onChange={e => { montant = e.target.value; }} />
            <span className="field__hint">
              Solde actuel de {employee ? employee.name : "—"} : {employee ? eur(employee.balance) : "—"}
            </span>
          </label>
        ) : null}
        <label className="field">
          <span className="field__lb">Message de clôture</span>
          <textarea className="textarea" autoFocus placeholder="Expliquez la décision au salarié."
                    onChange={e => { note = e.target.value; }} />
        </label>
      </>
    ), (
      <>
        <button className="btn" type="button" onClick={modal.close}>Annuler</button>
        <button className={"btn " + (status === "resolved" ? "btn--primary" : "btn--danger")} type="button"
                onClick={async () => {
                  modal.close();
                  const cts = status === "resolved" ? centimes(montant) : null;
                  try {
                    await api.patch("/claims/" + courant.id,
                      { status, note, amount: cts || 0, author: agent.name });
                    toast("good", status === "resolved" ? "Réclamation résolue" : "Réclamation rejetée",
                      cts ? "Régularisation de " + eur(cts) + " créditée." : "Le salarié a été informé.");
                  } catch (e) { /* message déjà affiché */ }
                }}>
          {status === "resolved" ? "Clôturer et créditer" : "Rejeter"}
        </button>
      </>
    ));
  };

  if (courant) {
    const employee = db.employees.find(e => e.id === courant.employeeId);
    const closed = courant.status === "resolved" || courant.status === "rejected";
    return (
      <>
        <div className="pagehead">
          <div>
            <button className="btn btn--ghost" type="button" onClick={() => setOpenId(null)} style={{ marginBottom: 8 }}>
              <Icon name="left" /> File des réclamations
            </button>
            <h1>{courant.subject}</h1>
            <p>{courant.id} · {employee ? employee.name : "—"} ·
              {" "}{CLAIM_CATEGORIES.find(c => c.id === courant.category)?.label} ·
              {" "}ouverte le {dateFR(courant.createdAt)}</p>
          </div>
          <div className="pagehead__act">
            <Pill kind={CLAIM_STATUS[courant.status].pill.replace("pill--", "")}>
              {CLAIM_STATUS[courant.status].label}
            </Pill>
          </div>
        </div>

        <div className="grid g-main">
          <section className="card"><div className="card__bd">
            <Fil messages={courant.messages} />
            {closed ? (
              <div style={{ marginTop: 18 }}>
                <Note>Réclamation clôturée{courant.resolution
                  ? ", avec une régularisation de " + eur(courant.resolution.amount) : ""}.</Note>
              </div>
            ) : (
              <div style={{ marginTop: 18, borderTop: "1px solid var(--line)", paddingTop: 16 }}>
                <label className="field">
                  <span className="field__lb">Répondre au salarié</span>
                  <textarea className="textarea" value={reply} onChange={e => setReply(e.target.value)}
                            placeholder="Votre réponse apparaîtra dans l'espace du salarié." />
                </label>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  <button className="btn btn--primary" type="button" onClick={repondre} disabled={!reply.trim()}>
                    <Icon name="arrow" /> Envoyer la réponse
                  </button>
                  <button className="btn" type="button" onClick={() => cloturer("resolved")}>
                    <Icon name="check" /> Clôturer et régulariser
                  </button>
                  <button className="btn btn--ghost" type="button" onClick={() => cloturer("rejected")}>
                    Rejeter
                  </button>
                </div>
              </div>
            )}
          </div></section>

          <section className="card">
            <div className="card__hd"><h3>Dossier du bénéficiaire</h3></div>
            <div className="card__bd">
              {employee ? (
                <>
                  <div style={{ display: "flex", gap: 12, alignItems: "center", marginBottom: 14 }}>
                    <span className="msg__av" style={{ width: 40, height: 40, fontSize: 13 }}>
                      {initiales(employee.name)}
                    </span>
                    <div>
                      <b>{employee.name}</b>
                      <div style={{ fontSize: 12, color: "var(--ink-3)" }}>
                        {(db.employers.find(x => x.id === employee.employerId) || {}).name}
                      </div>
                    </div>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", padding: "7px 0",
                                borderTop: "1px solid var(--line)", fontSize: 13 }}>
                    <span style={{ color: "var(--ink-3)" }}>Solde</span>
                    <b className="num">{eur(employee.balance)}</b>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", padding: "7px 0",
                                borderTop: "1px solid var(--line)", fontSize: 13 }}>
                    <span style={{ color: "var(--ink-3)" }}>Statut du compte</span>
                    <Pill kind={STATUS[employee.status].pill.replace("pill--", "")}>
                      {STATUS[employee.status].label}
                    </Pill>
                  </div>
                  {courant.txnRef ? (
                    <div style={{ display: "flex", justifyContent: "space-between", padding: "7px 0",
                                  borderTop: "1px solid var(--line)", fontSize: 13 }}>
                      <span style={{ color: "var(--ink-3)" }}>Opération visée</span>
                      <span className="mono">{courant.txnRef}</span>
                    </div>
                  ) : null}
                  {courant.txnRef ? <OperationVisee ref_={courant.txnRef} /> : null}
                </>
              ) : <Empty>Bénéficiaire introuvable</Empty>}
            </div>
          </section>
        </div>
      </>
    );
  }

  return (
    <>
      <div className="pagehead">
        <div><h1>Réclamations</h1>
          <p>Les demandes adressées par les bénéficiaires. Répondre, régulariser ou rejeter :
            tout se fait dans le fil, et le salarié voit la réponse dans son espace.</p></div>
        <div className="pagehead__act">
          {[["open", "À traiter"], ["resolved", "Résolues"], ["rejected", "Rejetées"], ["all", "Toutes"]]
            .map(([k, lb]) => (
              <button key={k} className="pgbtn" type="button"
                      aria-current={filtre === k ? "true" : undefined}
                      onClick={() => setFiltre(k)}>{lb}</button>
            ))}
        </div>
      </div>

      <section className="card">
        {rows.length ? rows.map(c => {
          const e = db.employees.find(x => x.id === c.employeeId);
          const last = c.messages[c.messages.length - 1];
          return (
            <button key={c.id} className="claimrow" type="button" onClick={() => setOpenId(c.id)}>
              <span className="msg__av">{initiales(e ? e.name : "?")}</span>
              <span className="claimrow__m">
                <span className="claimrow__t" style={{ display: "block" }}>{c.subject}</span>
                <span className="claimrow__s" style={{ display: "block" }}>
                  {c.id} · {e ? e.name : "—"} · {last ? (last.from === "admin" ? "Réponse de " : "Message de ")
                    + last.author : ""} · {ilYA(c.updatedAt)}
                </span>
              </span>
              <Pill kind={CLAIM_STATUS[c.status].pill.replace("pill--", "")}>
                {CLAIM_STATUS[c.status].label}
              </Pill>
            </button>
          );
        }) : <Empty icon="chat">Aucune réclamation dans ce filtre.</Empty>}
      </section>
    </>
  );
}

function OperationVisee({ ref_ }) {
  const db = useDB();
  const t = db.txns.find(x => x.ref === ref_);
  if (!t) return null;
  const p = db.partners.find(x => x.id === t.partnerId);
  return (
    <div style={{ marginTop: 14 }}>
      <Note>
        <b>{p ? p.name : "—"}</b> · {eur(t.amount)} · {dateFR(t.at, true)}<br />
        Empreinte <span className="mono">{t.hash}</span> — l&apos;écriture ne peut pas être modifiée ;
        seule une régularisation créditée fait mouvement inverse.
      </Note>
    </div>
  );
}

/* ---- Comptes partenaires --------------------------------------------------- */
function Comptes({ agent }) {
  usePageTitle("Comptes partenaires");
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const [page, setPage] = useState(1);
  const [res, setRes] = useState(null);

  useEffect(() => {
    let alive = true;
    api.get("/partners", { all: 1, size: 8, page }).then(r => { if (alive) setRes(r); }).catch(() => {});
    return () => { alive = false; };
  }, [api, page, db.partners.length, db.partners.map(p => p.status).join("")]);

  const modal = useModal();

  const setStatus = async (p, status) => {
    if (status === "active") {
      try {
        await api.patch("/partners/" + p.id, { status, author: agent.name, authorId: agent.id });
        toast("good", "Statut mis à jour", p.name + " — actif.");
      } catch (e) { /* message déjà affiché */ }
      return;
    }
    let motive = "";
    modal.open((status === "suspended" ? "Suspendre" : "Clôturer") + " — " + p.name, (
      <>
        <Note kind="warn">
          Un motif écrit est obligatoire : il est montré à l&apos;établissement et conservé au
          journal des décisions, avec votre nom et l&apos;horodatage.
        </Note>
        <label className="field" style={{ marginTop: 14 }}>
          <span className="field__lb">Motif (dix caractères minimum)</span>
          <textarea className="textarea" autoFocus onChange={e => { motive = e.target.value; }} />
        </label>
      </>
    ), (
      <>
        <button className="btn" type="button" onClick={modal.close}>Renoncer</button>
        <button className="btn btn--danger" type="button" onClick={async () => {
          if (motive.trim().length < 10) {
            toast("bad", "Motif trop court", "Dix caractères au minimum.");
            return;
          }
          modal.close();
          try {
            await api.patch("/partners/" + p.id,
              { status, note: motive.trim(), author: agent.name, authorId: agent.id });
            toast("info", "Statut mis à jour", p.name + " — " + STATUS[status].label.toLowerCase() + ".");
          } catch (e) { /* message déjà affiché */ }
        }}>Confirmer</button>
      </>
    ));
  };

  return (
    <>
      <div className="pagehead"><div><h1>Comptes partenaires</h1>
        <p>Activation, suspension et clôture des établissements référencés.</p></div></div>
      <section className="card">
        <div className="card__hd"><h3>Partenaires</h3>
          <span className="sub">{res ? res.total : 0} comptes</span></div>
        <div className="tblwrap">
          <table className="tbl">
            <thead><tr><th>Établissement</th><th>Catégorie</th><th>Région</th><th>Statut</th><th>Actions</th></tr></thead>
            <tbody>
              {res && res.items.map(p => (
                <tr key={p.id}>
                  <td><b>{p.name}</b>
                    <div className="mono" style={{ fontSize: 11.5, color: "var(--ink-4)" }}>{p.id}</div></td>
                  <td>{p.categoryLabel}</td>
                  <td style={{ color: "var(--ink-3)" }}>{p.region}</td>
                  <td><Pill kind={STATUS[p.status].pill.replace("pill--", "")}>{STATUS[p.status].label}</Pill></td>
                  <td>
                    <div style={{ display: "flex", gap: 6 }}>
                      {p.status !== "active" ? (
                        <button className="btn" type="button" onClick={() => setStatus(p, "active")}>Activer</button>
                      ) : (
                        <button className="btn" type="button" onClick={() => setStatus(p, "suspended")}>Suspendre…</button>
                      )}
                      {p.status !== "closed" ? (
                        <button className="btn btn--ghost" type="button" onClick={() => setStatus(p, "closed")}>
                          Clôturer…
                        </button>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="card__ft"><div className="pager"><Pager meta={res} onPage={setPage} /></div></div>
      </section>
    </>
  );
}

/* ---- Rechargements employeurs ---------------------------------------------- */
function Recharges({ agent }) {
  usePageTitle("Rechargements");
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const [employerId, setEmployerId] = useState(db.employers[0].id);
  const [amount, setAmount] = useState("180,00");
  const [label, setLabel] = useState("Dotation mensuelle");
  const [checked, setChecked] = useState(() => db.employees.filter(e => e.employerId === db.employers[0].id).map(e => e.id));

  useEffect(() => {
    setChecked(db.employees.filter(e => e.employerId === employerId && e.status === "active").map(e => e.id));
  }, [employerId, db.employees]);

  const liste = db.employees.filter(e => e.employerId === employerId);

  const crediter = async () => {
    const cts = centimes(amount);
    if (!cts) { toast("bad", "Montant invalide", "Saisissez un montant supérieur à zéro."); return; }
    if (!checked.length) { toast("bad", "Aucun bénéficiaire", "Sélectionnez au moins un salarié."); return; }
    try {
      const r = await api.post("/topups", { employerId, amount: cts, employeeIds: checked,
        label, kind: "dotation", actor: agent.name });
      toast("good", "Comptes crédités", r.credited + " salariés · " + eur(r.total) + " au total.");
    } catch (e) { /* message déjà affiché */ }
  };

  return (
    <>
      <div className="pagehead"><div><h1>Rechargements employeurs</h1>
        <p>Créditer les comptes salariés au nom d&apos;un employeur raccordé au dispositif.</p></div></div>

      <SimBar>
        <b>Créditation de simulation.</b> Aucun fonds n&apos;est appelé auprès de l&apos;employeur :
        l&apos;opération n&apos;augmente qu&apos;un solde fictif.
      </SimBar>

      <div className="grid g-main">
        <section className="card">
          <div className="card__hd"><h3>Nouveau rechargement</h3></div>
          <div className="card__bd">
            <label className="field">
              <span className="field__lb">Employeur</span>
              <select className="select" value={employerId} onChange={e => setEmployerId(e.target.value)}>
                {db.employers.map(e => (
                  <option key={e.id} value={e.id}>{e.name} — {e.headcount} salariés</option>
                ))}
              </select>
            </label>
            <label className="field">
              <span className="field__lb">Montant par salarié</span>
              <input className="input input--big num" inputMode="decimal" value={amount}
                     onChange={e => setAmount(e.target.value)} />
              <span className="field__hint">Le même montant est crédité à chaque bénéficiaire sélectionné.</span>
            </label>
            <label className="field">
              <span className="field__lb">Libellé</span>
              <input className="input" value={label} onChange={e => setLabel(e.target.value)} />
            </label>
            <span className="field__lb">Bénéficiaires</span>
            <div style={{ maxHeight: 190, overflow: "auto", border: "1px solid var(--line)",
                          borderRadius: "var(--r-ctl)", padding: "8px 10px", marginBottom: 14 }}>
              {liste.map(e => (
                <label key={e.id} style={{ display: "flex", gap: 9, alignItems: "center",
                                           padding: "5px 0", fontSize: 13 }}>
                  <input type="checkbox" checked={checked.includes(e.id)}
                         onChange={ev => setChecked(c => ev.target.checked
                           ? c.concat(e.id) : c.filter(x => x !== e.id))} />
                  {e.name}
                  {e.status !== "active"
                    ? <Pill kind="crit">{STATUS[e.status].label}</Pill> : null}
                  <span style={{ marginLeft: "auto", color: "var(--ink-4)" }} className="num">
                    {eur(e.balance)}
                  </span>
                </label>
              ))}
            </div>
            <button className="btn btn--primary btn--lg btn--block" type="button" onClick={crediter}>
              <Icon name="wallet" /> Créditer les comptes
            </button>
          </div>
        </section>

        <section className="card">
          <div className="card__hd"><h3>Derniers mouvements</h3></div>
          <div className="tblwrap">
            <table className="tbl">
              <thead><tr><th>Réf.</th><th>Salarié</th><th className="r">Montant</th><th>Nature</th><th>Date</th></tr></thead>
              <tbody>
                {db.topups.slice(0, 10).map(t => (
                  <tr key={t.id}>
                    <td className="mono">{t.id}</td>
                    <td>{(db.employees.find(e => e.id === t.employeeId) || {}).name || "—"}</td>
                    <td className="r num">+{eur(t.amount)}</td>
                    <td>{t.kind === "regularisation"
                      ? <Pill kind="info">Régularisation</Pill> : <Pill kind="mute">Dotation</Pill>}</td>
                    <td className="num" style={{ color: "var(--ink-3)" }}>{dateFR(t.at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </>
  );
}

/* ---- Registre -------------------------------------------------------------- */
function Registre({ agent }) {
  usePageTitle("Registre des transactions");
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const modal = useModal();
  const [v, setV] = useState(null);
  const [msg, setMsg] = useState(null);

  /* Le ministre veut pouvoir annuler ; une écriture validée reste inaltérable.
     Les deux tiennent ensemble parce que l'annulation est une écriture de plus,
     de sens inverse, et non une correction de l'ancienne. */
  const annuler = t => {
    let reason = "";
    modal.open("Annuler l'écriture " + t.ref, (
      <>
        <Note kind="warn">
          <b>L&apos;écriture ne sera pas effacée.</b> Une écriture inverse est ajoutée au registre,
          rattachée à celle-ci, et le salarié est recrédité de {eur(t.amount)}. La chaîne
          d&apos;empreintes reste vérifiable.
        </Note>
        <label className="field" style={{ marginTop: 14 }}>
          <span className="field__lb">Motif de l&apos;annulation</span>
          <input className="input" autoFocus placeholder="Ex. double encaissement constaté"
                 onChange={e => { reason = e.target.value; }} />
        </label>
      </>
    ), (
      <>
        <button className="btn" type="button" onClick={modal.close}>Renoncer</button>
        <button className="btn btn--danger" type="button" onClick={async () => {
          modal.close();
          try {
            const rev = await api.post("/transactions/" + t.ref + "/cancel",
              { reason, author: agent.name });
            await verifier();
            toast("good", "Écriture annulée", rev.ref + " compense " + t.ref + " · " + eur(t.amount));
          } catch (e) { /* message déjà affiché */ }
        }}>Annuler l&apos;écriture</button>
      </>
    ));
  };

  const verifier = async note => {
    const r = await api.get("/ledger/verify");
    setV(r); setMsg(note || null);
    return r;
  };
  useEffect(() => { verifier(); /* eslint-disable-next-line */ }, []);

  const falsifier = async () => {
    const i = Math.max(0, db.txns.length - 5);
    const t = db.txns[i], keep = t.amount;
    t.amount = keep + 1337;
    await verifier("La ligne " + t.ref + " a été modifiée hors procédure.");
    setTimeout(async () => {
      t.amount = keep;
      await verifier("Valeur d'origine restaurée : le registre est de nouveau cohérent.");
      toast("info", "Démonstration terminée", "Le montant modifié a été restauré.");
    }, 2800);
  };

  const last = db.txns.slice(-14).reverse();
  const annulations = db.txns.filter(t => t.kind === "reversal").length;

  return (
    <>
      <div className="pagehead"><div><h1>Registre des transactions</h1>
        <p>Chaque transaction porte l&apos;empreinte de la précédente. Une annulation n&apos;efface
          rien : elle ajoute une écriture inverse, rattachée à celle qu&apos;elle compense — c&apos;est
          ce qui permet d&apos;annuler sans renoncer à l&apos;inaltérabilité.</p></div></div>

      <SimBar />

      <div className="grid g-4" style={{ marginBottom: 16 }}>
        <StatTile label="Écritures au registre" value={nfr(db.txns.length)}
                  note={annulations + " annulation" + (annulations > 1 ? "s" : "")} />
        <StatTile label="État de la chaîne" value={v ? (v.ok ? "Intègre" : "Rompue") : "…"}
                  note={v && v.ok ? "Vérifiée à l'instant" : v ? "Rupture à l'écriture " + v.ref : ""} />
        <StatTile label="Empreinte de tête" value={v && v.head ? v.head : "—"}
                  note="Dernier maillon de la chaîne" />
      </div>

      <section className="card">
        <div className="card__hd"><h3>Contrôle d&apos;inaltérabilité</h3>
          <span className="act">
            <button className="btn" type="button" onClick={() => verifier()}>
              <Icon name="shield" /> Vérifier la chaîne
            </button>
            <button className="btn" type="button" onClick={falsifier}>Simuler une falsification</button>
          </span>
        </div>
        <div className="card__bd">
          {v ? (
            <Note kind={v.ok ? undefined : "warn"} icon={v.ok ? "check" : "alert"}>
              <b>{v.ok ? "Chaîne intègre." : "Rupture détectée à l'écriture " + v.ref + "."}</b>{" "}
              {v.ok
                ? nfr(v.count) + " écritures vérifiées, empreinte de tête " + v.head + "."
                : "Empreinte attendue " + v.expected + ", empreinte stockée " + v.found + "."}
              {msg ? " " + msg : ""}
            </Note>
          ) : null}
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <div className="card__hd"><h3>Dernières écritures</h3></div>
        <div className="tblwrap">
          <table className="tbl">
            <thead><tr>
              <th>Réf.</th><th>Nature</th><th>Date</th><th>Salarié</th><th>Partenaire</th>
              <th className="r">Montant</th><th>Empreinte</th><th></th>
            </tr></thead>
            <tbody>
              {last.map(t => (
                <tr key={t.ref}>
                  <td className="mono">{t.ref}</td>
                  <td>
                    {t.kind === "reversal"
                      ? <Pill kind="crit">Annule {t.reverses}</Pill>
                      : t.reversedBy
                        ? <Pill kind="mute">Annulée par {t.reversedBy}</Pill>
                        : <Pill kind="good">Paiement</Pill>}
                  </td>
                  <td className="num">{dateFR(t.at, true)}</td>
                  <td>{(db.employees.find(e => e.id === t.employeeId) || {}).name || "—"}</td>
                  <td>{(db.partners.find(p => p.id === t.partnerId) || {}).name || "—"}</td>
                  <td className="r num">{t.kind === "reversal" ? "+" : "−"}{eur(t.amount)}</td>
                  <td className="mono" style={{ fontSize: 11.5 }}>{t.hash}</td>
                  <td className="r">
                    {t.kind !== "reversal" && !t.reversedBy ? (
                      <button className="btn btn--ghost" type="button" onClick={() => annuler(t)}>
                        Annuler
                      </button>
                    ) : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

/* ---- API ------------------------------------------------------------------- */
function ApiView() {
  usePageTitle("API");
  const api = useApi();
  const toast = useToast();
  return (
    <>
      <div className="pagehead">
        <div><h1>API</h1>
          <p>Interface REST documentée, échanges en JSON. Chaque geste de l&apos;interface passe par
            l&apos;un de ces points d&apos;entrée : la console en bas de page le montre en direct.</p></div>
        <div className="pagehead__act">
          <a className="btn btn--primary" href="/api-docs/"><Icon name="eye" /> Swagger UI</a>
          <a className="btn" href="/openapi.yaml" download><Icon name="dl" /> openapi.yaml</a>
        </div>
      </div>

      <section className="card">
        <div className="card__hd"><h3>Points d&apos;entrée</h3>
          <span className="sub">base <span className="mono">/api/v1</span></span></div>
        <div className="tblwrap">
          <table className="tbl">
            <thead><tr><th>Méthode</th><th>Chemin</th><th>Rôle</th><th></th></tr></thead>
            <tbody>
              {api.raw.doc.map(([m, p, d]) => (
                <tr key={m + p}>
                  <td><b className="mono">{m}</b></td>
                  <td className="mono">{p}</td>
                  <td style={{ color: "var(--ink-3)" }}>{d}</td>
                  <td className="r">
                    {p.indexOf("{") < 0 && m === "GET" ? (
                      <button className="btn btn--ghost" type="button" onClick={() => {
                        api.get(p).then(() => toast("info", "Appel effectué",
                          "Ouvrez la console API en bas de page pour voir la réponse."));
                      }}>Tester</button>
                    ) : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <div className="grid g-2" style={{ marginTop: 16 }}>
        <section className="card">
          <div className="card__hd"><h3>Exemple — annuler une écriture</h3></div>
          <div className="card__bd">
            <pre className="mono" style={{ margin: 0, fontSize: 12, overflowX: "auto",
                 background: "var(--surface-2)", padding: 12, borderRadius: "var(--r-ctl)",
                 border: "1px solid var(--line)" }}>
{`POST /api/v1/transactions/TRX-000104/cancel
{ "reason": "double encaissement constaté" }

201 Created
{
  "ref": "TRX-000110",
  "kind": "reversal",
  "reverses": "TRX-000104",
  "amount": 4200,
  "currency": "EUR",
  "integrity": { "prev": "9c1f0ab3", "hash": "4d77e2b1" }
}`}
            </pre>
            <div style={{ marginTop: 14 }}>
              <Note>L&apos;écriture d&apos;origine n&apos;est pas modifiée : la réponse est une
                nouvelle écriture, chaînée, qui la compense. Les montants circulent en centimes,
                en nombre entier — aucun arrondi flottant dans une somme d&apos;argent.</Note>
            </div>
          </div>
        </section>
        <section className="card">
          <div className="card__hd"><h3>Sécurité des échanges</h3></div>
          <div className="card__bd" style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {[["HTTPS obligatoire", "Aucun échange en clair ; en production, HSTS et certificat de l'État."],
              ["Jeton à usage unique", "Trente minutes de validité, invalidé dès le premier encaissement."],
              ["Écriture définitive", "Aucune route ne modifie ni ne supprime une transaction ; l'annulation en ajoute une."],
              ["Authentification par rôle", "Salarié, partenaire et administration ont des périmètres disjoints."]
            ].map(([t, d]) => (
              <div key={t} style={{ display: "flex", gap: 11 }}>
                <span style={{ color: "var(--good)", flex: "none" }}><Icon name="check" /></span>
                <div><b style={{ fontSize: 13 }}>{t}</b>
                  <div style={{ fontSize: 12.5, color: "var(--ink-3)" }}>{d}</div></div>
              </div>
            ))}
          </div>
        </section>
      </div>
    </>
  );
}
