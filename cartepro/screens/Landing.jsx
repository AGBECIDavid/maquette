"use client";
/* Page publique : écran d'ouverture animé, présentation du dispositif, le
   Choix du Ministre, et les deux portes d'entrée — connexion et inscription. */

import { useEffect, useState } from "react";
import { Icon } from "../lib/icons.jsx";
import { useNav, useDB } from "../lib/app.jsx";
import { eur, nfr } from "../lib/format.js";
import { catIco, catLabel } from "../lib/data.js";

export function Splash({ onDone }) {
  useEffect(() => {
    const t = setTimeout(onDone, 2600);
    return () => clearTimeout(t);
  }, [onDone]);
  return (
    <div className="splash" role="status" aria-label="Chargement de CartePro">
      <div className="splash__in">
        <div className="splash__mark">
          <span className="splash__ring" />
          <span className="splash__ring" />
          <span className="splash__tile">CP</span>
        </div>
        <div style={{ textAlign: "center", display: "grid", gap: 6, justifyItems: "center" }}>
          <div className="splash__name">CartePro</div>
          <div className="splash__sub">Ministère du Job et Bonheur</div>
        </div>
        <div className="splash__bar"><i /></div>
      </div>
    </div>
  );
}

const FEATURES = [
  ["qr", "Payer par QR code", "Le salarié présente un code à usage unique, valable cinq minutes, régénérable en un geste s’il expire."],
  ["spark", "Le Choix du Ministre", "Le ministre met en avant lui-même les partenaires qu'il veut recommander, sans passer par une mise à jour technique."],
  ["shield", "Un sceau qui se mérite", "Chaque partenaire est validé à la main par le Ministère, et porte le badge « Partenaire Officiel »."],
  ["lock", "Écritures inaltérables", "Une transaction validée n'est jamais réécrite. Une annulation ajoute une écriture inverse, rattachée à la première."],
  ["chat", "Une réclamation, une réponse", "Le salarié saisit l'administration depuis son espace ; l'agent instruit, répond et régularise dans le même fil."],
  ["chart", "Pilotage en direct", "Volume échangé, partenaires actifs, encours non dépensé : le Ministère suit le dispositif au jour le jour."]
];

const STEPS = [
  ["L'employeur crédite", "Le Ministère enregistre la dotation ; le budget du salarié est disponible immédiatement."],
  ["Le salarié en profite", "Un QR code présenté chez l'un des partenaires choisis par le Ministère."],
  ["Le partenaire encaisse", "La validation débite le budget, écrit au registre et déclenche le reversement."]
];

export function Landing() {
  const { push } = useNav();
  const db = useDB();
  const [splash, setSplash] = useState(() => {
    if (typeof sessionStorage === "undefined") return true;
    try { return !sessionStorage.getItem("cartepro.splash"); } catch (e) { return true; }
  });
  const done = () => {
    setSplash(false);
    try { sessionStorage.setItem("cartepro.splash", "1"); } catch (e) { /* sans effet */ }
  };

  const actifs = db.partners.filter(p => p.status === "active");
  const enCours = db.partners.filter(p => p.status === "pending");
  const mis = actifs.filter(p => p.featured);
  const volume = db.txns.filter(t => (t.kind || "payment") === "payment")
    .reduce((s, t) => s + t.amount, 0);

  return (
    <>
      {splash ? <Splash onDone={done} /> : null}

      <section className="hero">
        <div className="hero__in">
          <div>
            <span className="hero__eyebrow"><Icon name="spark" /> Dispositif public — lancement 2026</span>
            <h1>Les travailleurs français méritent de profiter de la vie, pas seulement de manger un sandwich.</h1>
            <p className="lead">
              Le CartePro, c&apos;est le principe du titre-restaurant, sans le restaurant. Votre
              employeur crédite votre budget ; vous le dépensez chez les partenaires référencés par
              le Ministère — poney club, costumier, glacier, chapelier.
            </p>
            <div className="hero__acts">
              <button className="btn btn--lg btn--onDark" type="button" onClick={() => push("/inscription")}>
                Créer un compte <Icon name="arrow" />
              </button>
              <button className="btn btn--lg btn--outline" type="button" onClick={() => push("/connexion")}>
                J&apos;ai déjà un compte
              </button>
            </div>
            <div className="hero__facts">
              <div className="hero__fact"><b>{nfr(actifs.length)}</b><span>partenaires officiels</span></div>
              <div className="hero__fact"><b>{eur(volume, { maximumFractionDigits: 0 })}</b><span>échangés depuis l&apos;ouverture</span></div>
              <div className="hero__fact"><b>30 min</b><span>de validité par QR code</span></div>
            </div>
          </div>

          <div className="showcard" aria-hidden="true">
            <div className="showcard__top">
              <div>
                <div className="paycard__brand">CartePro</div>
                <div className="paycard__min">Ministère du Job et Bonheur</div>
              </div>
              <div className="showcard__chip" />
            </div>
            <div style={{ marginTop: 20, fontSize: 10.5, letterSpacing: ".06em",
                          textTransform: "uppercase", opacity: .74 }}>À dépenser</div>
            <div className="showcard__bal num">{eur(db.employees[0].balance)}</div>
            <div style={{ fontSize: 12, opacity: .8, marginTop: 4 }}>
              chez vos partenaires préférés !
            </div>
            <div className="showcard__row">
              <span className="mono num" style={{ letterSpacing: ".12em" }}>4021 0042 88</span>
              <span style={{ marginLeft: "auto" }}>Groupe Vallonis</span>
            </div>
          </div>
        </div>
      </section>

      {mis.length ? (
        <div className="band">
          <div className="section">
            <div className="section__h">
              <h2>Le Choix du Ministre</h2>
              <p>Sélection personnelle de Jean-Eudes Berlier, Ministre du Job et Bonheur.</p>
            </div>
            <div className="grid g-2">
              {mis.map(p => (
                <article className="feat pickfeat" key={p.id}>
                  <div style={{ display: "flex", gap: 14, alignItems: "flex-start" }}>
                    <span className="feat__ico"><Icon name={catIco(p.category)} /></span>
                    <div style={{ minWidth: 0 }}>
                      <h3>{p.name} <span className="pick__star">★</span></h3>
                      <p style={{ marginTop: 2 }}>{catLabel(p.category)} · {p.city} · {p.channel}</p>
                    </div>
                  </div>
                  {p.ministerNote ? (
                    <p className="quote">« {p.ministerNote} » — Jean-Eudes Berlier</p>
                  ) : null}
                </article>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      <div className="section">
        <div className="section__h">
          <h2>Les partenaires du lancement</h2>
          <p>Établissements validés par le Ministère. D&apos;autres sont en cours de signature.</p>
        </div>
        <div className="grid g-4">
          {actifs.map(p => (
            <article className="feat" key={p.id}>
              <span className="feat__ico"><Icon name={catIco(p.category)} /></span>
              <h3>{p.name}</h3>
              <p>{catLabel(p.category)}<br />{p.city}<br />
                <span style={{ color: "var(--ink-4)" }}>{p.channel}</span></p>
              <span className="official official--sm" style={{ marginTop: "auto" }}>
                <span className="official__seal" aria-hidden="true">★</span>
                Partenaire Officiel
              </span>
            </article>
          ))}
        </div>
        {enCours.length ? (
          <p style={{ textAlign: "center", marginTop: 22, fontSize: 13, color: "var(--ink-3)" }}>
            {enCours.length} autres établissements sont en cours de signature :{" "}
            {enCours.slice(0, 4).map(p => p.name).join(", ")}…
          </p>
        ) : null}
      </div>

      <div className="band">
        <div className="section">
          <div className="section__h">
            <h2>Trois gestes, trois espaces</h2>
            <p>Le dispositif relie l&apos;employeur, le salarié et le commerçant autour d&apos;un même registre.</p>
          </div>
          <div className="steps">
            {STEPS.map(([t, d]) => (
              <div className="step" key={t}><b>{t}</b><span>{d}</span></div>
            ))}
          </div>
        </div>
      </div>

      <div className="section">
        <div className="section__h">
          <h2>Ce que fait la plateforme</h2>
          <p>Les fonctions attendues au cahier des charges JEB/DNI/2026-002 v2.0, toutes démontrables.</p>
        </div>
        <div className="grid g-3">
          {FEATURES.map(([ico, t, d]) => (
            <div className="feat" key={t}>
              <span className="feat__ico"><Icon name={ico} /></span>
              <h3>{t}</h3>
              <p>{d}</p>
            </div>
          ))}
        </div>
      </div>

      <div className="band">
        <div className="section">
          <div className="section__h">
            <h2>Vous êtes…</h2>
            <p>Chaque profil dispose de son espace, de ses droits et de ses écrans.</p>
          </div>
          <div className="grid g-3">
            {[
              ["wallet", "Salarié", "Consultez votre budget, payez par QR code, retrouvez vos opérations, localisez les partenaires et saisissez l'administration en cas de litige.", "/inscription?role=employee", "Créer mon compte"],
              ["store", "Partenaire", "Encaissez les paiements CartePro, suivez vos recettes, arborez le sceau officiel du Ministère.", "/inscription?role=partner", "Demander l'adhésion"],
              ["shield", "Ministère", "Validez les adhésions, désignez le Choix du Ministre, pilotez les comptes et suivez la volumétrie nationale.", "/connexion", "Accès agents"]
            ].map(([ico, t, d, href, cta]) => (
              <div className="feat" key={t}>
                <span className="feat__ico"><Icon name={ico} /></span>
                <h3>{t}</h3>
                <p>{d}</p>
                <button className="btn" type="button" style={{ marginTop: "auto", alignSelf: "flex-start" }}
                        onClick={() => push(href)}>{cta}</button>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="section" style={{ paddingTop: 30 }}>
        <div className="note">
          <Icon name="info" />
          <div>
            <b>Simulation fonctionnelle.</b> Aucune opération financière réelle n&apos;est effectuée.
            Les données sont fictives et conservées dans ce navigateur uniquement ; la barre noire en
            bas de page permet de changer d&apos;espace, de changer d&apos;appareil et de tout
            réinitialiser.
          </div>
        </div>
      </div>

      <footer className="band">
        <div className="footer">
          <span><b style={{ color: "var(--ink-2)" }}>CartePro</b> — Ministère du Job et Bonheur</span>
          <span>Direction du Numérique et de l&apos;Innovation</span>
          <span style={{ marginLeft: "auto" }} className="mono">JEB/DNI/2026-002 · v2.0</span>
        </div>
      </footer>
    </>
  );
}
