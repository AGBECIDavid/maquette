/* §5.2 — sonde de vie. En export statique, la route est pré-rendue : elle
   répond hors ligne comme en ligne, ce qui suffit à un contrôle de déploiement
   (« le service répond, voici sa version »). Un backend réel y ajouterait
   l'état de la base et des dépendances. */

export const dynamic = "force-static";

export function GET() {
  return Response.json({
    status: "ok",
    application: "cartepro",
    version: "2.0.0",
    simulation: true,
    builtAt: new Date().toISOString()
  });
}
