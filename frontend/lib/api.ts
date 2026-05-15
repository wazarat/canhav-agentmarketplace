export type WaitlistRole = "web3" | "ai" | "both";
export type WaitlistSource = "landing" | "market-map" | "agents" | "footer" | "other";

export interface WaitlistPayload {
  email: string;
  role?: WaitlistRole;
  source?: WaitlistSource;
  /** Honeypot field — must remain empty. */
  company?: string;
}

export interface WaitlistResult {
  ok: boolean;
  lead_id?: string;
}

export async function submitWaitlist(payload: WaitlistPayload): Promise<WaitlistResult> {
  // We always go through our own /api/waitlist proxy so the browser never sees
  // the backend URL or has to deal with CORS quirks on preview deploys.
  const res = await fetch("/api/waitlist", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    let message = "Something went wrong. Please try again.";
    try {
      const data = (await res.json()) as { detail?: string | unknown };
      if (typeof data.detail === "string") message = data.detail;
    } catch {
      /* ignore */
    }
    throw new Error(message);
  }

  return (await res.json()) as WaitlistResult;
}
