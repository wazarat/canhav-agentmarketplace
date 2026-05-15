import Link from "next/link";
import { ArrowLeft } from "lucide-react";

import { WaitlistForm } from "@/components/landing/WaitlistForm";
import type { WaitlistSource } from "@/lib/api";

interface ComingSoonShellProps {
  eyebrow: string;
  title: React.ReactNode;
  description: string;
  bullets?: string[];
  source: WaitlistSource;
  badges?: string[];
}

export function ComingSoonShell({
  eyebrow,
  title,
  description,
  bullets,
  source,
  badges,
}: ComingSoonShellProps) {
  return (
    <section className="relative overflow-hidden">
      <div className="container max-w-4xl py-16 sm:py-20">
        <Link
          href="/"
          className="group inline-flex items-center gap-2 text-sm text-ink-300 hover:text-ink-100"
        >
          <ArrowLeft className="h-4 w-4 transition-transform group-hover:-translate-x-0.5" />
          Back to home
        </Link>

        <div className="mt-8 inline-flex items-center gap-2 rounded-full glass px-3 py-1 font-mono text-[11px] uppercase tracking-wider text-signal-400">
          <span className="h-1.5 w-1.5 animate-pulse-soft rounded-full bg-signal-400" />
          {eyebrow}
        </div>

        <h1 className="mt-5 font-display text-4xl font-semibold leading-[1.05] tracking-tight text-ink-50 sm:text-5xl lg:text-[58px]">
          {title}
        </h1>

        <p className="mt-6 max-w-2xl text-lg leading-relaxed text-ink-100/85">
          {description}
        </p>

        {badges && badges.length > 0 && (
          <div className="mt-6 flex flex-wrap gap-2">
            {badges.map((b) => (
              <span
                key={b}
                className="rounded-full border border-ink-700/80 bg-ink-900/50 px-3 py-1 font-mono text-[11px] uppercase tracking-wider text-ink-300"
              >
                {b}
              </span>
            ))}
          </div>
        )}

        {bullets && bullets.length > 0 && (
          <ul className="mt-8 grid gap-3 sm:grid-cols-2">
            {bullets.map((b) => (
              <li
                key={b}
                className="glass flex items-start gap-3 rounded-2xl p-4 text-sm text-ink-100"
              >
                <span className="mt-1 h-1.5 w-1.5 shrink-0 rounded-full bg-electric-500" />
                <span>{b}</span>
              </li>
            ))}
          </ul>
        )}

        <div className="mt-12 rounded-3xl glass p-6 sm:p-8 glow-ring">
          <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-signal-400">
            Get early access
          </p>
          <h2 className="mt-2 font-display text-2xl font-semibold text-ink-50 sm:text-3xl">
            Be the first in when we open this up.
          </h2>
          <p className="mt-2 text-sm text-ink-300">
            Drop your email — we&apos;ll send a single message the moment this
            tab goes live.
          </p>
          <div className="mt-6 max-w-xl">
            <WaitlistForm source={source} />
          </div>
        </div>
      </div>
    </section>
  );
}
