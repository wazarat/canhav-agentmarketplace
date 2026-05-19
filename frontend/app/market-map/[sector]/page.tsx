import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { Breadcrumbs } from "@/components/market-map/Breadcrumbs";
import { ErrorPanel } from "@/components/market-map/ErrorPanel";
import { SubsectorGrid } from "@/components/market-map/SubsectorGrid";
import { getSector, MarketMapError } from "@/lib/market-map";

interface PageProps {
  params: { sector: string };
}

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const sector = await getSector(params.sector).catch(() => null);
  if (!sector) {
    return { title: "Market Map — Sector" };
  }
  return {
    title: `${sector.name} — Market Map`,
    description: sector.description ?? undefined,
  };
}

export default async function SectorPage({ params }: PageProps) {
  let error: string | null = null;
  let sector: Awaited<ReturnType<typeof getSector>> | null = null;
  try {
    sector = await getSector(params.sector);
  } catch (err) {
    error =
      err instanceof MarketMapError
        ? `Market Map API returned ${err.status}.`
        : "Could not reach the Market Map API.";
  }

  if (!sector && !error) {
    notFound();
  }

  const subsectorCount = sector?.subsectors.length ?? 0;
  const projectCount = sector?.subsectors.reduce((a, s) => a + s.project_count, 0) ?? 0;

  return (
    <section className="relative overflow-hidden">
      <div className="container max-w-6xl py-12 sm:py-16">
        <Breadcrumbs
          crumbs={[
            { label: "Market Map", href: "/market-map" },
            { label: sector?.name ?? params.sector },
          ]}
        />

        <h1 className="mt-6 font-display text-4xl font-semibold leading-[1.1] tracking-tight text-ink-50 sm:text-5xl">
          {sector?.name ?? params.sector}
        </h1>
        {sector?.description && (
          <p className="mt-4 max-w-2xl text-ink-100/85">{sector.description}</p>
        )}

        <div className="mt-6 flex flex-wrap items-center gap-3 font-mono text-[11px] uppercase tracking-wider text-ink-300">
          <span className="rounded-full border border-ink-700/80 bg-ink-900/50 px-3 py-1">
            {subsectorCount} subsector{subsectorCount === 1 ? "" : "s"}
          </span>
          <span className="rounded-full border border-ink-700/80 bg-ink-900/50 px-3 py-1">
            {projectCount} project{projectCount === 1 ? "" : "s"}
          </span>
        </div>

        {error ? (
          <div className="mt-10">
            <ErrorPanel title="Sector data warming up" detail={error} />
          </div>
        ) : null}

        <div className="mt-10">
          {sector && (
            <SubsectorGrid sectorSlug={sector.slug} subsectors={sector.subsectors} />
          )}
        </div>
      </div>
    </section>
  );
}
