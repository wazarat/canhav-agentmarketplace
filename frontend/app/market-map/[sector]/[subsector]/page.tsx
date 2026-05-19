import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { Breadcrumbs } from "@/components/market-map/Breadcrumbs";
import { CanonicalSpecCard } from "@/components/market-map/CanonicalSpecCard";
import { ErrorPanel } from "@/components/market-map/ErrorPanel";
import { ProjectTable } from "@/components/market-map/ProjectTable";
import {
  getSubsector,
  listSubsectorProjects,
  MarketMapError,
  type ProjectRow,
  type SubsectorDetail,
} from "@/lib/market-map";

function isCanonical(p: ProjectRow): boolean {
  const sector = (p.sector_attributes ?? {}) as Record<string, unknown>;
  const productionStatus =
    typeof sector.production_status === "string" ? sector.production_status.toLowerCase() : "";
  const entityType = typeof sector.entity_type === "string" ? sector.entity_type.toLowerCase() : "";
  return productionStatus === "canonical" || entityType.includes("specification");
}

interface PageProps {
  params: { sector: string; subsector: string };
}

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const sub = await getSubsector(params.subsector).catch(() => null);
  if (!sub) {
    return { title: "Market Map — Subsector" };
  }
  return {
    title: `${sub.name} — Market Map`,
    description: sub.description ?? undefined,
  };
}

export default async function SubsectorPage({ params }: PageProps) {
  let error: string | null = null;
  let sub: SubsectorDetail | null = null;
  let projects: ProjectRow[] = [];
  try {
    sub = await getSubsector(params.subsector);
    if (sub) {
      projects = await listSubsectorProjects(sub.slug, { limit: 200 });
    }
  } catch (err) {
    error =
      err instanceof MarketMapError
        ? `Market Map API returned ${err.status}.`
        : "Could not reach the Market Map API.";
  }

  if (!sub && !error) {
    notFound();
  }

  const canonical = projects.filter(isCanonical);
  const others = projects.filter((p) => !isCanonical(p));

  return (
    <section className="relative overflow-hidden">
      <div className="container max-w-6xl py-12 sm:py-16">
        <Breadcrumbs
          crumbs={[
            { label: "Market Map", href: "/market-map" },
            { label: sub?.sector?.name ?? params.sector, href: `/market-map/${params.sector}` },
            { label: sub?.name ?? params.subsector },
          ]}
        />

        <h1 className="mt-6 font-display text-4xl font-semibold leading-[1.1] tracking-tight text-ink-50 sm:text-5xl">
          {sub?.name ?? params.subsector}
        </h1>
        {sub?.description && (
          <p className="mt-4 max-w-2xl text-ink-100/85">{sub.description}</p>
        )}

        <div className="mt-6 flex flex-wrap items-center gap-3 font-mono text-[11px] uppercase tracking-wider text-ink-300">
          <span className="rounded-full border border-ink-700/80 bg-ink-900/50 px-3 py-1">
            {projects.length} entit{projects.length === 1 ? "y" : "ies"}
          </span>
          {canonical.length > 0 && (
            <span className="rounded-full border border-amber-300/30 bg-amber-300/5 px-3 py-1 text-amber-100">
              {canonical.length} canonical spec{canonical.length === 1 ? "" : "s"}
            </span>
          )}
          {others.length > 0 && (
            <span className="rounded-full border border-ink-700/80 bg-ink-900/50 px-3 py-1">
              {others.length} client{others.length === 1 ? "" : "s"}
            </span>
          )}
        </div>

        {error ? (
          <div className="mt-10">
            <ErrorPanel title="Subsector data warming up" detail={error} />
          </div>
        ) : null}

        {canonical.length > 0 && (
          <div className="mt-10 space-y-6">
            {canonical.map((spec) => (
              <CanonicalSpecCard key={spec.id} project={spec} />
            ))}
          </div>
        )}

        {others.length > 0 && (
          <div className="mt-10">
            <div className="mb-3 flex items-baseline justify-between">
              <h2 className="font-display text-xl font-semibold text-ink-50">
                Implementations
              </h2>
              <p className="font-mono text-[10px] uppercase tracking-wider text-ink-300">
                All implementations conform to the canonical spec above
              </p>
            </div>
            <ProjectTable
              projects={others}
              sectorSlug={params.sector}
              subsectorSlug={params.subsector}
              emptyHint="No implementations ingested yet."
            />
          </div>
        )}

        {canonical.length === 0 && others.length === 0 && !error && (
          <div className="mt-8">
            <ProjectTable
              projects={[]}
              sectorSlug={params.sector}
              subsectorSlug={params.subsector}
              emptyHint="This subsector is on deck — projects will appear here once they're ingested from the source sheet."
            />
          </div>
        )}
      </div>
    </section>
  );
}
