import {
  ErreurEncaissement,
  type CodeErreurEncaissement,
  type EncaissementAccepte,
  type JetonResolu,
  type MontantCentimes,
} from "@/types/encaissement";

const BASE = process.env.NEXT_PUBLIC_API_URL ?? "/api";

type CorpsErreur = { error?: { code?: string; message?: string } };

/**
 * Lit une réponse et transforme tout échec en `ErreurEncaissement`.
 *
 * Le point qui compte : un échec ne remonte jamais comme un succès. Une
 * réponse non-ok ne rend pas un objet vide que l'appelant confondrait avec
 * une transaction — elle lève. C'est exactement le trou qu'un test de la
 * maquette avait attrapé.
 */
async function lire<T>(reponse: Response): Promise<T> {
  if (reponse.ok) return (await reponse.json()) as T;

  let corps: CorpsErreur = {};
  try {
    corps = (await reponse.json()) as CorpsErreur;
  } catch {
    /* réponse sans corps JSON : on garde le message par défaut */
  }

  const code = (corps.error?.code ?? "inconnu") as CodeErreurEncaissement;
  const message = corps.error?.message ?? `Le serveur a répondu ${reponse.status}.`;
  throw new ErreurEncaissement(code, message);
}

/** Résout un jeton présenté par un salarié. Lève si expiré, déjà utilisé ou inconnu. */
export async function resoudreJeton(token: string): Promise<JetonResolu> {
  let reponse: Response;
  try {
    reponse = await fetch(`${BASE}/payment-tokens/${encodeURIComponent(token)}`, {
      cache: "no-store",
    });
  } catch {
    throw new ErreurEncaissement("reseau", "Le service est injoignable.");
  }
  return lire<JetonResolu>(reponse);
}

export type DemandeEncaissement = {
  token: string;
  partnerId: string;
  amount: MontantCentimes;
  /** Forgée à la caisse, une fois par tentative. Voir R3. */
  idempotencyKey: string;
  channel?: "qr" | "manuel";
};

/** Écrit l'encaissement au registre. */
export async function encaisser(demande: DemandeEncaissement): Promise<EncaissementAccepte> {
  let reponse: Response;
  try {
    reponse = await fetch(`${BASE}/transactions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(demande),
    });
  } catch {
    /* Le réseau a lâché. On ne sait pas si le serveur a écrit ou non : c'est
       précisément pourquoi la clé d'idempotence existe, et pourquoi elle ne
       doit pas changer si le caissier réessaie. */
    throw new ErreurEncaissement("reseau", "Le service est injoignable.");
  }

  const brut = await lire<{
    ref: string;
    amount: number;
    createdAt: number;
    employee: { id: string; name: string };
    __replayed?: boolean;
  }>(reponse);

  return {
    ref: brut.ref,
    amount: brut.amount,
    createdAt: brut.createdAt,
    employee: brut.employee,
    rejoue: brut.__replayed === true,
  };
}
