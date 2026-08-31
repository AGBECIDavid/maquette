"use client";
/* ============================================================================
   Liaison React : magasin observable, session, navigation, notifications,
   fenêtres modales, et le châssis d'aperçu (smartphone / tablette / PC).

   La navigation est abstraite derrière `useNav` : l'application Next la
   branche sur son routeur, le build monofichier de l'aperçu la branche sur le
   fragment d'URL. Les écrans, eux, ignorent lequel des deux les héberge.
   ========================================================================= */

import { createContext, useContext, useEffect, useMemo, useState, useSyncExternalStore, useCallback } from "react";
import { store, API, BUS, emp, prt, agent } from "./api.js";
import { Icon } from "./icons.jsx";

/* ---- Magasin -------------------------------------------------------------- */
export function useDB() {
  useSyncExternalStore(
    cb => store.subscribe(cb),
    () => store.snapshot(),
    () => 0
  );
  return store.init();
}

export function useMounted() {
  const [m, setM] = useState(false);
  useEffect(() => { setM(true); }, []);
  return m;
}

/* Rejoue le rendu quand un événement métier passe (solde temps réel). */
export function useBus(evt, fn) {
  useEffect(() => BUS.on(evt, fn), [evt, fn]);
}

export function useSession() {
  const db = useDB();
  const s = db.session;
  return useMemo(() => {
    if (!s) return null;
    const who = s.role === "employee" ? emp(s.id) : s.role === "partner" ? prt(s.id) : agent(s.id);
    if (!who) return null;
    return { role: s.role, id: s.id, who };
  }, [s && s.role, s && s.id, db.employees, db.partners]);
}

/* ---- Navigation ----------------------------------------------------------- */
const NavCtx = createContext({ path: "/", push: () => {} });
export const NavProvider = NavCtx.Provider;
export const useNav = () => useContext(NavCtx);

/* ---- Notifications -------------------------------------------------------- */
const ToastCtx = createContext(() => {});
export const useToast = () => useContext(ToastCtx);

/* ---- Fenêtres ------------------------------------------------------------- */
const ModalCtx = createContext({ open: () => {}, close: () => {} });
export const useModal = () => useContext(ModalCtx);

/* ---- Aperçu par type d'appareil ------------------------------------------- */
export const DEVICES = {
  phone:   { label: "Smartphone", w: 390,  h: 780,  ico: "phone" },
  tablet:  { label: "Tablette",   w: 900,  h: 720,  ico: "tablet" },
  desktop: { label: "Ordinateur", w: null, h: null, ico: "desktop" }
};
const DeviceCtx = createContext({ device: "desktop", setDevice: () => {} });
export const useDevice = () => useContext(DeviceCtx);

/* ---- Fournisseur unique --------------------------------------------------- */
export function AppProviders({ children, path, push }) {
  const [toasts, setToasts] = useState([]);
  const [modal, setModal] = useState(null);
  const [device, setDeviceState] = useState("desktop");

  useEffect(() => {
    try {
      const d = localStorage.getItem("cartepro.device");
      if (d && DEVICES[d]) setDeviceState(d);
    } catch (e) { /* stockage indisponible */ }
  }, []);

  const setDevice = useCallback(d => {
    setDeviceState(d);
    try { localStorage.setItem("cartepro.device", d); } catch (e) { /* sans effet */ }
  }, []);

  const toast = useCallback((kind, title, detail) => {
    const id = Math.random().toString(36).slice(2);
    setToasts(t => t.concat({ id, kind, title, detail }));
    setTimeout(() => setToasts(t => t.filter(x => x.id !== id)), 4600);
  }, []);

  const modalApi = useMemo(() => ({
    open: (title, content, foot) => setModal({ title, content, foot }),
    close: () => setModal(null)
  }), []);

  const nav = useMemo(() => ({ path, push }), [path, push]);

  useEffect(() => {
    const onKey = e => { if (e.key === "Escape") setModal(null); };
    addEventListener("keydown", onKey);
    return () => removeEventListener("keydown", onKey);
  }, []);

  return (
    <NavCtx.Provider value={nav}>
      <DeviceCtx.Provider value={{ device, setDevice }}>
        <ToastCtx.Provider value={toast}>
          <ModalCtx.Provider value={modalApi}>
            {children}
            <Toasts items={toasts} />
            {modal ? <Modal {...modal} onClose={() => setModal(null)} /> : null}
          </ModalCtx.Provider>
        </ToastCtx.Provider>
      </DeviceCtx.Provider>
    </NavCtx.Provider>
  );
}

function Toasts({ items }) {
  return (
    <div className="toasts" aria-live="assertive">
      {items.map(t => (
        <div key={t.id} className={"toast toast--" + t.kind}>
          <Icon name={t.kind === "good" ? "check" : t.kind === "bad" ? "alert" : "info"} />
          <div><b>{t.title}</b>{t.detail ? <span>{t.detail}</span> : null}</div>
        </div>
      ))}
    </div>
  );
}

function Modal({ title, content, foot, onClose }) {
  return (
    <div className="modal" data-open="true" role="dialog" aria-modal="true"
         aria-label={title} onMouseDown={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="modal__box">
        <div className="modal__hd">
          <h3>{title}</h3>
          <span style={{ flex: 1 }} />
          <button className="btn btn--ghost" type="button" onClick={onClose} aria-label="Fermer">
            <Icon name="x" />
          </button>
        </div>
        <div className="modal__bd">{content}</div>
        {foot ? <div className="modal__ft">{foot}</div> : null}
      </div>
    </div>
  );
}

/* ---- Appels d'API avec gestion d'erreur homogène -------------------------- */
export function useApi() {
  const toast = useToast();
  return useMemo(() => {
    const wrap = fn => async (...args) => {
      try { return await fn(...args); }
      catch (e) {
        if (e.network) throw e;                         // le mode dégradé a ses propres messages
        toast("bad", "Opération refusée", (e.body && e.body.message) || e.message);
        throw e;
      }
    };
    return { get: wrap(API.get), post: wrap(API.post), patch: wrap(API.patch), raw: API };
  }, [toast]);
}

/* Charge une ressource et la recharge à chaque mutation du magasin. */
export function useResource(fn, deps) {
  const db = useDB();
  const [state, setState] = useState({ loading: true, data: null });
  const key = JSON.stringify(deps || []);
  useEffect(() => {
    let alive = true;
    Promise.resolve(fn()).then(
      data => { if (alive) setState({ loading: false, data }); },
      () => { if (alive) setState({ loading: false, data: null }); }
    );
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, db.version, store.snapshot()]);
  return state;
}
