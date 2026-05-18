"use client";

import { ArrowRight, CheckCircle2, Loader2 } from "lucide-react";
import posthog from "posthog-js";
import { useState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import {
  submitWaitlist,
  type WaitlistRole,
  type WaitlistSource,
} from "@/lib/api";
import { cn } from "@/lib/utils";

interface WaitlistFormProps {
  source?: WaitlistSource;
  className?: string;
  /** Compact mode hides the role selector (used in the footer/inline spots). */
  compact?: boolean;
}

const ROLES: { id: WaitlistRole; label: string }[] = [
  { id: "web3", label: "Web3 dev" },
  { id: "ai", label: "AI dev" },
  { id: "both", label: "Both" },
];

const SUBMIT_THROTTLE_MS = 1500;

export function WaitlistForm({
  source = "landing",
  className,
  compact = false,
}: WaitlistFormProps) {
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<WaitlistRole | undefined>(undefined);
  const [company, setCompany] = useState(""); // honeypot
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [lastSubmittedAt, setLastSubmittedAt] = useState(0);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting || done) return;

    const now = Date.now();
    if (now - lastSubmittedAt < SUBMIT_THROTTLE_MS) return;
    setLastSubmittedAt(now);

    if (!email.includes("@")) {
      toast.error("Please enter a valid email");
      return;
    }

    setSubmitting(true);
    try {
      const result = await submitWaitlist({ email, role, source, company });
      setDone(true);
      toast.success("You're on the list. We'll be in touch soon.");

      // PostHog: identify the lead and capture the conversion event.
      // Safe to no-op when PH isn't initialised (missing key in local dev).
      try {
        if (posthog.__loaded) {
          posthog.identify(email, {
            email,
            role: role ?? "unspecified",
            waitlist_source: source,
          });
          posthog.capture("waitlist_submitted", {
            source,
            role: role ?? "unspecified",
            lead_id: result.lead_id,
          });
        }
      } catch {
        /* analytics errors must never break the form */
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : "Something went wrong";
      toast.error(message);
      try {
        if (posthog.__loaded) {
          posthog.capture("waitlist_submit_failed", {
            source,
            role: role ?? "unspecified",
            message,
          });
        }
      } catch {
        /* ignore */
      }
    } finally {
      setSubmitting(false);
    }
  }

  if (done) {
    return (
      <div
        className={cn(
          "glass flex items-center gap-3 rounded-2xl px-5 py-4 text-sm text-ink-50",
          className,
        )}
      >
        <CheckCircle2 className="h-5 w-5 text-signal-400" />
        <span>
          You&apos;re in. Watch your inbox — we&apos;ll send the next research drop and
          early access invites first.
        </span>
      </div>
    );
  }

  return (
    <form
      onSubmit={onSubmit}
      className={cn("flex w-full flex-col gap-3", className)}
      noValidate
    >
      {/* Honeypot — hidden from real users via aria + tab + position */}
      <div className="hidden" aria-hidden="true">
        <label>
          Company
          <input
            type="text"
            tabIndex={-1}
            autoComplete="off"
            value={company}
            onChange={(e) => setCompany(e.target.value)}
          />
        </label>
      </div>

      <div className="flex w-full flex-col gap-2 sm:flex-row">
        <Input
          type="email"
          name="email"
          autoComplete="email"
          required
          placeholder="founder@yourstartup.xyz"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="sm:flex-1"
        />
        <Button
          type="submit"
          size="md"
          disabled={submitting}
          className="sm:w-auto"
        >
          {submitting ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              Joining…
            </>
          ) : (
            <>
              Join the waitlist
              <ArrowRight className="h-4 w-4" />
            </>
          )}
        </Button>
      </div>

      {!compact && (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs uppercase tracking-wider text-ink-300">
            I build for
          </span>
          {ROLES.map((r) => {
            const active = role === r.id;
            return (
              <button
                key={r.id}
                type="button"
                onClick={() => setRole(active ? undefined : r.id)}
                className={cn(
                  "rounded-full border px-3 py-1 text-xs transition-colors",
                  active
                    ? "border-electric-500 bg-electric-500/15 text-white"
                    : "border-ink-700 text-ink-300 hover:border-ink-500 hover:text-ink-100",
                )}
              >
                {r.label}
              </button>
            );
          })}
        </div>
      )}

      <p className="text-xs text-ink-300">
        No spam. Unsubscribe anytime. We&apos;ll only email you about CanHav.
      </p>
    </form>
  );
}
