import { CheckCircle2, Circle, Zap } from "lucide-react";

import { cn } from "@/lib/utils";

type Status = "live" | "next" | "later";

const STEPS: { title: string; sub: string; status: Status }[] = [
  {
    title: "Research",
    sub: "Weekly drops on infra, agents, and the parts of the ecosystem that move.",
    status: "live",
  },
  {
    title: "Market Map",
    sub: "Search 500+ projects by sector, status, and traction.",
    status: "next",
  },
  {
    title: "Agents",
    sub: "Train your agent end-to-end on the CanHav stack.",
    status: "next",
  },
  {
    title: "On-chain Marketplace",
    sub: "Specialized agents transacting with each other, settled on Arbitrum.",
    status: "later",
  },
];

const ICON: Record<Status, React.ComponentType<{ className?: string }>> = {
  live: CheckCircle2,
  next: Zap,
  later: Circle,
};

const PILL_STYLE: Record<Status, string> = {
  live: "bg-signal-500/15 text-signal-400 border-signal-500/30",
  next: "bg-electric-500/15 text-electric-400 border-electric-500/30",
  later: "bg-ink-800 text-ink-300 border-ink-700",
};

export function Roadmap() {
  return (
    <section className="container py-20">
      <p className="text-center font-mono text-xs uppercase tracking-[0.25em] text-signal-400">
        Roadmap
      </p>
      <h2 className="mx-auto mt-3 max-w-2xl text-center font-display text-3xl font-semibold tracking-tight text-ink-50 sm:text-4xl">
        Where we&apos;re going.
      </h2>
      <p className="mx-auto mt-3 max-w-xl text-center text-ink-300">
        Shipping in milestones. Each one independently useful.
      </p>

      <ol className="relative mx-auto mt-12 max-w-3xl space-y-4">
        <div className="absolute bottom-0 left-[19px] top-2 w-px bg-gradient-to-b from-electric-500/40 via-ink-700 to-transparent" />
        {STEPS.map((step, i) => {
          const Icon = ICON[step.status];
          return (
            <li
              key={step.title}
              className="relative flex items-start gap-5 rounded-2xl glass p-5"
            >
              <div
                className={cn(
                  "grid h-10 w-10 shrink-0 place-items-center rounded-full border",
                  PILL_STYLE[step.status],
                )}
              >
                <Icon className="h-5 w-5" />
              </div>
              <div className="flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-mono text-xs uppercase tracking-wider text-ink-300">
                    Step {String(i + 1).padStart(2, "0")}
                  </span>
                  <span
                    className={cn(
                      "rounded-full border px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider",
                      PILL_STYLE[step.status],
                    )}
                  >
                    {step.status === "live"
                      ? "Live"
                      : step.status === "next"
                        ? "Up next"
                        : "Later"}
                  </span>
                </div>
                <h3 className="mt-1 font-display text-lg font-semibold text-ink-50">
                  {step.title}
                </h3>
                <p className="mt-1 text-sm text-ink-300">{step.sub}</p>
              </div>
            </li>
          );
        })}
      </ol>
    </section>
  );
}
