import Link from "next/link";

import type { SubsectorSummary } from "@/lib/market-map";

interface SubsectorGridProps {
  sectorSlug: string;
  subsectors: SubsectorSummary[];
}

export function SubsectorGrid({ sectorSlug, subsectors }: SubsectorGridProps) {
  if (subsectors.length === 0) {
    return (
      <div className="glass rounded-2xl p-6 text-sm text-ink-300">
        No subsectors yet for this sector.
      </div>
    );
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {subsectors.map((sub) => (
        <Link
          key={sub.subsector_slug}
          href={`/market-map/${sectorSlug}/${sub.subsector_slug}`}
          className="group rounded-2xl border border-ink-700/60 bg-ink-900/40 p-5 transition hover:border-electric-500/60 hover:bg-ink-900/70"
        >
          <div className="font-mono text-[10px] uppercase tracking-wider text-ink-300">
            {String(sub.subsector_display_order).padStart(2, "0")}
          </div>
          <h3 className="mt-1 font-display text-base font-semibold text-ink-50 group-hover:text-electric-400">
            {sub.subsector_name}
          </h3>
          {sub.subsector_description && (
            <p className="mt-2 line-clamp-2 text-sm text-ink-100/80">
              {sub.subsector_description}
            </p>
          )}
          <div className="mt-4 flex items-baseline justify-between">
            <span className="text-xs text-ink-300">
              {sub.project_count} project{sub.project_count === 1 ? "" : "s"}
            </span>
            <span className="font-mono text-[10px] text-electric-400">View →</span>
          </div>
        </Link>
      ))}
    </div>
  );
}
