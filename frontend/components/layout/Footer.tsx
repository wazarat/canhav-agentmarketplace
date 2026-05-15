import Link from "next/link";
import { Github, Twitter } from "lucide-react";

import { Logo } from "@/components/ui/Logo";
import { SITE } from "@/lib/utils";

export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="relative mt-32 border-t border-ink-800/60">
      <div className="container py-12">
        <div className="flex flex-col gap-8 md:flex-row md:items-start md:justify-between">
          <div className="max-w-sm space-y-3">
            <Logo />
            <p className="text-sm leading-relaxed text-ink-300">
              Research, infra, and an on-chain marketplace for web3 and AI agent
              developers. Ship faster. Monetize what you build.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-10 sm:grid-cols-3">
            <div>
              <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-ink-300">
                Product
              </p>
              <ul className="space-y-2 text-sm">
                <li>
                  <a
                    href={SITE.research}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-ink-100 hover:text-white"
                  >
                    Research
                  </a>
                </li>
                <li>
                  <Link href="/market-map" className="text-ink-100 hover:text-white">
                    Market Map
                  </Link>
                </li>
                <li>
                  <Link href="/agents" className="text-ink-100 hover:text-white">
                    Agents
                  </Link>
                </li>
              </ul>
            </div>

            <div>
              <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-ink-300">
                Company
              </p>
              <ul className="space-y-2 text-sm">
                <li>
                  <a href="#waitlist" className="text-ink-100 hover:text-white">
                    Waitlist
                  </a>
                </li>
                <li>
                  <a
                    href={`mailto:hello@canhav.com`}
                    className="text-ink-100 hover:text-white"
                  >
                    Contact
                  </a>
                </li>
              </ul>
            </div>

            <div>
              <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-ink-300">
                Connect
              </p>
              <ul className="flex gap-3">
                <li>
                  <a
                    href={SITE.socials.x}
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label="X / Twitter"
                    className="grid h-9 w-9 place-items-center rounded-full glass text-ink-100 hover:text-white"
                  >
                    <Twitter size={16} />
                  </a>
                </li>
                <li>
                  <a
                    href={SITE.socials.github}
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label="GitHub"
                    className="grid h-9 w-9 place-items-center rounded-full glass text-ink-100 hover:text-white"
                  >
                    <Github size={16} />
                  </a>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div className="mt-10 flex flex-col gap-2 border-t border-ink-800/60 pt-6 text-xs text-ink-300 sm:flex-row sm:items-center sm:justify-between">
          <p>&copy; {year} CanHav Research. All rights reserved.</p>
          <p className="font-mono text-[11px]">v0.1.0 · build_something_real</p>
        </div>
      </div>
    </footer>
  );
}
