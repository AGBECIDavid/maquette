"use client";
/* §8 — Swagger UI accessible sur l'instance. La bibliothèque est chargée depuis
   un CDN ; si elle ne répond pas (poste hors ligne, politique de sécurité), la
   page ne se contente pas d'un écran blanc : elle affiche la spécification
   brute, qui reste la source de vérité. */

import { useEffect, useState } from "react";
import { Icon } from "../lib/icons.jsx";

const CDN = "https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.17.14";

export function SwaggerPage() {
  const [etat, setEtat] = useState("chargement");
  const [brut, setBrut] = useState("");

  useEffect(() => {
    fetch("/openapi.yaml").then(r => r.text()).then(setBrut).catch(() => {});

    const css = document.createElement("link");
    css.rel = "stylesheet";
    css.href = CDN + "/swagger-ui.min.css";
    document.head.appendChild(css);

    const js = document.createElement("script");
    js.src = CDN + "/swagger-ui-bundle.min.js";
    js.onload = () => {
      try {
        window.SwaggerUIBundle({ url: "/openapi.yaml", dom_id: "#swagger", deepLinking: true });
        setEtat("pret");
      } catch (e) { setEtat("secours"); }
    };
    js.onerror = () => setEtat("secours");
    document.head.appendChild(js);

    const minuteur = setTimeout(() => setEtat(e => (e === "chargement" ? "secours" : e)), 6000);
    return () => clearTimeout(minuteur);
  }, []);

  return (
    <div className="app">
      <div className="tricolore" aria-hidden="true"><i /><i /><i /></div>
      <div className="stage">
        <div className="pagehead">
          <div><h1>Documentation de l&apos;API</h1>
            <p>Spécification OpenAPI 3.0 du dispositif CartePro. Source de vérité :{" "}
              <a href="/openapi.yaml">openapi.yaml</a>.</p></div>
          <div className="pagehead__act">
            <a className="btn" href="/openapi.yaml" download><Icon name="dl" /> Télécharger</a>
          </div>
        </div>

        {etat === "secours" ? (
          <>
            <div className="note note--warn" style={{ marginBottom: 16 }}>
              <Icon name="alert" />
              <div>
                <b>Swagger UI n&apos;a pas pu être chargé</b> depuis le réseau. La spécification
                complète est reproduite ci-dessous ; elle reste lisible par n&apos;importe quel
                outil compatible OpenAPI 3.0.
              </div>
            </div>
            <section className="card"><div className="card__bd">
              <pre className="mono" style={{ margin: 0, fontSize: 12, lineHeight: 1.55,
                   overflowX: "auto", whiteSpace: "pre-wrap" }}>{brut || "Chargement…"}</pre>
            </div></section>
          </>
        ) : null}

        <div id="swagger" style={{ background: "var(--surface)", borderRadius: "var(--r-card)" }} />
        {etat === "chargement" ? <p className="empty">Chargement de Swagger UI…</p> : null}
      </div>
    </div>
  );
}
