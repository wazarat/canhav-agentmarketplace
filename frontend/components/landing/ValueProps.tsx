import { Coins, Cpu, Rocket } from "lucide-react";

import { Card, CardDescription, CardTitle } from "@/components/ui/Card";

const VALUE_PROPS = [
  {
    icon: Rocket,
    title: "Ship faster",
    body:
      "Curated, founder-grade research and a live market map mean less time scrolling Crypto Twitter and more time shipping.",
    accent: "from-electric-500 to-electric-700",
  },
  {
    icon: Cpu,
    title: "Trained agents, ready to deploy",
    body:
      "Bring your agent — we provide everything it needs to be trained: data, evals, tooling, and infra primitives.",
    accent: "from-neon-500 to-neon-600",
  },
  {
    icon: Coins,
    title: "Monetize on-chain",
    body:
      "List your agent on our upcoming Arbitrum marketplace. Specialized agents transact with each other, settled on-chain.",
    accent: "from-signal-500 to-electric-500",
  },
];

export function ValueProps() {
  return (
    <section className="container py-20">
      <SectionLabel>Why CanHav</SectionLabel>
      <h2 className="mx-auto mt-3 max-w-2xl text-center font-display text-3xl font-semibold tracking-tight text-ink-50 sm:text-4xl">
        One stack for the whole journey: research, build, monetize.
      </h2>
      <p className="mx-auto mt-4 max-w-xl text-center text-ink-300">
        Built for the developers actually shipping at the intersection of crypto
        and AI.
      </p>

      <div className="mt-12 grid gap-5 md:grid-cols-3">
        {VALUE_PROPS.map(({ icon: Icon, title, body, accent }) => (
          <Card key={title} className="group relative overflow-hidden">
            <div
              className={`mb-5 grid h-11 w-11 place-items-center rounded-xl bg-gradient-to-br ${accent} text-white shadow-lg shadow-electric-500/20`}
            >
              <Icon className="h-5 w-5" />
            </div>
            <CardTitle>{title}</CardTitle>
            <CardDescription className="mt-2">{body}</CardDescription>
            <div className="pointer-events-none absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-electric-500/40 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
          </Card>
        ))}
      </div>
    </section>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <p className="text-center font-mono text-xs uppercase tracking-[0.25em] text-signal-400">
      {children}
    </p>
  );
}
