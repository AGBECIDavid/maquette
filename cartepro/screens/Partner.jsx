"use client";
/* Espace partenaire : encaissement, recettes, catalogue, compte. */

import { useEffect, useMemo, useState } from "react";
import { Icon } from "../lib/icons.jsx";
import { eur, eurShort, dateFR, heureFR, jourRelatif, centimes } from "../lib/format.js";
import { catIco, catLabel, STATUS } from "../lib/data.js";
import { store } from "../lib/api.js";
import { useApi, useToast, useDB, useSession, useNav, useModal } from "../lib/app.jsx";
import { Pager, Note, Empty, StatTile, ColumnChart, Pill, CopyButton } from "../components/ui.jsx";

const SECTIONS = [
  ["bord",         "chart", "Tableau de bord", "/partenaire"],
  ["encaisser",    "scan",  "Encaisser",       "/partenaire/encaisser"],
  ["transactions", "list",  "Transactions",    "/partenaire/transactions"],
  ["catalogue",    "store", "Catalogue",       "/partenaire/catalogue"],
  ["compte",       "build", "Mon compte",      "/partenaire/compte"]
];

export function PartnerSpace({ section = "bord" }) {
  const session = useSession();
  const { push } = useNav();
  const db = useDB();

  if (!session || session.role !== "partner") {
    return (
      <div className="stage stage--narrow" style={{ paddingTop: 60 }}>
        <div className="card"><div className="card__bd" style={{ textAlign: "center" }}>
          <h2 style={{ marginBottom: 8 }}>Espace réservé</h2>
          <p style={{ color: "var(--ink-3)", marginBottom: 18 }}>
            Connectez-vous avec un compte partenaire pour accéder à cet espace.
          </p>
          <button className="btn btn--primary" type="button" onClick={() => push("/connexion")}>
            Se connecter
          </button>
        </div></div>
      </div>
    );
  }

  const p = session.who;
  return (
    <div className="workspace">
      <aside className="rail">
        <div className="rail__group">
          <p className="rail__label">Espace partenaire</p>
          {SECTIONS.map(([id, ico, label, href]) => (
            <button key={id} className="navitem" type="button" onClick={() => push(href)}
                    aria-current={section === id ? "true" : undefined}>
              <span className="navitem__ico"><Icon name={ico} /></span>{label}
              {id === "encaisser" && db.outbox.length
                ? <span className="navitem__badge">{db.outbox.length}</span> : null}
            </button>
          ))}
        </div>
        <div className="rail__group rail__aside">
          <p className="rail__label">Établissement</p>
          <div style={{ padding: "0 10px" }}>
            <div style={{ fontWeight: 600, fontSize: 13 }}>{p.name}</div>
            <div style={{ fontSize: 11.5, color: "var(--ink-4)", marginBottom: 8 }}>{p.city}</div>
            <Pill kind={STATUS[p.status].pill.replace("pill--", "")}>{STATUS[p.status].label}</Pill>
          </div>
        </div>
      </aside>
      <div className="stage">
        {section === "bord" ? <Bord p={p} />
          : section === "encaisser" ? <Encaisser p={p} />
          : section === "transactions" ? <Transactions p={p} />
          : section === "catalogue" ? <Catalogue />
          : <Compte p={p} />}
      </div>
    </div>
  );
}

/* ---- Tableau de bord ------------------------------------------------------ */
function Bord({ p }) {
  const db = useDB();
  const { push } = useNav();
  const now = Date.now();
  const mine = db.txns.filter(t => t.partnerId === p.id);
  const d0 = new Date(); d0.setHours(0, 0, 0, 0);
  const sum = a => a.reduce((s, t) => s + t.amount, 0);
  const today = mine.filter(t => t.at >= d0.getTime());
  const m30 = mine.filter(t => t.at >= now - 30 * 864e5);
  const m60 = mine.filter(t => t.at >= now - 60 * 864e5 && t.at < now - 30 * 864e5);
  const evol = sum(m60) ? Math.round((sum(m30) - sum(m60)) / sum(m60) * 100) : 0;

  const days = [];
  for (let i = 13; i >= 0; i--) {
    const d = new Date(now - i * 864e5); d.setHours(0, 0, 0, 0);
    const rows = mine.filter(t => t.at >= d.getTime() && t.at < d.getTime() + 864e5);
    days.push({ label: dateFR(d.getTime()), value: sum(rows), count: rows.length,
                tick: i % 3 === 0 ? d.getDate() + "/" + (d.getMonth() + 1) : "" });
  }

  return (
    <>
      <div className="pagehead">
        <div><h1>Tableau de bord</h1>
          <p>Encaissements CartePro de {p.name}. Les montants sont reversés sur le compte de
            l&apos;établissement à J+2 ouvré.</p></div>
        <div className="pagehead__act">
          <button className="btn btn--primary" type="button" onClick={() => push("/partenaire/encaisser")}>
            <Icon name="scan" /> Encaisser
          </button>
        </div>
      </div>

      <div className="grid g-4" style={{ marginBottom: 16 }}>
        <StatTile label="Encaissé aujourd'hui" value={eur(sum(today))}
                  note={today.length + " transaction" + (today.length > 1 ? "s" : "")} />
        <StatTile label="Encaissé sur 30 jours" value={eur(sum(m30))}
                  delta={(evol >= 0 ? "+" : "") + evol + " %"} deltaDir={evol >= 0 ? "up" : "down"}
                  deltaNote="vs 30 jours précédents" />
        <StatTile label="Transactions (30 j)" value={m30.length}
                  spark={days.slice(-12).map(d => d.value / 100)} />
        <StatTile label="Panier moyen"
                  value={m30.length ? eur(Math.round(sum(m30) / m30.length)) : "—"}
                  note="sur les 30 derniers jours" />
      </div>

      <div className="grid g-main">
        <section className="card">
          <div className="card__hd"><h3>Encaissements des 14 derniers jours</h3>
            <span className="sub">en euros</span></div>
          <div className="card__bd">
            <ColumnChart rows={days} height={210} fmtTick={eurShort} fmtPeak={r => eurShort(r.value)}
              aria="Encaissements quotidiens des quatorze derniers jours"
              tip={r => `${r.label}\n${eur(r.value)} · ${r.count} transaction${r.count > 1 ? "s" : ""}`} />
          </div>
        </section>
        <section className="card">
          <div className="card__hd"><h3>Derniers encaissements</h3></div>
          <div className="card__bd" style={{ padding: "8px 0" }}>
            {mine.length ? mine.slice(-6).reverse().map(t => {
              const e = db.employees.find(x => x.id === t.employeeId);
              return (
                <div className="txnrow" key={t.ref} style={{ padding: "9px 18px" }}>
                  <span className="txnrow__ico txnrow__ico--in"><Icon name="down" /></span>
                  <span className="txnrow__m">
                    <span className="txnrow__t" style={{ display: "block" }}>{e ? e.name : "Salarié"}</span>
                    <span className="txnrow__s">
                      {jourRelatif(t.at)} · {heureFR(t.at)} · <span className="mono">{t.ref}</span>
                    </span>
                  </span>
                  <span className="txnrow__a txnrow__a--in num">+{eur(t.amount)}</span>
                </div>
              );
            }) : <Empty icon="wallet">Aucun encaissement</Empty>}
          </div>
          <div className="card__ft">
            Total historique : <b className="num">{eur(sum(mine))}</b> sur {mine.length} transactions
          </div>
        </section>
      </div>
    </>
  );
}

/* ---- Encaisser ------------------------------------------------------------ */
function Encaisser({ p }) {
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const modal = useModal();
  const [scan, setScan] = useState({ token: null, employee: null });
  const [amount, setAmount] = useState("");
  const [scanning, setScanning] = useState(false);

  if (p.status !== "active") {
    return (
      <>
        <div className="pagehead"><div><h1>Encaisser</h1></div></div>
        <div className="card"><div className="card__bd">
          <Note kind="warn">
            <b>Compte {STATUS[p.status].label.toLowerCase()}.</b> Un établissement non actif ne peut
            pas encaisser. La Direction du Numérique et de l&apos;Innovation vous informera des suites
            données à votre dossier.
          </Note>
        </div></div>
      </>
    );
  }

  const resoudre = async token => {
    try {
      const r = await api.raw.get("/payment-tokens/" + token);
      setScan({ token: r.token, employee: r.employee });
      toast("good", "Jeton reconnu", r.employee.name);
    } catch (e) {
      if (e.network) {
        // Hors ligne : le jeton est accepté sur sa présentation et vérifié à la synchronisation.
        setScan({ token, employee: { name: "Salarié (vérification différée)" } });
        toast("info", "Capturé hors ligne", "Le jeton sera vérifié à la reconnexion.");
      } else {
        toast("bad", "Jeton refusé", (e.body && e.body.message) || "Erreur");
      }
    }
  };

  const scanner = async () => {
    setScanning(true);
    await new Promise(r => setTimeout(r, 1200));
    setScanning(false);
    const t = db.tokens.filter(x => !x.usedAt && x.expiresAt > Date.now()).slice(-1)[0];
    if (!t) {
      toast("bad", "Aucun QR détecté", "Demandez au salarié de générer un jeton dans son application.");
      return;
    }
    await resoudre(t.token);
  };

  const saisieManuelle = () => {
    let val = "";
    modal.open("Saisie manuelle du jeton", (
      <label className="field">
        <span className="field__lb">Numéro dicté par le salarié</span>
        <input className="input mono" autoFocus placeholder="CP1|a1b2 c3d4 e5f6 a7b8"
               onChange={e => { val = e.target.value; }} />
        <span className="field__hint">
          Le numéro figure sous le QR code, dans l&apos;application du salarié. Les espaces sont ignorés.
        </span>
      </label>
    ), (
      <>
        <button className="btn" type="button" onClick={modal.close}>Annuler</button>
        <button className="btn btn--primary" type="button" onClick={() => {
          const raw = val.replace(/\s/g, "").replace(/^CP1\|/i, "");
          modal.close();
          if (raw) resoudre(raw);
          else toast("bad", "Jeton vide", "Recopiez le numéro affiché sous le QR code.");
        }}>Valider le jeton</button>
      </>
    ));
  };

  const valider = async () => {
    const cts = centimes(amount);
    if (!cts) { toast("bad", "Montant invalide", "Saisissez un montant supérieur à zéro."); return; }
    const capturedAt = Date.now();
    try {
      const t = await api.raw.post("/transactions",
        { token: scan.token, partnerId: p.id, amount: cts, capturedAt, channel: "qr" });
      setScan({ token: null, employee: null }); setAmount("");
      toast("good", "Encaissement validé", t.ref + " · " + eur(t.amount));
    } catch (e) {
      if (e.network) {
        db.outbox.push({ token: scan.token, amount: cts, capturedAt, partnerId: p.id });
        store.save();
        setScan({ token: null, employee: null }); setAmount("");
        toast("info", "Mis en file d'attente", "Sera transmis dès le retour du réseau.");
      } else {
        toast("bad", "Encaissement refusé", (e.body && e.body.message) || "Erreur");
      }
    }
  };

  const synchroniser = async () => {
    const items = db.outbox.slice();
    db.outbox.length = 0;
    let ok = 0;
    for (const o of items) {
      try {
        await api.raw.post("/transactions", { token: o.token, partnerId: o.partnerId,
          amount: o.amount, capturedAt: o.capturedAt, channel: "offline" });
        ok++;
      } catch (e) {
        o.error = (e.body && e.body.message) || "Échec";
        db.outbox.push(o);
      }
    }
    store.save();
    if (ok) toast("good", "Synchronisation terminée",
      ok + " encaissement" + (ok > 1 ? "s" : "") + " transmis.");
    if (db.outbox.length) toast("bad", "Reste " + db.outbox.length + " en échec", "Voir la file d'attente.");
  };

  return (
    <>
      <div className="pagehead"><div><h1>Encaisser un paiement</h1>
        <p>Scannez le QR code présenté par le salarié, ou saisissez son numéro de jeton si la
          caméra est indisponible.</p></div></div>

      <div className="grid g-main">
        <section className="card"><div className="card__bd">
          {db.degraded ? (
            <div style={{ marginBottom: 16 }}>
              <Note kind="warn" icon="offline">
                <b>Mode dégradé actif.</b> L&apos;encaissement sera capturé localement, puis transmis
                au registre dès le retour du réseau.
              </Note>
            </div>
          ) : null}

          <div className="grid g-2">
            <div>
              <span className="field__lb">1. Jeton du salarié</span>
              {scan.token ? (
                <div className="card" style={{ padding: 14, background: "var(--good-wash)", borderColor: "#c6e8c6" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <span style={{ color: "#0a7a0a" }}><Icon name="check" /></span>
                    <div>
                      <b>{scan.employee.name}</b>
                      <div className="mono" style={{ fontSize: 11.5, color: "var(--ink-3)" }}>
                        CP1|{scan.token}
                      </div>
                    </div>
                  </div>
                </div>
              ) : scanning ? (
                <div className="card" style={{ padding: 20, display: "grid", placeItems: "center", gap: 10 }}>
                  <Icon name="scan" size="26" />
                  <span style={{ fontSize: 13, color: "var(--ink-3)" }}>Recherche d&apos;un QR code…</span>
                </div>
              ) : (
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  <button className="btn btn--primary" type="button" onClick={scanner}>
                    <Icon name="scan" /> Scanner le QR
                  </button>
                  <button className="btn" type="button" onClick={saisieManuelle}>Saisie manuelle</button>
                </div>
              )}
            </div>
            <div>
              <label className="field">
                <span className="field__lb">2. Montant à encaisser</span>
                <input className="input input--big num" inputMode="decimal" placeholder="0,00"
                       value={amount} disabled={!scan.token}
                       onChange={e => setAmount(e.target.value)} />
                <span className="field__hint">En euros. Le solde du salarié est débité immédiatement.</span>
              </label>
            </div>
          </div>

          <hr className="sep" />
          <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
            <button className="btn btn--primary btn--lg" type="button"
                    onClick={valider} disabled={!scan.token}>
              <Icon name="check" /> Valider l&apos;encaissement
            </button>
            <button className="btn btn--ghost" type="button"
                    onClick={() => { setScan({ token: null, employee: null }); setAmount(""); }}>
              Annuler
            </button>
            <span style={{ fontSize: 12, color: "var(--ink-4)", marginLeft: "auto" }}>
              Une transaction validée est définitive (§2.2).
            </span>
          </div>
        </div></section>

        <section className="card">
          <div className="card__hd"><h3>Comment ça marche</h3></div>
          <div className="card__bd" style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            {[["Le salarié génère un QR", "Valable 5 minutes, utilisable une seule fois."],
              ["Vous scannez et saisissez le montant", "Le jeton identifie le salarié, jamais sa carte bancaire."],
              ["La validation débite le solde", "Le salarié voit le nouveau solde à l'instant même."],
              ["L'écriture est définitive", "Chaque transaction est chaînée à la précédente par une empreinte."]
            ].map(([t, d], i) => (
              <div key={t} style={{ display: "flex", gap: 12 }}>
                <span style={{ width: 22, height: 22, borderRadius: "50%", background: "var(--brand-wash)",
                               color: "var(--brand)", display: "grid", placeItems: "center",
                               fontSize: 11.5, fontWeight: 700, flex: "none" }}>{i + 1}</span>
                <div>
                  <b style={{ fontSize: 13 }}>{t}</b>
                  <div style={{ fontSize: 12.5, color: "var(--ink-3)" }}>{d}</div>
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>

      {db.outbox.length ? (
        <section className="card" style={{ marginTop: 16 }}>
          <div className="card__hd">
            <h3>File d&apos;attente hors ligne</h3>
            <span className="sub">
              {db.outbox.length} encaissement{db.outbox.length > 1 ? "s" : ""} capturé
              {db.outbox.length > 1 ? "s" : ""} sans réseau
            </span>
            <span className="act">
              <button className="btn btn--primary" type="button" onClick={synchroniser} disabled={db.degraded}>
                <Icon name="refresh" /> Synchroniser
              </button>
            </span>
          </div>
          <div className="tblwrap">
            <table className="tbl">
              <thead><tr><th>Capturé le</th><th>Jeton</th><th className="r">Montant</th><th>État</th></tr></thead>
              <tbody>
                {db.outbox.map((o, i) => (
                  <tr key={i}>
                    <td className="num">{dateFR(o.capturedAt, true)}</td>
                    <td className="mono">{o.token.slice(0, 10)}…</td>
                    <td className="r num">{eur(o.amount)}</td>
                    <td><Pill kind={o.error ? "crit" : "warn"}>{o.error || "En attente"}</Pill></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="card__ft">
            {db.degraded
              ? "La synchronisation reprendra à la reconnexion. Les jetons restent valides : c'est la date de capture qui fait foi."
              : "Réseau disponible — lancez la synchronisation pour écrire ces opérations au registre."}
          </div>
        </section>
      ) : null}
    </>
  );
}

/* ---- Transactions --------------------------------------------------------- */
function Transactions({ p }) {
  const api = useApi();
  const db = useDB();
  const modal = useModal();
  const [period, setPeriod] = useState(30);
  const [page, setPage] = useState(1);
  const [res, setRes] = useState(null);
  const since = useMemo(() => Date.now() - period * 864e5, [period]);

  useEffect(() => {
    let alive = true;
    api.get("/partners/" + p.id + "/transactions", { since, page, size: 12 })
      .then(r => { if (alive) setRes(r); }).catch(() => {});
    return () => { alive = false; };
  }, [api, p.id, since, page, db.txns.length]);

  const rows = db.txns.filter(t => t.partnerId === p.id && t.at >= since);
  const total = rows.reduce((s, t) => s + t.amount, 0);

  const exporter = () => {
    const csv = ["reference;date;salarie;montant_eur;canal;empreinte"].concat(rows.map(t =>
      [t.ref, new Date(t.at).toISOString(),
       (db.employees.find(e => e.id === t.employeeId) || {}).name || "",
       (t.amount / 100).toFixed(2).replace(".", ","), t.channel, t.hash].join(";"))).join("\n");
    modal.open("Export des transactions (" + rows.length + " lignes)", (
      <>
        <p style={{ fontSize: 13, color: "var(--ink-3)", marginBottom: 10 }}>
          Format CSV, séparateur point-virgule.
        </p>
        <textarea className="textarea mono" readOnly rows={10} value={csv} style={{ fontSize: 11.5 }} />
      </>
    ), (
      <>
        <button className="btn" type="button" onClick={modal.close}>Fermer</button>
        <CopyButton value={csv} label="Copier le CSV" className="btn--primary" />
      </>
    ));
  };

  return (
    <>
      <div className="pagehead">
        <div><h1>Transactions</h1>
          <p>Journal des encaissements. Chaque ligne porte l&apos;empreinte qui la relie à la
            précédente.</p></div>
        <div className="pagehead__act">
          {[7, 30, 90].map(d => (
            <button key={d} className="pgbtn" type="button"
                    aria-current={period === d ? "true" : undefined}
                    onClick={() => { setPeriod(d); setPage(1); }}>{d} j</button>
          ))}
          <button className="btn" type="button" onClick={exporter}><Icon name="dl" /> Exporter</button>
        </div>
      </div>

      <div className="grid g-3" style={{ marginBottom: 16 }}>
        <StatTile label="Encaissé sur la période" value={eur(total)} />
        <StatTile label="Transactions" value={rows.length} />
        <StatTile label="Panier moyen" value={rows.length ? eur(Math.round(total / rows.length)) : "—"} />
      </div>

      <section className="card">
        <div className="tblwrap">
          <table className="tbl">
            <thead><tr>
              <th>Référence</th><th>Date</th><th>Salarié</th><th>Canal</th>
              <th className="r">Montant</th><th>Empreinte</th><th>État</th>
            </tr></thead>
            <tbody>
              {res && res.items.length ? res.items.map(t => (
                <tr key={t.ref}>
                  <td className="mono">{t.ref}</td>
                  <td className="num">{dateFR(new Date(t.at).getTime(), true)}</td>
                  <td>{t.employee ? t.employee.name : "—"}</td>
                  <td>{t.channel === "offline"
                    ? <Pill kind="mute">Hors ligne</Pill> : <Pill kind="info">QR</Pill>}</td>
                  <td className="r num"><b>{eur(t.amount)}</b></td>
                  <td className="mono" style={{ fontSize: 11.5, color: "var(--ink-4)" }}>{t.integrity.hash}</td>
                  <td><Pill kind="good">Validée</Pill></td>
                </tr>
              )) : (
                <tr><td colSpan="7"><Empty icon="list">Aucune transaction sur la période</Empty></td></tr>
              )}
            </tbody>
          </table>
        </div>
        <div className="card__ft"><div className="pager"><Pager meta={res} onPage={setPage} /></div></div>
      </section>
    </>
  );
}

/* ---- Catalogue ------------------------------------------------------------ */
function Catalogue() {
  const api = useApi();
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [res, setRes] = useState(null);

  useEffect(() => {
    let alive = true;
    api.get("/partners", { page, size: 8, query }).then(r => { if (alive) setRes(r); }).catch(() => {});
    return () => { alive = false; };
  }, [api, page, query]);

  return (
    <>
      <div className="pagehead"><div><h1>Catalogue des partenaires</h1>
        <p>Les établissements référencés par le Ministère. La liste est paginée : elle est appelée
          à s&apos;allonger (§3.4).</p></div></div>
      <section className="card">
        <div className="card__hd">
          <input className="input" type="search" placeholder="Rechercher…" style={{ maxWidth: 280 }}
                 value={query} onChange={e => { setQuery(e.target.value); setPage(1); }} />
          <span className="sub">{res ? res.total : 0} établissements actifs</span>
        </div>
        <div className="tblwrap">
          <table className="tbl">
            <thead><tr><th>Établissement</th><th>Catégorie</th><th>Ville</th><th>Région</th></tr></thead>
            <tbody>
              {res && res.items.map(p => (
                <tr key={p.id}>
                  <td><b>{p.name}</b>
                    <div style={{ fontSize: 11.5, color: "var(--ink-4)" }}>{p.address}</div></td>
                  <td>{p.categoryLabel}</td>
                  <td>{p.city}</td>
                  <td style={{ color: "var(--ink-3)" }}>{p.region}</td>
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

/* ---- Compte --------------------------------------------------------------- */
function Compte({ p }) {
  const api = useApi();
  const db = useDB();
  const [full, setFull] = useState(null);
  useEffect(() => {
    let alive = true;
    api.get("/partners/" + p.id).then(r => { if (alive) setFull(r); }).catch(() => {});
    return () => { alive = false; };
  }, [api, p.id, db.txns.length, p.status]);

  const line = (k, v) => (
    <div key={k} style={{ display: "flex", gap: 16, padding: "9px 0", borderBottom: "1px solid var(--line)" }}>
      <span style={{ color: "var(--ink-3)", minWidth: 150 }}>{k}</span><span>{v}</span>
    </div>
  );

  return (
    <>
      <div className="pagehead"><div><h1>Mon compte</h1>
        <p>Coordonnées de l&apos;établissement et état de votre référencement.</p></div></div>

      {p.status === "pending" ? (
        <div style={{ marginBottom: 16 }}>
          <Note kind="warn">
            <b>Demande en cours d&apos;instruction.</b> Votre adhésion a été transmise à la Direction
            du Numérique et de l&apos;Innovation. Aucun encaissement n&apos;est possible avant sa
            validation (§2.2).
          </Note>
        </div>
      ) : null}

      <div className="grid g-main">
        <section className="card">
          <div className="card__hd"><h3>{p.name}</h3>
            <span className="act">
              <Pill kind={STATUS[p.status].pill.replace("pill--", "")}>{STATUS[p.status].label}</Pill>
            </span>
          </div>
          <div className="card__bd" style={{ paddingTop: 4 }}>
            {line("Identifiant", <span className="mono">{p.id}</span>)}
            {line("Catégorie", catLabel(p.category))}
            {line("Adresse", (p.address ? p.address + ", " : "") + p.city)}
            {line("Région", p.region)}
            {line("SIRET", <span className="mono">{p.siret || "—"}</span>)}
            {line("Contact", p.contact)}
            {line("IBAN de reversement", <span className="mono">{p.iban || "—"}</span>)}
            {line("Référencé depuis", dateFR(p.createdAt))}
            {full ? line("Encaissements",
              <span><b>{eur(full.totals.amount)}</b> sur {full.totals.count} transactions</span>) : null}
          </div>
        </section>

        <section className="card">
          <div className="card__hd"><h3>Reversements</h3></div>
          <div className="card__bd">
            <Note>
              Les encaissements CartePro sont reversés sur l&apos;IBAN de l&apos;établissement à J+2
              ouvré, par virement groupé quotidien. Le détail des lignes est exportable depuis
              l&apos;onglet Transactions.
            </Note>
            <div style={{ marginTop: 14, fontSize: 13, color: "var(--ink-3)" }}>
              Pour modifier vos coordonnées bancaires, adressez une demande écrite à la Direction du
              Numérique et de l&apos;Innovation ; la modification prend effet après vérification.
            </div>
          </div>
        </section>
      </div>
    </>
  );
}
