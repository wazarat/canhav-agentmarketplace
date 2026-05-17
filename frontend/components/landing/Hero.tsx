import { ArrowRight, Sparkles } from "lucide-react";
import Link from "next/link";

import { AgentNetwork } from "@/components/landing/AgentNetwork";
import { Button } from "@/components/ui/Button";
import { SITE } from "@/lib/utils";

export function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div className="container relative grid items-center gap-12 py-12 lg:grid-cols-[1.1fr_1fr] lg:gap-16 lg:py-20">
        <div className="relative">
          <div className="inline-flex animate-fade-in-up items-center gap-2 rounded-full glass px-3 py-1 text-xs font-medium text-ink-100 [animation-delay:0ms]">
            <Sparkles className="h-3.5 w-3.5 text-signal-400" />
            <span>For web3 + AI agent developers</span>
            <span className="h-1 w-1 rounded-full bg-ink-500" />
            <span className="text-ink-300">Now in private alpha</span>
          </div>

          <h1 className="mt-5 animate-fade-in-up font-display text-5xl font-semibold leading-[1.05] tracking-tight text-ink-50 [animation-delay:60ms] sm:text-6xl lg:text-[68px]">
            The builder intelligence for shipping{" "}
            <span className="text-gradient-brand">web3 products</span> with{" "}
            <span className="text-gradient-brand">AI agents</span>.
          </h1>

          <p className="mt-6 max-w-xl animate-fade-in-up text-lg leading-relaxed text-ink-100/85 [animation-delay:140ms]">
            Use CanHav to research blockchain ecosystems, train smarter agents,
            and turn AI agent workflows into products that can be deployed and
            monetized on-chain.
          </p>

          <div className="mt-8 flex animate-fade-in-up flex-wrap items-center gap-3 [animation-delay:220ms]">
            <Button asChild size="lg">
              <a href="#waitlist">
                Join the waitlist
                <ArrowRight className="h-4 w-4" />
              </a>
            </Button>
            <Button asChild size="lg" variant="secondary">
              <Link href={SITE.research} target="_blank" rel="noopener noreferrer">
                Read research
              </Link>
            </Button>
          </div>

          <div className="mt-10 flex animate-fade-in-up flex-wrap items-center gap-x-8 gap-y-3 text-xs text-ink-300 [animation-delay:340ms]">
            <Stat label="Projects mapped" value="500+" />
            <span className="hidden h-3 w-px bg-ink-700 sm:inline-block" />
            <Stat label="Research pieces" value="weekly" />
            <span className="hidden h-3 w-px bg-ink-700 sm:inline-block" />
            <Stat label="Marketplace" value="Agentic Economy" />
          </div>
        </div>

        <div className="relative mx-auto flex w-full animate-fade-in-up justify-center [animation-delay:120ms]">
          <AgentNetwork />
        </div>
      </div>
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline gap-2">
      <span className="font-display text-base font-semibold text-ink-50">
        {value}
      </span>
      <span className="uppercase tracking-wider">{label}</span>
    </div>
  );
}
