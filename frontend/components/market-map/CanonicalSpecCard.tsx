import Link from "next/link";
import { ArrowUpRight, BookOpenCheck, ExternalLink, Github, ShieldCheck } from "lucide-react";

import type { ProjectRow } from "@/lib/market-map";

interface CanonicalSpecCardProps {
  project: ProjectRow;
  reasonForInclusion?: string | null;
}

function splitList(value: unknown): string[] {
  if (typeof value !== "string") return [];
  return value
    .split(/[;\n]+/)
    .map((s) => s.trim().replace(/^[-•]\s*/, ""))
    .filter(Boolean);
}

/**
 * Hero card for the authoritative spec entity in a subsector
 * (e.g. Ethereum Consensus Specifications for the Consensus Layer).
 *
 * Visually elevated above the regular project table: gradient border, gold
 * "Canonical Specification" badge, and the full "role in consensus" / "reason
 * for inclusion" bullet lists inline so practitioners see why everything else
 * below derives from it.
 */
export function CanonicalSpecCard({ project, reasonForInclusion }: CanonicalSpecCardProps) {
  const sector = (project.sector_attributes ?? {}) as Record<string, unknown>;
  const subsector = (project.subsector_attributes ?? {}) as Record<string, unknown>;

  const maintainingOrg = typeof sector.maintaining_organization === "string"
    ? sector.maintaining_organization
    : null;
  const entityType = typeof sector.entity_type === "string" ? sector.entity_type : null;
  const supportedNetworks = splitList(sector.supported_networks);
  const license = typeof sector.license === "string" ? sector.license : null;
  const productionStatus = typeof sector.production_status === "string"
    ? sector.production_status
    : null;
  const roleInConsensus = splitList(subsector.role_in_consensus);
  const clientCategory = typeof subsector.client_category === "string"
    ? subsector.client_category
    : null;
  const clientScope = typeof subsector.client_scope === "string" ? subsector.client_scope : null;
  const reason = reasonForInclusion ?? (typeof sector.reason_for_inclusion === "string"
    ? sector.reason_for_inclusion
    : null);
  const reasonBullets = splitList(reason);

  return (
    <div className="relative">
      {/* Animated gradient border ring */}
      <div
        aria-hidden
        className="absolute -inset-px rounded-3xl bg-[conic-gradient(from_0deg,#f5c451,#3D7BFF,#8B5CF6,#22D3EE,#f5c451)] opacity-70 blur-[1px]"
      />
      <div className="relative overflow-hidden rounded-3xl border border-amber-300/20 bg-ink-950/85 p-6 sm:p-8">
        {/* Soft inner radial glow */}
        <div
          aria-hidden
          className="pointer-events-none absolute -right-24 -top-24 h-72 w-72 rounded-full bg-amber-400/10 blur-3xl"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute -left-32 -bottom-24 h-72 w-72 rounded-full bg-electric-500/10 blur-3xl"
        />

        <div className="relative flex flex-wrap items-center gap-2">
          <span className="inline-flex items-center gap-1.5 rounded-full border border-amber-300/40 bg-amber-300/10 px-3 py-1 font-mono text-[10px] uppercase tracking-[0.18em] text-amber-200">
            <ShieldCheck className="h-3.5 w-3.5" />
            Canonical Specification
          </span>
          {entityType && (
            <span className="inline-flex items-center rounded-full border border-ink-700/80 bg-ink-900/60 px-2.5 py-1 font-mono text-[10px] uppercase tracking-wider text-ink-200">
              {entityType}
            </span>
          )}
          {productionStatus && (
            <span className="inline-flex items-center rounded-full border border-amber-300/30 bg-amber-300/5 px-2.5 py-1 font-mono text-[10px] uppercase tracking-wider text-amber-100">
              {productionStatus}
            </span>
          )}
          {license && (
            <span className="inline-flex items-center rounded-full border border-ink-700/80 bg-ink-900/60 px-2.5 py-1 font-mono text-[10px] uppercase tracking-wider text-ink-200">
              {license}
            </span>
          )}
        </div>

        <div className="relative mt-5 flex flex-wrap items-baseline justify-between gap-4">
          <div>
            <h2 className="font-display text-2xl font-semibold leading-tight tracking-tight text-ink-50 sm:text-3xl">
              <span className="bg-gradient-to-r from-amber-200 via-ink-50 to-amber-200 bg-clip-text text-transparent">
                {project.name}
              </span>
            </h2>
            {maintainingOrg && (
              <p className="mt-1 text-sm text-ink-300">
                Maintained by{" "}
                <span className="text-ink-100">{maintainingOrg}</span>
              </p>
            )}
          </div>
          <Link
            href={`/market-map/project/${project.slug}`}
            className="inline-flex items-center gap-1.5 rounded-lg border border-amber-300/30 bg-amber-300/10 px-3 py-1.5 font-mono text-[11px] uppercase tracking-wider text-amber-100 transition hover:border-amber-300/60 hover:bg-amber-300/20"
          >
            Open spec
            <ArrowUpRight className="h-3.5 w-3.5" />
          </Link>
        </div>

        {project.description && (
          <p className="relative mt-4 max-w-3xl text-[15px] leading-relaxed text-ink-100/90">
            {project.description}
          </p>
        )}

        {/* Why-it's-here grid */}
        {(roleInConsensus.length > 0 || reasonBullets.length > 0) && (
          <div className="relative mt-6 grid gap-5 sm:grid-cols-2">
            {roleInConsensus.length > 0 && (
              <div>
                <div className="font-mono text-[10px] uppercase tracking-wider text-amber-200/80">
                  Role in consensus
                </div>
                <ul className="mt-2 space-y-1.5 text-sm text-ink-100/90">
                  {roleInConsensus.map((r, i) => (
                    <li key={i} className="flex gap-2">
                      <span className="mt-1.5 inline-block h-1 w-1 shrink-0 rounded-full bg-amber-300/70" />
                      <span>{r}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
            {reasonBullets.length > 0 && (
              <div>
                <div className="font-mono text-[10px] uppercase tracking-wider text-amber-200/80">
                  Why it&apos;s canonical
                </div>
                <ul className="mt-2 space-y-1.5 text-sm text-ink-100/90">
                  {reasonBullets.map((r, i) => (
                    <li key={i} className="flex gap-2">
                      <BookOpenCheck className="mt-0.5 h-3.5 w-3.5 shrink-0 text-amber-300/70" />
                      <span>{r}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        )}

        {/* Meta strip */}
        <div className="relative mt-6 grid gap-3 border-t border-ink-700/60 pt-5 sm:grid-cols-3">
          {clientCategory && (
            <MetaCell label="Category" value={clientCategory} />
          )}
          {clientScope && (
            <MetaCell label="Scope" value={clientScope} />
          )}
          {supportedNetworks.length > 0 && (
            <MetaCell label="Supported networks" value={supportedNetworks.join(" · ")} />
          )}
        </div>

        {/* Links */}
        {(project.website_url || project.github_url) && (
          <div className="relative mt-5 flex flex-wrap items-center gap-4 text-sm">
            {project.website_url && (
              <a
                href={project.website_url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 text-amber-200 hover:text-white"
              >
                Documentation <ExternalLink className="h-3.5 w-3.5" />
              </a>
            )}
            {project.github_url && (
              <a
                href={project.github_url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 text-amber-200 hover:text-white"
              >
                <Github className="h-3.5 w-3.5" /> consensus-specs
              </a>
            )}
            <span className="ml-auto font-mono text-[10px] uppercase tracking-wider text-ink-300">
              All clients below conform to this spec
            </span>
          </div>
        )}
      </div>
    </div>
  );
}

function MetaCell({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="font-mono text-[10px] uppercase tracking-wider text-ink-300">{label}</div>
      <div className="mt-1 text-sm text-ink-100">{value}</div>
    </div>
  );
}
