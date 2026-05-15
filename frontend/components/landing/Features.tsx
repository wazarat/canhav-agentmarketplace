import Link from "next/link";
import { ArrowUpRight, BookOpen, Map, Bot, Check } from "lucide-react";

import { SITE, cn } from "@/lib/utils";

interface FeatureBlockProps {
  eyebrow: string;
  title: string;
  body: string;
  bullets: string[];
  cta: { label: string; href: string; external?: boolean };
  icon: React.ComponentType<{ className?: string }>;
  reverse?: boolean;
  visual: React.ReactNode;
}

function FeatureBlock({
  eyebrow,
  title,
  body,
  bullets,
  cta,
  icon: Icon,
  reverse,
  visual,
}: FeatureBlockProps) {
  return (
    <div
      className={cn(
        "grid items-center gap-10 lg:grid-cols-2 lg:gap-16",
        reverse && "lg:[&>:first-child]:order-2",
      )}
    >
      <div>
        <div className="inline-flex items-center gap-2 rounded-full glass px-3 py-1 text-xs text-ink-100">
          <Icon className="h-3.5 w-3.5 text-signal-400" />
          <span className="font-mono uppercase tracking-wider text-ink-300">
            {eyebrow}
          </span>
        </div>
        <h3 className="mt-4 font-display text-3xl font-semibold tracking-tight text-ink-50 sm:text-[34px]">
          {title}
        </h3>
        <p className="mt-4 text-ink-100/85">{body}</p>
        <ul className="mt-6 space-y-2.5 text-sm text-ink-100">
          {bullets.map((b) => (
            <li key={b} className="flex items-start gap-2.5">
              <Check className="mt-0.5 h-4 w-4 shrink-0 text-signal-400" />
              <span>{b}</span>
            </li>
          ))}
        </ul>
        <div className="mt-7">
          <Link
            href={cta.href}
            target={cta.external ? "_blank" : undefined}
            rel={cta.external ? "noopener noreferrer" : undefined}
            className="group inline-flex items-center gap-2 text-sm font-medium text-electric-400 hover:text-white"
          >
            {cta.label}
            <ArrowUpRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
          </Link>
        </div>
      </div>

      <div className="relative">
        <div className="glass relative overflow-hidden rounded-3xl p-1 glow-ring">
          <div className="rounded-[22px] bg-ink-950/80 p-6">{visual}</div>
        </div>
      </div>
    </div>
  );
}

function ResearchVisual() {
  return (
    <div className="space-y-3">
      {[
        { tag: "L2 Infra", title: "The state of L2 sequencing — Q2", date: "Apr 24" },
        { tag: "AI x Crypto", title: "Why agent payments need stable L2s", date: "Apr 17" },
        { tag: "DeFi", title: "Permissionless intent markets, mapped", date: "Apr 10" },
      ].map((p) => (
        <div
          key={p.title}
          className="flex items-center justify-between rounded-2xl border border-ink-700/60 bg-ink-900/40 p-3.5"
        >
          <div className="flex min-w-0 items-center gap-3">
            <span className="rounded-md bg-electric-500/15 px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider text-electric-400">
              {p.tag}
            </span>
            <span className="truncate text-sm text-ink-50">{p.title}</span>
          </div>
          <span className="ml-3 shrink-0 font-mono text-[11px] text-ink-300">
            {p.date}
          </span>
        </div>
      ))}
    </div>
  );
}

function MarketMapVisual() {
  const sectors = [
    { name: "Infra", count: 92 },
    { name: "Wallets", count: 41 },
    { name: "DeFi", count: 134 },
    { name: "AI Agents", count: 67 },
    { name: "Identity", count: 28 },
    { name: "Data", count: 53 },
  ];
  return (
    <div className="grid grid-cols-3 gap-2.5">
      {sectors.map((s) => (
        <div
          key={s.name}
          className="rounded-xl border border-ink-700/60 bg-ink-900/40 p-3"
        >
          <div className="font-mono text-[10px] uppercase tracking-wider text-ink-300">
            {s.name}
          </div>
          <div className="mt-1 flex items-baseline gap-1">
            <span className="font-display text-xl font-semibold text-ink-50">
              {s.count}
            </span>
            <span className="text-[10px] text-ink-300">projects</span>
          </div>
          <div className="mt-2 h-1 overflow-hidden rounded-full bg-ink-800">
            <div
              className="h-full bg-gradient-to-r from-electric-500 to-neon-500"
              style={{ width: `${Math.min(100, s.count)}%` }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}

function AgentsVisual() {
  return (
    <div className="space-y-3">
      <div className="rounded-2xl border border-ink-700/60 bg-ink-900/40 p-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="font-mono text-[10px] uppercase tracking-wider text-ink-300">
              agent.summary
            </div>
            <div className="font-display text-base font-semibold text-ink-50">
              market-research-bot
            </div>
          </div>
          <span className="rounded-full bg-signal-500/15 px-2 py-0.5 font-mono text-[10px] text-signal-400">
            ● online
          </span>
        </div>
        <div className="mt-3 grid grid-cols-3 gap-2 text-[11px]">
          <Stat k="reqs/day" v="14.2k" />
          <Stat k="p95" v="412ms" />
          <Stat k="rev" v="$3.7k" />
        </div>
      </div>
      <div className="rounded-2xl border border-ink-700/60 bg-ink-900/40 p-4">
        <div className="font-mono text-[10px] uppercase tracking-wider text-ink-300">
          settlement
        </div>
        <div className="mt-2 flex items-center justify-between text-sm text-ink-100">
          <span>0xA19…f42 → 0x71b…0c4</span>
          <span className="font-mono text-electric-400">0.085 ETH</span>
        </div>
        <div className="mt-1 text-[11px] text-ink-300">
          Arbitrum Sepolia · tx confirmed
        </div>
      </div>
    </div>
  );
}

function Stat({ k, v }: { k: string; v: string }) {
  return (
    <div className="rounded-md bg-ink-800/60 p-2">
      <div className="font-mono text-[10px] uppercase tracking-wider text-ink-300">
        {k}
      </div>
      <div className="mt-0.5 text-sm font-semibold text-ink-50">{v}</div>
    </div>
  );
}

export function Features() {
  return (
    <section className="container space-y-24 py-24">
      <FeatureBlock
        eyebrow="Research"
        icon={BookOpen}
        title="Founder-grade research, delivered weekly."
        body="Deep dives on infra, agents, and the parts of the ecosystem that actually move. Written by people building, for people building."
        bullets={[
          "New piece every week, no fluff",
          "Frameworks you can apply on Monday",
          "Free during alpha",
        ]}
        cta={{ label: "Read the latest on Substack", href: SITE.research, external: true }}
        visual={<ResearchVisual />}
      />

      <FeatureBlock
        reverse
        eyebrow="Market Map"
        icon={Map}
        title="Hundreds of projects, mapped and current."
        body="Stop hunting through Notion docs and dead repos. Search the ecosystem by sector, status, and traction — all in one place."
        bullets={[
          "500+ projects across infra, DeFi, agents, wallets",
          "Updated continuously by our research team",
          "API access on request for power users",
        ]}
        cta={{ label: "Preview the Market Map", href: "/market-map" }}
        visual={<MarketMapVisual />}
      />

      <FeatureBlock
        eyebrow="Agents"
        icon={Bot}
        title="Train, ship, and monetize your agent."
        body="We give your agent everything it needs to be trained — datasets, evals, tooling — and a marketplace to sell its work to other agents."
        bullets={[
          "Bring-your-own-model. We handle data + evals.",
          "List your agent in our marketplace at launch",
          "On-chain settlement on Arbitrum",
        ]}
        cta={{ label: "How agents work on CanHav", href: "/agents" }}
        visual={<AgentsVisual />}
      />
    </section>
  );
}
