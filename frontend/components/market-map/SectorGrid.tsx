import Link from "next/link";
import { ArrowUpRight } from "lucide-react";

import type { SectorSummary } from "@/lib/market-map";

interface SectorGridProps {
  sectors: SectorSummary[];
}

export function SectorGrid({ sectors }: SectorGridProps) {
  if (sectors.length === 0) {
    return (
      <div className="glass rounded-2xl p-6 text-sm text-ink-300">
        No sectors available yet. Check back soon.
      </div>
    );
  }

  const maxProjects = Math.max(1, ...sectors.map((s) => s.project_count));

  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {sectors.map((sector) => {
        const pct = Math.max(6, Math.round((sector.project_count / maxProjects) * 100));
        return (
          <Link
            key={sector.sector_slug}
            href={`/market-map/${sector.sector_slug}`}
            className="group relative overflow-hidden rounded-2xl border border-ink-700/60 bg-ink-900/40 p-5 transition hover:border-electric-500/60 hover:bg-ink-900/70"
          >
            <div className="flex items-start justify-between">
              <div>
                <div className="font-mono text-[10px] uppercase tracking-wider text-ink-300">
                  Sector {String(sector.sector_display_order).padStart(2, "0")}
                </div>
                <h3 className="mt-1 font-display text-lg font-semibold text-ink-50">
                  {sector.sector_name}
                </h3>
              </div>
              <ArrowUpRight className="h-4 w-4 text-ink-300 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5 group-hover:text-electric-400" />
            </div>
            {sector.sector_description && (
              <p className="mt-3 line-clamp-2 text-sm text-ink-100/80">
                {sector.sector_description}
              </p>
            )}
            <div className="mt-4 flex items-baseline gap-3">
              <span className="font-display text-2xl font-semibold text-ink-50">
                {sector.project_count}
              </span>
              <span className="text-xs text-ink-300">
                project{sector.project_count === 1 ? "" : "s"}
              </span>
              <span className="ml-auto font-mono text-[10px] text-ink-300">
                {sector.subsector_count} subsector
                {sector.subsector_count === 1 ? "" : "s"}
              </span>
            </div>
            <div className="mt-3 h-1 overflow-hidden rounded-full bg-ink-800">
              <div
                className="h-full bg-gradient-to-r from-electric-500 to-neon-500 transition-[width]"
                style={{ width: `${pct}%` }}
              />
            </div>
          </Link>
        );
      })}
    </div>
  );
}
