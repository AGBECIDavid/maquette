"use client";
/* Espace salarié : solde, paiement par QR, historique, partenaires et
   réclamations adressées à l'administration. */

import { useEffect, useMemo, useRef, useState } from "react";
import { Icon } from "../lib/icons.jsx";
import { draw as drawQR } from "../lib/qr.js";
import { eur, dateFR, heureFR, jourRelatif, ilYA, pad, initiales, MOIS } from "../lib/format.js";
import { catIco, catLabel, CATEGORIES, CLAIM_STATUS, CLAIM_CATEGORIES } from "../lib/data.js";
import { useApi, useToast, useDB, useSession, useNav, useBus, useModal } from "../lib/app.jsx";
import { Pager, Note, Empty, CopyButton, Pill } from "../components/ui.jsx";

const SECTIONS = [
  ["accueil",     "home",   "Accueil",      "/salarie"],
  ["payer",       "qr",     "Payer",        "/salarie/payer"],
  ["historique",  "clock",  "Historique",   "/salarie/historique"],
  ["partenaires", "pin",    "Partenaires",  "/salarie/partenaires"],
  ["demandes",    "chat",   "Mes demandes", "/salarie/demandes"]
];

export function EmployeeSpace({ section = "accueil" }) {
  const session = useSession();
  const { push } = useNav();
  const db = useDB();

  if (!session || session.role !== "employee") {
    return <NotConnected push={push} />;
  }
  const me = session.who;
  const ouvertes = db.claims.filter(c => c.employeeId === me.id
    && (c.status === "open" || c.status === "in_progress")).length;

  return (
    <div className="workspace">
      <aside className="rail">
        <div className="rail__group">
          <p className="rail__label">Espace salarié</p>
          {SECTIONS.map(([id, ico, label, href]) => (
            <button key={id} className="navitem" type="button" onClick={() => push(href)}
                    aria-current={section === id ? "true" : undefined}>
              <span className="navitem__ico"><Icon name={ico} /></span>
              {label}
              {id === "demandes" && ouvertes ? <span className="navitem__badge">{ouvertes}</span> : null}
            </button>
          ))}
        </div>
        <div className="rail__group rail__aside">
          <p className="rail__label">Compte</p>
          <div style={{ padding: "0 10px" }}>
            <div style={{ fontWeight: 600, fontSize: 13 }}>{me.name}</div>
            <div style={{ fontSize: 11.5, color: "var(--ink-4)", marginBottom: 8 }}>
              {(db.employers.find(x => x.id === me.employerId) || {}).name}
            </div>
            <Pill kind={me.status === "active" ? "good" : "crit"}>
              {me.status === "active" ? "Actif" : "Suspendu"}
            </Pill>
          </div>
        </div>
      </aside>

      <div className="stage stage--narrow">
        {me.status !== "active" ? (
          <div style={{ marginBottom: 18 }}>
            <Note kind="warn">
              <b>Compte suspendu.</b> Vous ne pouvez plus générer de QR code de paiement.
              Ouvrez une demande depuis « Mes demandes » pour joindre l&apos;administration.
            </Note>
          </div>
        ) : null}
        {section === "accueil" ? <Accueil me={me} />
          : section === "payer" ? <Payer me={me} />
          : section === "historique" ? <Historique me={me} />
          : section === "partenaires" ? <Partenaires />
          : <Demandes me={me} />}
      </div>
    </div>
  );
}

function NotConnected({ push }) {
  return (
    <div className="stage stage--narrow" style={{ paddingTop: 60 }}>
      <div className="card"><div className="card__bd" style={{ textAlign: "center" }}>
        <h2 style={{ marginBottom: 8 }}>Espace réservé</h2>
        <p style={{ color: "var(--ink-3)", marginBottom: 18 }}>
          Connectez-vous avec un compte salarié pour accéder à cet espace.
        </p>
        <button className="btn btn--primary" type="button" onClick={() => push("/connexion")}>
          Se connecter
        </button>
      </div></div>
    </div>
  );
}

/* ---- Accueil -------------------------------------------------------------- */
function Accueil({ me }) {
  const db = useDB();
  const { push } = useNav();
  const mine = db.txns.filter(t => t.employeeId === me.id);
  const last = mine.slice(-4).reverse();
  const lastTop = db.topups.filter(t => t.employeeId === me.id).sort((a, b) => b.at - a.at)[0];
  const moisCourant = mine.filter(t => new Date(t.at).getMonth() === new Date().getMonth())
    .reduce((s, t) => s + t.amount, 0);
  const claim = db.claims.find(c => c.employeeId === me.id && (c.status === "open" || c.status === "in_progress"));

  return (
    <>
      <div className="pagehead"><div><h1>Bonjour {me.name.split(" ")[0]}</h1>
        <p>Votre budget CartePro et vos dernières opérations.</p></div></div>

      <div className="paycard">
        <div className="paycard__top">
          <div>
            <div className="paycard__brand">CartePro</div>
            <div className="paycard__min">Ministère du Job et Bonheur</div>
          </div>
          <div className="paycard__chip" aria-hidden="true" />
        </div>
        <div className="paycard__bal">
          <div className="lb">Solde disponible</div>
          <div className="v num">{eur(me.balance)}</div>
        </div>
        <div className="paycard__foot">
          <span className="mono num">{me.id.replace("SAL-", "4021 ")} 88</span>
          <span style={{ marginLeft: "auto" }}>
            {(db.employers.find(x => x.id === me.employerId) || {}).name}
          </span>
        </div>
      </div>

      <div className="qbtns">
        <button className="qbtn" type="button" onClick={() => push("/salarie/payer")}>
          <Icon name="qr" />Payer</button>
        <button className="qbtn" type="button" onClick={() => push("/salarie/historique")}>
          <Icon name="clock" />Historique</button>
        <button className="qbtn" type="button" onClick={() => push("/salarie/partenaires")}>
          <Icon name="pin" />Partenaires</button>
      </div>

      <div className="grid g-2" style={{ marginTop: 16 }}>
        <div className="card stat">
          <div className="stat__lb">Dépensé ce mois</div>
          <div className="stat__v num" style={{ fontSize: 22 }}>{eur(moisCourant)}</div>
        </div>
        <div className="card stat">
          <div className="stat__lb">Dernier crédit reçu</div>
          <div className="stat__v num" style={{ fontSize: 22 }}>{lastTop ? eur(lastTop.amount) : "—"}</div>
          {lastTop ? (
            <div className="stat__d">
              {lastTop.kind === "regularisation" ? "Régularisation" : lastTop.label} · {dateFR(lastTop.at)}
            </div>
          ) : null}
        </div>
      </div>

      {claim ? (
        <div style={{ marginTop: 16 }}>
          <button className="card claimrow" type="button" style={{ width: "100%", borderRadius: "var(--r-card)" }}
                  onClick={() => push("/salarie/demandes")}>
            <span className="txnrow__ico"><Icon name="chat" /></span>
            <span className="claimrow__m">
              <span className="claimrow__t">{claim.subject}</span>
              <span className="claimrow__s">
                Demande {claim.id} · {CLAIM_STATUS[claim.status].label.toLowerCase()} · {ilYA(claim.updatedAt)}
              </span>
            </span>
            <Icon name="right" />
          </button>
        </div>
      ) : null}

      <h3 style={{ fontSize: 13, margin: "22px 0 4px" }}>Dernières opérations</h3>
      {last.length ? last.map(t => <TxnRow key={t.ref} t={t} />)
                   : <Empty icon="clock">Aucune opération pour l&apos;instant</Empty>}
      <button className="btn btn--ghost btn--block" type="button" style={{ marginTop: 10 }}
              onClick={() => push("/salarie/historique")}>
        Tout l&apos;historique
      </button>
    </>
  );
}

function TxnRow({ t, onClick }) {
  const db = useDB();
  const p = db.partners.find(x => x.id === t.partnerId);
  const Tag = onClick ? "button" : "div";
  return (
    <Tag className={"txnrow" + (onClick ? " txnrow--act" : "")} onClick={onClick} type={onClick ? "button" : undefined}>
      <span className="txnrow__ico"><Icon name={catIco(p ? p.category : "store")} /></span>
      <span className="txnrow__m">
        <span className="txnrow__t" style={{ display: "block" }}>{p ? p.name : "Partenaire"}</span>
        <span className="txnrow__s">{jourRelatif(t.at)} · {heureFR(t.at)} · {t.ref}</span>
      </span>
      <span className="txnrow__a num">−{eur(t.amount)}</span>
    </Tag>
  );
}

/* ---- Payer ---------------------------------------------------------------- */
function Payer({ me }) {
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const [tok, setTok] = useState(null);
  const [paid, setPaid] = useState(null);
  const [left, setLeft] = useState(0);
  const canvas = useRef(null);

  const live = tok && left > 0;

  useEffect(() => {
    if (!tok) return;
    const tick = () => setLeft(Math.max(0, tok.expiresAt - Date.now()));
    tick();
    const i = setInterval(tick, 500);
    return () => clearInterval(i);
  }, [tok]);

  useEffect(() => {
    if (!live || !canvas.current) return;
    try { drawQR(canvas.current, "CP1|" + tok.token, 236); }
    catch (e) { toast("bad", "QR indisponible", e.message); }
  }, [live, tok, toast]);

  useBus("txn", useMemo(() => d => {
    if (!tok || d.employee.id !== me.id) return;
    const used = db.tokens.find(t => t.token === tok.token && t.usedAt);
    if (!used) return;
    setPaid({ amount: d.txn.amount, ref: d.txn.ref, hash: d.txn.hash, partner: d.partner.name });
    setTok(null);
  }, [tok, me.id, db.tokens]));

  const emettre = async () => {
    try {
      const t = await api.post("/payment-tokens", { employeeId: me.id });
      setTok(t); setPaid(null);
      toast("info", "Jeton émis", "Valable 5 minutes, un seul encaissement.");
    } catch (e) { /* message déjà affiché */ }
  };

  if (paid) {
    return (
      <>
        <div className="pagehead"><div><h1>Paiement accepté</h1></div></div>
        <div className="card"><div className="card__bd">
          <div className="paid">
            <div className="paid__mark"><Icon name="check" /></div>
            <div>
              <div className="num" style={{ fontSize: 32, fontWeight: 600 }}>−{eur(paid.amount)}</div>
              <div style={{ color: "var(--ink-3)", marginTop: 4 }}>{paid.partner}</div>
            </div>
            <div style={{ width: "100%", textAlign: "left", borderTop: "1px solid var(--line)", paddingTop: 12 }}>
              <Ligne k="Référence" v={<span className="mono">{paid.ref}</span>} />
              <Ligne k="Nouveau solde" v={<b className="num">{eur(me.balance)}</b>} />
              <Ligne k="Empreinte" v={<span className="mono" style={{ fontSize: 11 }}>{paid.hash}</span>} />
            </div>
            <p style={{ fontSize: 12, color: "var(--ink-4)", maxWidth: "34ch" }}>
              Cette opération est définitive : elle ne peut être ni modifiée ni annulée.
            </p>
            <button className="btn btn--primary btn--lg" type="button" onClick={() => setPaid(null)}>
              Terminer
            </button>
          </div>
        </div></div>
      </>
    );
  }

  const mm = Math.floor(left / 60000), ss = Math.floor(left / 1000) % 60;

  return (
    <>
      <div className="pagehead"><div><h1>Payer</h1>
        <p>Présentez ce code au partenaire. Il saisit le montant, vous êtes débité à la validation.</p></div></div>

      {db.degraded ? (
        <div style={{ marginBottom: 14 }}>
          <Note kind="warn" icon="offline">
            <b>Mode dégradé.</b> Le jeton est produit par l&apos;application à partir de la réserve
            pré-provisionnée. Il reste présentable ; le partenaire l&apos;encaissera puis synchronisera.
          </Note>
        </div>
      ) : null}

      <div className="card"><div className="card__bd">
        <div className="qrstage">
          <div className={"qrframe" + (live ? "" : " qrframe--dead")}>
            <canvas ref={canvas} width="236" height="236" role="img"
                    aria-label="QR code de paiement à présenter au partenaire" />
            {!live ? (
              <div className="qrframe__over">
                <div>
                  <div style={{ fontWeight: 600, marginBottom: 6 }}>
                    {tok ? "Jeton expiré" : "Aucun jeton actif"}
                  </div>
                  <div style={{ fontSize: 12, color: "var(--ink-3)" }}>
                    Générez un QR code au moment de payer.
                  </div>
                </div>
              </div>
            ) : null}
          </div>

          {live ? (
            <div className="qrtimer">
              <svg className="qrtimer__ring" viewBox="0 0 36 36" aria-hidden="true">
                <circle cx="18" cy="18" r="15" fill="none" stroke="var(--surface-3)" strokeWidth="3" />
                <circle cx="18" cy="18" r="15" fill="none" stroke="var(--brand)" strokeWidth="3"
                        strokeLinecap="round" transform="rotate(-90 18 18)"
                        strokeDasharray="94.2" strokeDashoffset={94.2 * (1 - left / 300000)} />
              </svg>
              <div style={{ textAlign: "left" }}>
                <div className="qrtimer__t">{mm}:{pad(ss)}</div>
                <div className="qrtimer__s">avant expiration · usage unique</div>
              </div>
            </div>
          ) : null}

          {tok ? (
            <div className="tokenbox">
              <div className="tokenbox__lb">
                Numéro du jeton — à dicter si la caméra du partenaire ne répond pas
              </div>
              <div className="tokenbox__row">
                <div className="tokenbox__v mono">
                  <span className="tokenbox__pfx">CP1|</span>
                  {tok.token.match(/.{1,4}/g).map((g, i) => <span key={i}>{g}</span>)}
                </div>
                <CopyButton className="tokenbox__copy" value={"CP1|" + tok.token} label="Copier" />
              </div>
            </div>
          ) : null}

          <button className={"btn btn--lg btn--block " + (live ? "" : "btn--primary")} type="button"
                  style={{ marginTop: 16 }} onClick={emettre}>
            {live ? "Régénérer un jeton" : "Générer un QR code de paiement"}
          </button>
        </div>
      </div></div>
    </>
  );
}

const Ligne = ({ k, v }) => (
  <div style={{ display: "flex", gap: 12, padding: "5px 0", fontSize: 12.5 }}>
    <span style={{ color: "var(--ink-4)" }}>{k}</span>
    <span style={{ marginLeft: "auto" }}>{v}</span>
  </div>
);

/* ---- Historique ----------------------------------------------------------- */
function Historique({ me }) {
  const api = useApi();
  const db = useDB();
  const modal = useModal();
  const { push } = useNav();
  const [month, setMonth] = useState("");
  const [page, setPage] = useState(1);
  const [res, setRes] = useState(null);

  useEffect(() => {
    let alive = true;
    api.get("/employees/" + me.id + "/transactions", { page, size: 8, month })
      .then(r => { if (alive) setRes(r); }).catch(() => {});
    return () => { alive = false; };
  }, [api, me.id, page, month, db.txns.length]);

  const mois = [];
  for (let i = 0; i < 4; i++) {
    const d = new Date(); d.setDate(1); d.setMonth(d.getMonth() - i);
    mois.push({ v: d.toISOString().slice(0, 7), lb: MOIS[d.getMonth()] + " " + String(d.getFullYear()).slice(2) });
  }

  const detail = t => modal.open("Opération " + t.ref, (
    <>
      <div style={{ display: "flex", gap: 14, alignItems: "center", marginBottom: 14 }}>
        <span className="pitem__ico" style={{ width: 46, height: 46 }}>
          <Icon name={catIco(t.partner ? t.partner.category : "store")} />
        </span>
        <div>
          <div style={{ fontWeight: 600, fontSize: 15 }}>{t.partner ? t.partner.name : "—"}</div>
          <div style={{ color: "var(--ink-3)", fontSize: 13 }}>
            {t.partner ? t.partner.city : ""} · {dateFR(new Date(t.at).getTime(), true)}
          </div>
        </div>
        <div className="num" style={{ marginLeft: "auto", fontSize: 20, fontWeight: 600 }}>
          −{eur(t.amount)}
        </div>
      </div>
      <Ligne k="Référence" v={<span className="mono">{t.ref}</span>} />
      <Ligne k="Canal" v={t.channel === "offline" ? "Encaissement hors ligne" : "QR code"} />
      <Ligne k="Empreinte" v={<span className="mono" style={{ fontSize: 11 }}>{t.integrity.hash}</span>} />
      <Ligne k="Empreinte précédente" v={<span className="mono" style={{ fontSize: 11 }}>{t.integrity.prev}</span>} />
      <div style={{ marginTop: 14 }}>
        <Note>Une opération validée est définitive. Si elle vous paraît erronée, ouvrez une
          réclamation : un agent l&apos;instruira et pourra procéder à une régularisation.</Note>
      </div>
    </>
  ), (
    <>
      <button className="btn" type="button" onClick={modal.close}>Fermer</button>
      <button className="btn btn--primary" type="button"
              onClick={() => { modal.close(); push("/salarie/demandes?txn=" + t.ref); }}>
        Contester cette opération
      </button>
    </>
  ));

  const total = res ? res.items.reduce((s, t) => s + t.amount, 0) : 0;

  return (
    <>
      <div className="pagehead"><div><h1>Historique</h1>
        <p>Toutes vos opérations, du plus récent au plus ancien.</p></div></div>

      <div className="chips" style={{ marginBottom: 12 }}>
        <button className="pgbtn" type="button" aria-current={!month ? "true" : undefined}
                onClick={() => { setMonth(""); setPage(1); }}>Tout</button>
        {mois.map(m => (
          <button key={m.v} className="pgbtn" type="button"
                  aria-current={month === m.v ? "true" : undefined}
                  onClick={() => { setMonth(m.v); setPage(1); }}>{m.lb}</button>
        ))}
      </div>

      <div className="card" style={{ padding: "12px 14px", marginBottom: 6, display: "flex", alignItems: "baseline" }}>
        <span style={{ fontSize: 12, color: "var(--ink-3)" }}>
          {res ? res.total : 0} opération{res && res.total > 1 ? "s" : ""}
        </span>
        <b className="num" style={{ marginLeft: "auto" }}>{eur(total)}</b>
        <span style={{ fontSize: 11, color: "var(--ink-4)", marginLeft: 6 }}>sur cette page</span>
      </div>

      {res && res.items.length ? res.items.map(t => (
        <button key={t.ref} className="txnrow txnrow--act" type="button" onClick={() => detail(t)}>
          <span className="txnrow__ico"><Icon name={catIco(t.partner ? t.partner.category : "store")} /></span>
          <span className="txnrow__m">
            <span className="txnrow__t" style={{ display: "block" }}>{t.partner ? t.partner.name : "—"}</span>
            <span className="txnrow__s">{dateFR(new Date(t.at).getTime())} · {t.ref}</span>
          </span>
          <span className="txnrow__a num">−{eur(t.amount)}</span>
        </button>
      )) : <Empty icon="clock">Aucune opération sur cette période</Empty>}

      <div className="pager" style={{ marginTop: 14 }}>
        <Pager meta={res} onPage={setPage} />
      </div>
    </>
  );
}

/* ---- Partenaires ---------------------------------------------------------- */
function Partenaires() {
  const api = useApi();
  const modal = useModal();
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("");
  const [page, setPage] = useState(1);
  const [res, setRes] = useState(null);
  const [all, setAll] = useState([]);

  useEffect(() => {
    let alive = true;
    api.get("/partners", { page, size: 6, query, category })
      .then(r => { if (alive) setRes(r); }).catch(() => {});
    return () => { alive = false; };
  }, [api, page, query, category]);

  useEffect(() => {
    let alive = true;
    api.get("/partners", { size: 100 }).then(r => { if (alive) setAll(r.items); }).catch(() => {});
    return () => { alive = false; };
  }, [api]);

  const fiche = async id => {
    const p = await api.get("/partners/" + id);
    modal.open(p.name, (
      <>
        <div style={{ display: "flex", gap: 14, alignItems: "flex-start" }}>
          <span className="pitem__ico" style={{ width: 46, height: 46 }}><Icon name={catIco(p.category)} /></span>
          <div>
            <div style={{ fontWeight: 600 }}>{p.categoryLabel}</div>
            <div style={{ color: "var(--ink-3)", fontSize: 13 }}>{p.address}, {p.city}</div>
            <div style={{ marginTop: 8 }}><Pill kind="good">Actif</Pill></div>
          </div>
        </div>
        <hr className="sep" />
        <Note>Présentez votre QR code CartePro en caisse. Le partenaire saisit le montant,
          vous voyez le débit immédiatement.</Note>
      </>
    ), <button className="btn" type="button" onClick={modal.close}>Fermer</button>);
  };

  return (
    <>
      <div className="pagehead"><div><h1>Partenaires</h1>
        <p>Les établissements où votre budget CartePro est accepté.</p></div></div>

      <label className="field">
        <span className="vh">Rechercher un partenaire</span>
        <input className="input" type="search" placeholder="Rechercher un partenaire, une ville…"
               value={query} onChange={e => { setQuery(e.target.value); setPage(1); }} />
      </label>

      <div className="chips" style={{ marginBottom: 12 }}>
        <button className="pgbtn" type="button" aria-current={!category ? "true" : undefined}
                onClick={() => { setCategory(""); setPage(1); }}>Toutes</button>
        {CATEGORIES.map(c => (
          <button key={c.id} className="pgbtn" type="button"
                  aria-current={category === c.id ? "true" : undefined}
                  onClick={() => { setCategory(c.id); setPage(1); }}>{c.label}</button>
        ))}
      </div>

      <Plan items={all} onPick={fiche} />

      <div style={{ marginTop: 6 }}>
        {res && res.items.length ? res.items.map(p => (
          <button key={p.id} className="pitem" type="button" onClick={() => fiche(p.id)}>
            <span className="pitem__ico"><Icon name={catIco(p.category)} /></span>
            <span className="pitem__m">
              <span className="pitem__t" style={{ display: "block" }}>{p.name}</span>
              <span className="pitem__s">{p.categoryLabel} · {p.city}</span>
            </span>
            <span className="pitem__d">{(0.3 + p.x + p.y).toFixed(1)} km</span>
          </button>
        )) : <Empty icon="pin">Aucun partenaire ne correspond</Empty>}
      </div>

      <div className="pager" style={{ marginTop: 14 }}>
        <Pager meta={res} onPage={setPage} />
      </div>
    </>
  );
}

/* Fond de plan schématique : le démonstrateur n'embarque pas de service
   cartographique, mais la fonction « localiser un partenaire » doit être
   démontrable. Les rues sont dessinées, les positions sont réelles. */
function Plan({ items, onPick }) {
  const rues = [[0, 14, 100, 20], [0, 38, 100, 31], [0, 52, 100, 58],
                [18, 0, 26, 62], [52, 0, 46, 62], [76, 0, 84, 62]];
  return (
    <div className="mapbox">
      <svg viewBox="0 0 100 62" role="img" aria-label="Plan des partenaires référencés">
        <rect width="100" height="62" fill="#e9eef7" />
        <rect x="6" y="20" width="20" height="14" rx="2" fill="#dcecdd" />
        <rect x="62" y="6" width="26" height="10" rx="2" fill="#dcecdd" />
        <path d="M0 46 C 20 42, 30 54, 52 50 S 84 40, 100 44" fill="none" stroke="#cfe0f3" strokeWidth="4" />
        {rues.map((s, i) => (
          <line key={i} x1={s[0]} y1={s[1]} x2={s[2]} y2={s[3]} stroke="#fff" strokeWidth="2.4" />
        ))}
        {items.map(p => {
          const x = 6 + p.x * 88, y = 5 + p.y * 52;
          return (
            <g key={p.id} style={{ cursor: "pointer" }} onClick={() => onPick(p.id)}
               data-tip={p.name + " — " + p.city}>
              <circle cx={x} cy={y} r="4.5" fill="transparent" />
              <circle cx={x} cy={y} r="2.6" fill="#000091" stroke="#fff" strokeWidth="1" />
            </g>
          );
        })}
      </svg>
      <div className="maplegend">{items.length} partenaires référencés</div>
    </div>
  );
}

/* ---- Réclamations : le fil avec l'administration -------------------------- */
function Demandes({ me }) {
  const api = useApi();
  const toast = useToast();
  const db = useDB();
  const { path } = useNav();
  const [open, setOpen] = useState(null);
  const [form, setForm] = useState(null);
  const [reply, setReply] = useState("");

  const txnParam = useMemo(() => {
    const i = String(path || "").indexOf("txn=");
    return i < 0 ? "" : String(path).slice(i + 4);
  }, [path]);

  useEffect(() => {
    if (txnParam) setForm({ category: "operation", subject: "Opération contestée " + txnParam,
                            body: "", txnRef: txnParam });
  }, [txnParam]);

  const mine = db.claims.filter(c => c.employeeId === me.id)
    .slice().sort((a, b) => b.updatedAt - a.updatedAt);
  const courant = open ? db.claims.find(c => c.id === open) : null;

  const envoyer = async () => {
    if (!form.subject.trim() || !form.body.trim()) {
      toast("bad", "Formulaire incomplet", "Précisez l'objet et la description.");
      return;
    }
    try {
      const c = await api.post("/claims", { employeeId: me.id, ...form });
      setForm(null); setOpen(c.id);
      toast("good", "Demande transmise", c.id + " — un agent vous répondra dans cet espace.");
    } catch (e) { /* message déjà affiché */ }
  };

  const repondre = async () => {
    if (!reply.trim()) return;
    try {
      await api.post("/claims/" + courant.id + "/messages",
        { from: "employee", author: me.name, body: reply });
      setReply("");
    } catch (e) { /* message déjà affiché */ }
  };

  if (courant) {
    return (
      <>
        <div className="pagehead">
          <div>
            <button className="btn btn--ghost" type="button" onClick={() => setOpen(null)}
                    style={{ marginBottom: 8 }}>
              <Icon name="left" /> Toutes mes demandes
            </button>
            <h1>{courant.subject}</h1>
            <p>{courant.id} · ouverte le {dateFR(courant.createdAt)} ·{" "}
              {CLAIM_CATEGORIES.find(c => c.id === courant.category)?.label}</p>
          </div>
          <div className="pagehead__act">
            <Pill kind={CLAIM_STATUS[courant.status].pill.replace("pill--", "")}>
              {CLAIM_STATUS[courant.status].label}
            </Pill>
          </div>
        </div>

        {courant.resolution ? (
          <div style={{ marginBottom: 16 }}>
            <Note kind="good" icon="check">
              <b>Régularisation de {eur(courant.resolution.amount)}</b> créditée sur votre solde
              le {dateFR(courant.resolution.at)} par {courant.resolution.by}.
            </Note>
          </div>
        ) : null}

        <div className="card"><div className="card__bd">
          <Fil messages={courant.messages} />
          {courant.status === "resolved" || courant.status === "rejected" ? (
            <div style={{ marginTop: 18 }}>
              <Note>Cette demande est clôturée. Ouvrez-en une nouvelle si le problème persiste.</Note>
            </div>
          ) : (
            <div style={{ marginTop: 18, borderTop: "1px solid var(--line)", paddingTop: 16 }}>
              <label className="field">
                <span className="field__lb">Répondre à l&apos;administration</span>
                <textarea className="textarea" value={reply} onChange={e => setReply(e.target.value)}
                          placeholder="Votre message…" />
              </label>
              <button className="btn btn--primary" type="button" onClick={repondre} disabled={!reply.trim()}>
                <Icon name="arrow" /> Envoyer
              </button>
            </div>
          )}
        </div></div>
      </>
    );
  }

  if (form) {
    return (
      <>
        <div className="pagehead"><div>
          <button className="btn btn--ghost" type="button" onClick={() => setForm(null)}
                  style={{ marginBottom: 8 }}>
            <Icon name="left" /> Annuler
          </button>
          <h1>Nouvelle demande</h1>
          <p>Un agent du Ministère instruit votre dossier et vous répond dans cet espace.</p>
        </div></div>

        <div className="card"><div className="card__bd">
          <label className="field">
            <span className="field__lb">Motif</span>
            <select className="select" value={form.category}
                    onChange={e => setForm(f => ({ ...f, category: e.target.value }))}>
              {CLAIM_CATEGORIES.map(c => <option key={c.id} value={c.id}>{c.label}</option>)}
            </select>
          </label>
          <label className="field">
            <span className="field__lb">Objet</span>
            <input className="input" value={form.subject}
                   onChange={e => setForm(f => ({ ...f, subject: e.target.value }))}
                   placeholder="Résumez votre demande en une ligne" />
          </label>
          {form.txnRef ? (
            <label className="field">
              <span className="field__lb">Opération concernée</span>
              <input className="input mono" value={form.txnRef} readOnly />
            </label>
          ) : null}
          <label className="field">
            <span className="field__lb">Description</span>
            <textarea className="textarea" value={form.body}
                      onChange={e => setForm(f => ({ ...f, body: e.target.value }))}
                      placeholder="Décrivez ce qui s'est passé, avec les dates et les montants." />
          </label>
          <button className="btn btn--primary btn--lg btn--block" type="button" onClick={envoyer}>
            Transmettre ma demande
          </button>
        </div></div>
      </>
    );
  }

  return (
    <>
      <div className="pagehead">
        <div><h1>Mes demandes</h1>
          <p>Vos échanges avec l&apos;administration : contestation d&apos;une opération, solde,
            accès au compte.</p></div>
        <div className="pagehead__act">
          <button className="btn btn--primary" type="button"
                  onClick={() => setForm({ category: "operation", subject: "", body: "", txnRef: "" })}>
            <Icon name="plus" /> Nouvelle demande
          </button>
        </div>
      </div>

      <div className="card">
        {mine.length ? mine.map(c => (
          <button key={c.id} className="claimrow" type="button" onClick={() => setOpen(c.id)}>
            <span className="txnrow__ico"><Icon name="chat" /></span>
            <span className="claimrow__m">
              <span className="claimrow__t" style={{ display: "block" }}>{c.subject}</span>
              <span className="claimrow__s" style={{ display: "block" }}>
                {c.id} · {c.messages.length} message{c.messages.length > 1 ? "s" : ""} ·
                {" "}dernière activité {ilYA(c.updatedAt)}
              </span>
            </span>
            <Pill kind={CLAIM_STATUS[c.status].pill.replace("pill--", "")}>
              {CLAIM_STATUS[c.status].label}
            </Pill>
          </button>
        )) : (
          <Empty icon="chat">
            Aucune demande. Vous pouvez saisir l&apos;administration depuis une opération de
            votre historique, ou ouvrir une demande libre.
          </Empty>
        )}
      </div>
    </>
  );
}

export function Fil({ messages }) {
  return (
    <div className="thread">
      {messages.map((m, i) => (
        <div key={i} className={"msg msg--" + m.from}>
          <span className="msg__av">{initiales(m.author)}</span>
          <div>
            <div className="msg__b">{m.body}</div>
            <div className="msg__meta">
              {m.author} · {m.from === "admin" ? "Administration" : "Salarié"} · {ilYA(m.at)}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
