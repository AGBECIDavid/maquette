"use client";
/* Branche l'abstraction de navigation sur le routeur de Next, et retarde le
   rendu jusqu'au montage : le jeu de démonstration est daté par rapport à
   l'instant présent, donc un rendu serveur et un rendu client ne pourraient
   pas coïncider. L'écran d'ouverture couvre cette attente. */

import { useEffect, useState, useCallback } from "react";
import { usePathname, useRouter } from "next/navigation";
import { AppProviders, useMounted } from "../lib/app.jsx";

function Boot() {
  return (
    <div className="splash" data-static="true" role="status" aria-label="Chargement de CartePro">
      <div className="splash__in">
        <div className="splash__mark">
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

export function Providers({ children }) {
  const mounted = useMounted();
  const pathname = usePathname();
  const router = useRouter();
  const [full, setFull] = useState(pathname);

  useEffect(() => {
    setFull(pathname + (typeof location !== "undefined" ? location.search : ""));
  }, [pathname]);

  const push = useCallback(p => router.push(p), [router]);

  if (!mounted) return <Boot />;
  return <AppProviders path={full} push={push}>{children}</AppProviders>;
}
