import Link from "next/link";
import { ArrowUpRight } from "lucide-react";

import type { ProjectRow } from "@/lib/market-map";

interface ProjectTableProps {
  projects: ProjectRow[];
  sectorSlug: string;
  subsectorSlug: string;
  emptyHint?: string;
}

function formatFunding(usd: number | null): string | null {
  if (!usd || usd <= 0) return null;
  if (usd >= 1_000_000_000) return `$${(usd / 1_000_000_000).toFixed(1)}B`;
  if (usd >= 1_000_000) return `$${(usd / 1_000_000).toFixed(1)}M`;
  if (usd >= 1_000) return `$${(usd / 1_000).toFixed(0)}K`;
  return `$${usd}`;
}

export function ProjectTable({ projects, sectorSlug, subsectorSlug, emptyHint }: ProjectTableProps) {
  if (projects.length === 0) {
    return (
      <div className="glass rounded-2xl p-6 text-sm text-ink-300">
        {emptyHint ?? "No projects ingested for this subsector yet."}
      </div>
    );
  }

  void sectorSlug;
  void subsectorSlug;

  return (
    <div className="overflow-hidden rounded-2xl border border-ink-700/60 bg-ink-900/40">
      <table className="w-full text-left text-sm">
        <thead className="bg-ink-900/60 text-[11px] uppercase tracking-wider text-ink-300">
          <tr>
            <th className="px-4 py-3 font-mono font-normal">Project</th>
            <th className="px-4 py-3 font-mono font-normal">Status</th>
            <th className="px-4 py-3 font-mono font-normal">Stage</th>
            <th className="px-4 py-3 font-mono font-normal">Funding</th>
            <th className="px-4 py-3 font-mono font-normal">Links</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-ink-700/40">
          {projects.map((p) => {
            const funding = formatFunding(p.total_funding_usd);
            return (
              <tr key={p.id} className="transition hover:bg-ink-900/60">
                <td className="px-4 py-3">
                  <Link
                    href={`/market-map/project/${p.slug}`}
                    className="group inline-flex items-center gap-2 font-medium text-ink-50 hover:text-electric-400"
                  >
                    {p.name}
                    <ArrowUpRight className="h-3.5 w-3.5 opacity-0 transition group-hover:opacity-100" />
                  </Link>
                  {p.description && (
                    <p className="mt-1 line-clamp-1 text-[12px] text-ink-300">{p.description}</p>
                  )}
                </td>
                <td className="px-4 py-3 text-ink-100">
                  {p.status ? (
                    <span className="rounded-md bg-ink-800/60 px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider text-ink-100">
                      {p.status}
                    </span>
                  ) : (
                    <span className="text-ink-300">—</span>
                  )}
                </td>
                <td className="px-4 py-3 text-ink-100">{p.stage ?? <span className="text-ink-300">—</span>}</td>
                <td className="px-4 py-3 font-mono text-ink-100">{funding ?? <span className="text-ink-300">—</span>}</td>
                <td className="px-4 py-3">
                  <div className="flex items-center gap-3 text-xs text-ink-300">
                    {p.website_url && (
                      <a
                        href={p.website_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="hover:text-electric-400"
                      >
                        site
                      </a>
                    )}
                    {p.twitter_handle && (
                      <a
                        href={`https://x.com/${p.twitter_handle}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="hover:text-electric-400"
                      >
                        x
                      </a>
                    )}
                    {p.github_url && (
                      <a
                        href={p.github_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="hover:text-electric-400"
                      >
                        github
                      </a>
                    )}
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
