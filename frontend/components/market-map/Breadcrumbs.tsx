import Link from "next/link";

interface Crumb {
  label: string;
  href?: string;
}

export function Breadcrumbs({ crumbs }: { crumbs: Crumb[] }) {
  return (
    <nav className="flex items-center gap-1.5 font-mono text-[11px] uppercase tracking-wider text-ink-300">
      {crumbs.map((c, idx) => (
        <span key={`${c.label}-${idx}`} className="flex items-center gap-1.5">
          {c.href ? (
            <Link href={c.href} className="hover:text-electric-400">
              {c.label}
            </Link>
          ) : (
            <span className="text-ink-100">{c.label}</span>
          )}
          {idx < crumbs.length - 1 && <span className="text-ink-500">/</span>}
        </span>
      ))}
    </nav>
  );
}
