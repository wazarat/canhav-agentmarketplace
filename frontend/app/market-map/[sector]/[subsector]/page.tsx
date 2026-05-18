import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { Breadcrumbs } from "@/components/market-map/Breadcrumbs";
import { ErrorPanel } from "@/components/market-map/ErrorPanel";
import { ProjectTable } from "@/components/market-map/ProjectTable";
import {
  getSubsector,
  listSubsectorProjects,
  MarketMapError,
  type ProjectRow,
  type SubsectorDetail,
} from "@/lib/market-map";

interface PageProps {
  params: { sector: string; subsector: string };
}

export const revalidate = 60;

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
            {projects.length} project{projects.length === 1 ? "" : "s"}
          </span>
        </div>

        {error ? (
          <div className="mt-10">
            <ErrorPanel title="Subsector data warming up" detail={error} />
          </div>
        ) : null}

        <div className="mt-8">
          <ProjectTable
            projects={projects}
            sectorSlug={params.sector}
            subsectorSlug={params.subsector}
            emptyHint="This subsector is on deck — projects will appear here once they're ingested from the source sheet."
          />
        </div>
      </div>
    </section>
  );
}
