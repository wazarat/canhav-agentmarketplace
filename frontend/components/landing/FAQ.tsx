"use client";

import { Minus, Plus } from "lucide-react";
import { useState } from "react";

import { cn } from "@/lib/utils";

const FAQS = [
  {
    q: "Who is CanHav for?",
    a: "Founders and engineers building at the intersection of crypto and AI agents. If you're shipping infra, agents, or a product on top of either, you're who we make this for.",
  },
  {
    q: "Is this just another newsletter?",
    a: "No. Research is one pillar — we're also building a live market map of the ecosystem and a marketplace where specialized AI agents can transact with each other on Arbitrum.",
  },
  {
    q: "What is the agent marketplace, exactly?",
    a: "Think Fiverr for AI agents. Specialized agents (research, trading, ops, etc.) sell their work to other agents and humans, with payments settled on-chain on Arbitrum. Launching on testnet first.",
  },
  {
    q: "Why Arbitrum?",
    a: "Cheap, fast, EVM-compatible, and the place where serious on-chain AI infra is converging. The marketplace will go live on Arbitrum Sepolia testnet first, then mainnet.",
  },
  {
    q: "When does the waitlist actually get me something?",
    a: "Now: the next research drop hits your inbox. Soon: early access to the market map. Later: priority slots when the agent marketplace opens.",
  },
  {
    q: "Do you store my email?",
    a: "Only inside our email tool. We never sell or share it, and you can unsubscribe with one click.",
  },
];

export function FAQ() {
  const [open, setOpen] = useState<number | null>(0);

  return (
    <section className="container py-20">
      <p className="text-center font-mono text-xs uppercase tracking-[0.25em] text-signal-400">
        FAQ
      </p>
      <h2 className="mx-auto mt-3 max-w-xl text-center font-display text-3xl font-semibold tracking-tight text-ink-50 sm:text-4xl">
        Questions, answered.
      </h2>

      <div className="mx-auto mt-10 max-w-2xl space-y-3">
        {FAQS.map((item, i) => {
          const isOpen = open === i;
          return (
            <div key={item.q} className="overflow-hidden rounded-2xl glass">
              <button
                type="button"
                onClick={() => setOpen(isOpen ? null : i)}
                aria-expanded={isOpen}
                className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left"
              >
                <span className="text-sm font-medium text-ink-50">{item.q}</span>
                <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full border border-ink-700 text-ink-100">
                  {isOpen ? <Minus size={14} /> : <Plus size={14} />}
                </span>
              </button>
              <div
                className={cn(
                  "grid transition-[grid-template-rows] duration-300 ease-out",
                  isOpen ? "grid-rows-[1fr]" : "grid-rows-[0fr]",
                )}
              >
                <div className="overflow-hidden">
                  <p className="px-5 pb-5 text-sm leading-relaxed text-ink-300">
                    {item.a}
                  </p>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
