import Link from "next/link";
import { ArrowUpRight, ShieldCheck } from "lucide-react";

import { ProjectLogo } from "@/components/market-map/ProjectLogo";
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

function stringAttr(obj: Record<string, unknown> | null | undefined, key: string): string | null {
  if (!obj) return null;
  const v = obj[key];
  return typeof v === "string" && v.length > 0 ? v : null;
}

/**
 * Sniff which columns are interesting given the actual rows.
 * Goal: don't show columns where every value is null/TBD — that's just noise.
 */
function chooseColumns(projects: ProjectRow[]) {
  const has = (pred: (p: ProjectRow) => unknown) => projects.some((p) => Boolean(pred(p)));
  return {
    org: has((p) => stringAttr(p.sector_attributes, "maintaining_organization")),
    productionStatus: has((p) => stringAttr(p.sector_attributes, "production_status")),
    language: has((p) => stringAttr(p.subsector_attributes, "implementation_language")),
    diversity: has((p) => stringAttr(p.subsector_attributes, "client_diversity_risk")),
    funding: has((p) => p.total_funding_usd && p.total_funding_usd > 0),
    stage: has((p) => p.stage && p.stage.toLowerCase() !== "unknown"),
  };
}

function ProductionStatusPill({ value }: { value: string }) {
  const norm = value.toLowerCase();
  const styles =
    norm === "canonical"
      ? "border-amber-300/40 bg-amber-300/10 text-amber-100"
      : norm === "production-major"
        ? "border-electric-500/40 bg-electric-500/10 text-electric-400"
        : norm === "production-stable"
          ? "border-signal-400/40 bg-signal-400/10 text-signal-400"
          : norm === "production-limited"
            ? "border-ink-500/60 bg-ink-800/60 text-ink-100"
            : "border-ink-700/80 bg-ink-900/60 text-ink-200";
  return (
    <span
      className={`inline-flex items-center rounded-md border px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider ${styles}`}
    >
      {value}
    </span>
  );
}

function LanguagePill({ value }: { value: string }) {
  return (
    <span className="inline-flex items-center rounded-md border border-neon-500/40 bg-neon-500/10 px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider text-neon-400">
      {value}
    </span>
  );
}

function DiversityPill({ value }: { value: string }) {
  const norm = value.toLowerCase();
  const styles = norm.includes("positive")
    ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-300"
    : norm === "high"
      ? "border-rose-500/40 bg-rose-500/10 text-rose-300"
      : norm === "medium"
        ? "border-amber-500/40 bg-amber-500/10 text-amber-200"
        : norm === "low"
          ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-300"
          : "border-ink-700/80 bg-ink-900/60 text-ink-200";
  return (
    <span
      className={`inline-flex items-center rounded-md border px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider ${styles}`}
    >
      {value}
    </span>
  );
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

  const cols = chooseColumns(projects);

  return (
    <div className="overflow-hidden rounded-2xl border border-ink-700/60 bg-ink-900/40">
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead className="bg-ink-900/60 text-[11px] uppercase tracking-wider text-ink-300">
            <tr>
              <th className="px-4 py-3 font-mono font-normal">Project</th>
              {cols.org && <th className="px-4 py-3 font-mono font-normal">Maintained by</th>}
              {cols.language && <th className="px-4 py-3 font-mono font-normal">Language</th>}
              {cols.productionStatus && (
                <th className="px-4 py-3 font-mono font-normal">Production</th>
              )}
              {cols.diversity && <th className="px-4 py-3 font-mono font-normal">Diversity</th>}
              {cols.stage && <th className="px-4 py-3 font-mono font-normal">Stage</th>}
              {cols.funding && <th className="px-4 py-3 font-mono font-normal">Funding</th>}
              <th className="px-4 py-3 font-mono font-normal">Links</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-ink-700/40">
            {projects.map((p) => {
              const org = stringAttr(p.sector_attributes, "maintaining_organization");
              const productionStatus = stringAttr(p.sector_attributes, "production_status");
              const language = stringAttr(p.subsector_attributes, "implementation_language");
              const diversity = stringAttr(p.subsector_attributes, "client_diversity_risk");
              const funding = formatFunding(p.total_funding_usd);
              const isCanonical =
                productionStatus?.toLowerCase() === "canonical" ||
                stringAttr(p.sector_attributes, "entity_type")?.toLowerCase().includes(
                  "specification",
                );

              return (
                <tr
                  key={p.id}
                  className={`transition ${
                    isCanonical
                      ? "bg-amber-300/[0.04] hover:bg-amber-300/[0.07]"
                      : "hover:bg-ink-900/60"
                  }`}
                >
                  <td className="px-4 py-3 align-top">
                    <Link
                      href={`/market-map/project/${p.slug}`}
                      className="group flex items-start gap-3"
                    >
                      <ProjectLogo project={p} size="sm" />
                      <div className="min-w-0 flex-1">
                        <div className="inline-flex items-center gap-1.5 font-medium text-ink-50 group-hover:text-electric-400">
                          {isCanonical && (
                            <ShieldCheck
                              className="h-3.5 w-3.5 text-amber-300"
                              aria-label="Canonical specification"
                            />
                          )}
                          {p.name}
                          <ArrowUpRight className="h-3.5 w-3.5 opacity-0 transition group-hover:opacity-100" />
                        </div>
                        {p.description && (
                          <p className="mt-1 line-clamp-1 text-[12px] text-ink-300">
                            {p.description}
                          </p>
                        )}
                      </div>
                    </Link>
                  </td>
                  {cols.org && (
                    <td className="px-4 py-3 align-top text-ink-100">
                      {org ?? <span className="text-ink-300">—</span>}
                    </td>
                  )}
                  {cols.language && (
                    <td className="px-4 py-3 align-top">
                      {language ? (
                        <LanguagePill value={language} />
                      ) : (
                        <span className="text-ink-300">—</span>
                      )}
                    </td>
                  )}
                  {cols.productionStatus && (
                    <td className="px-4 py-3 align-top">
                      {productionStatus ? (
                        <ProductionStatusPill value={productionStatus} />
                      ) : (
                        <span className="text-ink-300">—</span>
                      )}
                    </td>
                  )}
                  {cols.diversity && (
                    <td className="px-4 py-3 align-top">
                      {diversity ? (
                        <DiversityPill value={diversity} />
                      ) : (
                        <span className="text-ink-300">—</span>
                      )}
                    </td>
                  )}
                  {cols.stage && (
                    <td className="px-4 py-3 align-top text-ink-100">
                      {p.stage ?? <span className="text-ink-300">—</span>}
                    </td>
                  )}
                  {cols.funding && (
                    <td className="px-4 py-3 align-top font-mono text-ink-100">
                      {funding ?? <span className="text-ink-300">—</span>}
                    </td>
                  )}
                  <td className="px-4 py-3 align-top">
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
    </div>
  );
}
