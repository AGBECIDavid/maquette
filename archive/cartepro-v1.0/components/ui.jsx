"use client";
/* Briques d'interface partagées par les trois espaces. */

import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Icon } from "../lib/icons.jsx";
import { nfr } from "../lib/format.js";

export const Pill = ({ kind = "mute", children }) =>
  <span className={"pill pill--" + kind}>{children}</span>;

export function Note({ kind, icon, children }) {
  return (
    <div className={"note" + (kind ? " note--" + kind : "")}>
      <Icon name={icon || (kind === "warn" ? "alert" : "info")} />
      <div>{children}</div>
    </div>
  );
}

export function Empty({ icon = "info", children }) {
  return <p className="empty"><Icon name={icon} /><br />{children}</p>;
}

export function StatTile({ label, value, note, delta, deltaDir, deltaNote, spark }) {
  return (
    <div className="card stat">
      <div className="stat__lb">{label}</div>
      <div className="stat__v">{value}</div>
      {delta ? (
        <div className={"stat__d stat__d--" + (deltaDir || "up")}>
          <Icon name={deltaDir === "down" ? "down" : "up"} />
          <b>{delta}</b> {deltaNote}
        </div>
      ) : null}
      {note ? <div className="stat__d">{note}</div> : null}
      {spark ? <Sparkline values={spark} /> : null}
    </div>
  );
}

export function Pager({ meta, onPage, id }) {
  if (!meta) return null;
  if (meta.pages <= 1) {
    return <span className="pager__i">{meta.total} résultat{meta.total > 1 ? "s" : ""}</span>;
  }
  const from = Math.max(1, Math.min(meta.page - 1, meta.pages - 2));
  const nums = [];
  for (let p = from; p < from + Math.min(3, meta.pages); p++) nums.push(p);
  return (
    <>
      <span className="pager__i">{meta.total} résultats · page {meta.page} sur {meta.pages}</span>
      <button className="pgbtn" type="button" disabled={meta.page === 1}
              onClick={() => onPage(meta.page - 1)} aria-label="Page précédente">
        <Icon name="left" />
      </button>
      {nums.map(p => (
        <button key={p} className="pgbtn" type="button"
                aria-current={p === meta.page ? "true" : undefined}
                onClick={() => onPage(p)}>{p}</button>
      ))}
      <button className="pgbtn" type="button" disabled={meta.page === meta.pages}
              onClick={() => onPage(meta.page + 1)} aria-label="Page suivante">
        <Icon name="right" />
      </button>
    </>
  );
}

/* ---- Infobulles de graphique : un seul écouteur pour toute la page ------- */
export function ChartTip() {
  const ref = useRef(null);
  useEffect(() => {
    const el = ref.current;
    const move = ev => {
      const t = ev.target.closest ? ev.target.closest("[data-tip]") : null;
      if (!t) { el.style.opacity = "0"; return; }
      el.textContent = t.getAttribute("data-tip");
      el.style.opacity = "1";
      const r = el.getBoundingClientRect();
      let x = ev.clientX + 14, y = ev.clientY - r.height - 10;
      if (x + r.width > innerWidth - 8) x = ev.clientX - r.width - 14;
      if (y < 8) y = ev.clientY + 16;
      el.style.left = x + "px"; el.style.top = y + "px";
    };
    document.addEventListener("mousemove", move);
    return () => document.removeEventListener("mousemove", move);
  }, []);
  return <div className="charttip" ref={ref} role="presentation" />;
}

/* ---- Colonnes -------------------------------------------------------------
   Dessinées après mesure, en unités pixel. Étirer un viewBox pour remplir la
   carte étirerait aussi les étiquettes. */
function niceMax(v) {
  if (v <= 0) return 1;
  const mag = Math.pow(10, Math.floor(Math.log10(v)));
  const n = v / mag;
  return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 2.5 ? 2.5 : n <= 5 ? 5 : 10) * mag;
}
function topRounded(x, y, w, h, r) {
  const rr = Math.min(r, w / 2, h);
  return `M${x} ${y + h}V${y + rr}a${rr} ${rr} 0 0 1 ${rr} ${-rr}h${w - 2 * rr}a${rr} ${rr} 0 0 1 ${rr} ${rr}V${y + h}Z`;
}

export function ColumnChart({ rows, height = 200, fmtTick, fmtPeak, tip, aria }) {
  const box = useRef(null);
  const [w, setW] = useState(0);
  useLayoutEffect(() => {
    const el = box.current;
    if (!el) return;
    const measure = () => setW(el.clientWidth);
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const W = Math.max(240, w), H = height;
  const padL = 54, padR = 10, padT = 20, padB = 22;
  const max = niceMax(Math.max(...rows.map(r => r.value), 1));
  const plotW = Math.max(10, W - padL - padR), plotH = Math.max(10, H - padT - padB);
  const band = plotW / Math.max(1, rows.length);
  const bw = Math.min(band * 0.6, 24);
  const peak = rows.reduce((a, b) => (b.value > a.value ? b : a), rows[0] || { value: 0 });

  return (
    <div className="chartbox" ref={box} style={{ height: H }}>
      {w > 0 ? (
        <svg className="chart" viewBox={`0 0 ${W} ${H}`} width={W} height={H}
             role="img" aria-label={aria || "Graphique en colonnes"}>
          {[0, 1, 2].map(i => {
            const y = padT + plotH * (i / 2), v = max * (1 - i / 2);
            return (
              <g key={i}>
                <line className="grid-l" x1={padL} y1={y} x2={W - padR} y2={y} />
                <text className="tick tick--v" x={padL - 8} y={y + 3.5} textAnchor="end">
                  {fmtTick ? fmtTick(v) : nfr(Math.round(v))}
                </text>
              </g>
            );
          })}
          {rows.map((r, i) => {
            const h = Math.max(1.5, plotH * (r.value / max));
            const x = padL + band * i + (band - bw) / 2, y = padT + plotH - h;
            const isPeak = r === peak && r.value > 0;
            return (
              <g key={i}>
                <rect className="hit" x={padL + band * i} y={padT} width={band} height={plotH}
                      data-tip={tip ? tip(r) : `${r.label} — ${r.value}`} />
                <path className={"bar" + (isPeak ? " on" : "")} d={topRounded(x, y, bw, h, 4)} />
                {isPeak ? (
                  <text className="val" x={x + bw / 2} y={y - 7} textAnchor="middle">
                    {fmtPeak ? fmtPeak(r) : nfr(r.value)}
                  </text>
                ) : null}
                {r.tick ? (
                  <text className="tick" x={x + bw / 2} y={H - 6} textAnchor="middle">{r.tick}</text>
                ) : null}
              </g>
            );
          })}
          <line className="axis-l" x1={padL} y1={padT + plotH} x2={W - padR} y2={padT + plotH} />
        </svg>
      ) : null}
    </div>
  );
}

/* ---- Barres horizontales : les libellés restent du texte HTML ------------ */
export function BarList({ rows, fmt }) {
  const max = Math.max(...rows.map(r => r.value), 1);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      {rows.map(r => {
        const pct = Math.max(1.5, (r.value / max) * 100);
        return (
          <div key={r.label}>
            <div style={{ display: "flex", gap: 12, alignItems: "baseline", marginBottom: 4 }}>
              <span style={{ fontSize: 12.5, color: "var(--ink-2)", flex: 1, minWidth: 0,
                             overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{r.label}</span>
              <b className="num" style={{ fontSize: 12.5 }}>{fmt ? fmt(r.value) : nfr(r.value)}</b>
            </div>
            <svg className="chart" viewBox="0 0 100 6" preserveAspectRatio="none"
                 style={{ height: 8, width: "100%" }} aria-hidden="true">
              <rect x="0" y="0" width="100" height="6" rx="3" fill="var(--data-wash)" />
              <rect className="bar" x="0" y="0" width={pct} height="6" rx="2.4" />
            </svg>
          </div>
        );
      })}
    </div>
  );
}

export function Sparkline({ values }) {
  const W = 100, H = 22;
  const max = Math.max(...values, 1);
  const step = W / Math.max(1, values.length - 1);
  const pt = i => [i * step, H - 2 - (H - 4) * (values[i] / max)];
  const d = values.map((v, i) => (i ? "L" : "M") + pt(i).map(n => n.toFixed(2)).join(" ")).join("");
  const last = pt(values.length - 1);
  return (
    <svg className="chart" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none"
         style={{ height: 26, width: "100%", marginTop: 10 }} aria-hidden="true">
      <path d={`${d}L${W} ${H}L0 ${H}Z`} fill="var(--data-wash)" />
      <path d={d} fill="none" stroke="var(--data)" strokeWidth="1.6" strokeLinejoin="round"
            strokeLinecap="round" vectorEffect="non-scaling-stroke" />
      <circle cx={last[0].toFixed(2)} cy={last[1].toFixed(2)} r="2.2" fill="var(--data)"
              stroke="var(--surface)" strokeWidth="1.4" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

/* ---- Bouton de copie ------------------------------------------------------
   Le presse-papiers moderne n'est pas toujours disponible (contexte non
   sécurisé, page en bac à sable) : on retombe sur la sélection + execCommand,
   et en dernier recours on laisse le texte sélectionné à l'utilisateur. */
export function CopyButton({ value, label = "Copier", className, onDone }) {
  const [done, setDone] = useState(false);
  const copy = async () => {
    let ok = false;
    try {
      if (navigator.clipboard && isSecureContext) { await navigator.clipboard.writeText(value); ok = true; }
    } catch (e) { ok = false; }
    if (!ok) {
      try {
        const ta = document.createElement("textarea");
        ta.value = value;
        ta.style.cssText = "position:fixed;opacity:0;left:-9999px";
        document.body.appendChild(ta);
        ta.select();
        ok = document.execCommand("copy");
        ta.remove();
      } catch (e) { ok = false; }
    }
    setDone(ok);
    setTimeout(() => setDone(false), 2000);
    if (onDone) onDone(ok);
  };
  return (
    <button type="button" className={"btn " + (className || "")} onClick={copy}
            data-done={done ? "true" : undefined}
            aria-label={done ? "Copié" : label + " : " + value}>
      <Icon name={done ? "check" : "copy"} />
      {done ? "Copié" : label}
    </button>
  );
}
