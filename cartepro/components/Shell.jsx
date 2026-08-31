"use client";
/* Coquille commune : bandeau institutionnel, châssis d'aperçu, barre de
   pilotage de la démonstration et console API. */

import { useEffect, useState } from "react";
import { Icon } from "../lib/icons.jsx";
import { initiales } from "../lib/format.js";
import { API, store } from "../lib/api.js";
import { useDB, useSession, useNav, useToast, useDevice, DEVICES } from "../lib/app.jsx";
import { ChartTip } from "./ui.jsx";

const ROLE_LABEL = { employee: "Salarié", partner: "Partenaire", admin: "Administration" };
const ROLE_HOME  = { employee: "/salarie", partner: "/partenaire", admin: "/admin" };

function Masthead() {
  const session = useSession();
  const { push } = useNav();
  const toast = useToast();

  const logout = async () => {
    await API.post("/auth/logout");
    toast("info", "Session fermée", "À bientôt.");
    push("/");
  };

  return (
    <header className="masthead">
      <div className="masthead__in">
        <button className="crest" type="button" onClick={() => push("/")}
                aria-label="Retour à l'accueil CartePro">
          <span className="crest__mark" aria-hidden="true">JB</span>
          <span className="crest__txt">
            <span className="crest__ministry">Ministère du Job<br />et Bonheur</span>
            <span className="crest__dir">Direction du Numérique et de l&apos;Innovation</span>
          </span>
        </button>
        <div className="wordmark"><b>CartePro</b> <span>JEB/DNI/2026-002 · v1.0</span></div>
        <div className="masthead__spacer" />
        <span className="envpill">Démonstrateur — aucune transaction réelle</span>
        {session ? (
          <div className="whoami">
            <span className="whoami__av">{initiales(session.who.name)}</span>
            <div>
              <div className="whoami__n">{session.who.name}</div>
              <div className="whoami__r">{ROLE_LABEL[session.role]}</div>
            </div>
            <button className="btn btn--ghost" type="button" onClick={logout}
                    title="Fermer la session" aria-label="Fermer la session">
              <Icon name="out" />
            </button>
          </div>
        ) : (
          <div style={{ display: "flex", gap: 8 }}>
            <button className="btn" type="button" onClick={() => push("/connexion")}>Se connecter</button>
            <button className="btn btn--primary" type="button" onClick={() => push("/inscription")}>
              Créer un compte
            </button>
          </div>
        )}
      </div>
    </header>
  );
}

function Console({ onClose }) {
  const [, force] = useState(0);
  useEffect(() => API.onLog(() => force(n => n + 1)), []);
  const rows = API.logs.slice(-60).reverse();
  return (
    <section className="console" aria-label="Journal des appels d'API">
      <div className="console__hd">
        <b>Console API</b>
        <span style={{ color: "#8b92ad" }}>REST · JSON · <span className="mono">/api/v1</span></span>
        <span style={{ flex: 1 }} />
        <button className="dockbtn" type="button" onClick={() => { API.clear(); force(n => n + 1); }}>Vider</button>
        <button className="dockbtn" type="button" onClick={onClose}>Fermer</button>
      </div>
      <div className="console__bd">
        {rows.length === 0 ? (
          <p style={{ color: "#8b92ad" }}>
            Aucun appel pour l&apos;instant. Chaque geste dans l&apos;interface en déclenche un.
          </p>
        ) : rows.map(e => {
          const body = JSON.stringify(e.body);
          return (
            <div key={e.id}>
              <div className="logline">
                <span className="logline__m" data-m={e.method}>{e.method}</span>
                <span className="logline__p">{e.path}</span>
                <span className="logline__s">
                  <b data-bad={e.bad ? "true" : undefined}>{e.status || "ERR"}</b> · {e.ms} ms
                </span>
              </div>
              <div className="logbody">{body.length > 260 ? body.slice(0, 260) + " …" : body}</div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

function Dock() {
  const db = useDB();
  const session = useSession();
  const { push } = useNav();
  const toast = useToast();
  const { device, setDevice } = useDevice();
  const [console_, setConsole] = useState(false);
  const [logCount, setLogCount] = useState(API.logs.length);
  useEffect(() => API.onLog(() => setLogCount(API.logs.length)), []);

  const switchRole = async role => {
    await API.post("/auth/session", { role });
    push(ROLE_HOME[role]);
  };

  const toggleDegraded = () => {
    db.degraded = !db.degraded;
    store.save();
    toast(db.degraded ? "info" : "good",
      db.degraded ? "Mode dégradé activé" : "Réseau rétabli",
      db.degraded ? "Les appels serveur échouent ; le QR et les encaissements passent en local."
                  : "Les encaissements en attente peuvent être synchronisés.");
  };

  const reset = () => {
    if (!confirm("Réinitialiser toutes les données de démonstration ?")) return;
    store.reset();
    API.clear();
    push("/");
    toast("good", "Données réinitialisées", "Le jeu de démonstration est revenu à son état initial.");
  };

  return (
    <>
      {console_ ? <Console onClose={() => setConsole(false)} /> : null}
      <nav className="dock" aria-label="Pilotage de la démonstration">
        <span className="dock__lb">Espace</span>
        <div className="switch" role="group" aria-label="Changer d'espace">
          {Object.keys(ROLE_LABEL).map(r => (
            <button key={r} type="button" onClick={() => switchRole(r)}
                    aria-current={session && session.role === r ? "true" : undefined}>
              {ROLE_LABEL[r]}
            </button>
          ))}
        </div>
        <span className="dock__lb">Vue</span>
        <div className="switch" role="group" aria-label="Changer d'appareil">
          {Object.keys(DEVICES).map(d => (
            <button key={d} type="button" onClick={() => setDevice(d)}
                    aria-current={device === d ? "true" : undefined} title={DEVICES[d].label}>
              <Icon name={DEVICES[d].ico} />
              <span className="dock__devlb">{DEVICES[d].label}</span>
            </button>
          ))}
        </div>
        <div className="dock__spacer" />
        <button className="dockbtn" type="button" onClick={toggleDegraded}
                aria-pressed={db.degraded ? "true" : "false"}
                title="Simule une perte de connectivité chez le partenaire">
          <Icon name="offline" /> Mode dégradé
        </button>
        <button className="dockbtn" type="button" onClick={() => setConsole(v => !v)}
                aria-pressed={console_ ? "true" : "false"}>
          <Icon name="list" /> Console API <span className="mono" style={{ opacity: .7 }}>{logCount}</span>
        </button>
        <button className="dockbtn" type="button" onClick={reset}>Réinitialiser</button>
      </nav>
    </>
  );
}

/* Le châssis : sur smartphone et tablette, l'application est rendue à la
   largeur de l'appareil. Les mises en page réagissent par requêtes de
   conteneur, donc ce qui s'affiche ici est la vraie version adaptative — pas
   une réduction d'échelle. */
export function Shell({ children }) {
  const { device } = useDevice();
  const d = DEVICES[device] || DEVICES.desktop;

  const app = (
    <div className="app">
      <div className="tricolore" aria-hidden="true"><i /><i /><i /></div>
      <Masthead />
      {children}
    </div>
  );

  return (
    <>
      <div className="preview" data-device={device}>
        {device === "desktop" ? app : (
          <div className={"chassis chassis--" + device}>
            <div className="chassis__body">
              {device === "phone" ? <div className="chassis__island" aria-hidden="true" /> : null}
              <div className="chassis__screen" style={{ width: d.w, height: d.h }}>
                <div className="chassis__scroll">{app}</div>
              </div>
            </div>
            <p className="chassis__cap">{d.label} — {d.w} × {d.h} px</p>
          </div>
        )}
      </div>
      <Dock />
      <ChartTip />
    </>
  );
}
