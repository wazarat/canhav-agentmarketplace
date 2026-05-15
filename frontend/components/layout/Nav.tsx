"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Menu, X } from "lucide-react";

import { Button } from "@/components/ui/Button";
import { Logo } from "@/components/ui/Logo";
import { cn, SITE } from "@/lib/utils";

const NAV_LINKS = [
  { label: "Research", href: SITE.research, external: true },
  { label: "Market Map", href: "/market-map", external: false },
  { label: "Agents", href: "/agents", external: false },
];

export function Nav() {
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 transition-all duration-300",
        scrolled ? "py-2" : "py-4",
      )}
    >
      <div className="container">
        <nav
          className={cn(
            "flex items-center justify-between rounded-full px-4 py-2.5 transition-all duration-300",
            scrolled ? "glass-strong" : "glass",
          )}
        >
          <Link href="/" className="flex items-center gap-2 pl-1">
            <Logo />
          </Link>

          <ul className="hidden items-center gap-1 md:flex">
            {NAV_LINKS.map((link) => {
              const isActive = !link.external && pathname === link.href;
              return (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    target={link.external ? "_blank" : undefined}
                    rel={link.external ? "noopener noreferrer" : undefined}
                    className={cn(
                      "inline-flex h-9 items-center rounded-full px-4 text-sm transition-colors",
                      isActive
                        ? "bg-ink-800/70 text-white"
                        : "text-ink-100 hover:bg-ink-800/50 hover:text-white",
                    )}
                  >
                    {link.label}
                  </Link>
                </li>
              );
            })}
          </ul>

          <div className="hidden md:block">
            <Button asChild size="sm" className="!h-9">
              <a href="#waitlist">Join waitlist</a>
            </Button>
          </div>

          <button
            type="button"
            aria-label="Toggle navigation"
            aria-expanded={open}
            onClick={() => setOpen((v) => !v)}
            className="grid h-9 w-9 place-items-center rounded-full text-ink-100 hover:bg-ink-800/60 md:hidden"
          >
            {open ? <X size={18} /> : <Menu size={18} />}
          </button>
        </nav>

        {open && (
          <div className="glass-strong mt-2 overflow-hidden rounded-3xl p-3 md:hidden">
            <ul className="flex flex-col">
              {NAV_LINKS.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    target={link.external ? "_blank" : undefined}
                    rel={link.external ? "noopener noreferrer" : undefined}
                    className="block rounded-2xl px-4 py-3 text-sm text-ink-100 hover:bg-ink-800/60 hover:text-white"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
            <a
              href="#waitlist"
              className="mt-2 inline-flex h-11 w-full items-center justify-center rounded-full bg-gradient-to-b from-electric-500 to-electric-700 text-sm font-medium text-white btn-glow"
            >
              Join waitlist
            </a>
          </div>
        )}
      </div>
    </header>
  );
}
