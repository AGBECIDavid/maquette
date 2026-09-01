"use client";
/* Page publique : écran d'ouverture animé, présentation du dispositif, et les
   deux portes d'entrée — connexion et inscription. */

import { useEffect, useState } from "react";
import { Icon } from "../lib/icons.jsx";
import { useNav, useDB } from "../lib/app.jsx";
import { eur, nfr } from "../lib/format.js";

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
  ["qr", "Payer par QR code", "Le salarié présente un code à usage unique, valable cinq minutes. Le partenaire scanne, saisit le montant, valide."],
  ["offline", "Résistant à la coupure réseau", "En connectivité dégradée, le jeton est produit localement et l'encaissement rejoué dès le retour du réseau."],
  ["lock", "Écritures inaltérables", "Chaque transaction est chaînée à la précédente par une empreinte. Une ligne modifiée se détecte immédiatement."],
  ["store", "Réseau de partenaires référencés", "Catalogue consultable, recherche par ville et par catégorie, adhésion soumise à validation du Ministère."],
  ["chat", "Une réclamation, une réponse", "Le salarié saisit l'administration depuis son espace ; l'agent instruit, répond et régularise dans le même fil."],
  ["key", "Interopérable avec les SIRH", "Une API REST documentée expose le solde d'un bénéficiaire aux systèmes de paie des employeurs."]
];

const STEPS = [
  ["L'employeur crédite", "Le Ministère enregistre la dotation ; le solde du salarié est disponible immédiatement."],
  ["Le salarié paie", "Un QR code présenté en caisse chez l'un des partenaires référencés."],
  ["Le partenaire encaisse", "La validation débite le solde, écrit au registre et déclenche le reversement."]
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

  const partenaires = db.partners.filter(p => p.status === "active").length;
  const volume = db.txns.reduce((s, t) => s + t.amount, 0);

  return (
    <>
      {splash ? <Splash onDone={done} /> : null}

      <section className="hero">
        <div className="hero__in">
          <div>
            <span className="hero__eyebrow"><Icon name="spark" /> Dispositif public — expérimentation 2026</span>
            <h1>Le titre d&apos;avantages salariés, dématérialisé de bout en bout.</h1>
            <p className="lead">
              CartePro permet à un employeur de créditer ses salariés d&apos;un budget utilisable
              chez les partenaires référencés par le Ministère. Pas de carte plastique, pas de
              carnet de titres : un solde, un QR code, un réseau.
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
              <div className="hero__fact"><b>{nfr(partenaires)}</b><span>partenaires actifs</span></div>
              <div className="hero__fact"><b>{eur(volume, { maximumFractionDigits: 0 })}</b><span>échangés depuis l&apos;ouverture</span></div>
              <div className="hero__fact"><b>5 min</b><span>de validité par QR code</span></div>
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
                          textTransform: "uppercase", opacity: .74 }}>Solde disponible</div>
            <div className="showcard__bal num">{eur(db.employees[0].balance)}</div>
            <div className="showcard__row">
              <span className="mono num" style={{ letterSpacing: ".12em" }}>4021 0042 88</span>
              <span style={{ marginLeft: "auto" }}>Groupe Vallonis</span>
            </div>
          </div>
        </div>
      </section>

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
          <p>Les fonctions attendues au cahier des charges JEB/DNI/2026-002, toutes démontrables.</p>
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
              ["wallet", "Salarié", "Consultez votre solde, payez par QR code, retrouvez vos opérations, localisez les partenaires et saisissez l'administration en cas de litige.", "/inscription?role=employee", "Créer mon compte"],
              ["store", "Partenaire", "Encaissez les paiements CartePro, suivez vos recettes et vos reversements, rejoignez le réseau référencé.", "/inscription?role=partner", "Demander l'adhésion"],
              ["shield", "Administration", "Instruisez les adhésions, pilotez les comptes, créditez les bénéficiaires et suivez la volumétrie nationale.", "/connexion", "Accès agents"]
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
            <b>Simulation fonctionnelle.</b> Aucune opération financière réelle n&apos;est effectuée
            (§5 du cahier des charges). Les données sont fictives et conservées dans ce navigateur
            uniquement ; la barre noire en bas de page permet de changer d&apos;espace, de simuler une
            coupure réseau et de tout réinitialiser.
          </div>
        </div>
      </div>

      <footer className="band">
        <div className="footer">
          <span><b style={{ color: "var(--ink-2)" }}>CartePro</b> — Ministère du Job et Bonheur</span>
          <span>Direction du Numérique et de l&apos;Innovation</span>
          <span style={{ marginLeft: "auto" }} className="mono">JEB/DNI/2026-002 · v1.0</span>
        </div>
      </footer>
    </>
  );
}
