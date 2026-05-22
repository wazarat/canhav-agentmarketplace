import type { Metadata } from "next";

import { ErrorPanel } from "@/components/market-map/ErrorPanel";
import { SectorGrid } from "@/components/market-map/SectorGrid";
import { listSectors, MarketMapError, type SectorSummary } from "@/lib/market-map";

export const metadata: Metadata = {
  title: "Market Map",
  description:
    "A live, searchable map of projects building across the blockchain ecosystem. Sector by sector, curated by the CanHav research team.",
};

// ISR: regenerate at most once per minute. The backend also emits
// `Cache-Control: public, max-age=60, stale-while-revalidate=300`, so warm
// Next.js caches + the backend's keep-alive Supabase client cut perceived
// latency to near-zero on warm navigations. Ingest scripts run out-of-band
// and can wait up to a minute to appear in the UI.
export const revalidate = 60;

export default async function MarketMapPage() {
  let sectors: SectorSummary[] = [];
  let error: string | null = null;
  try {
    sectors = await listSectors();
  } catch (err) {
    error =
      err instanceof MarketMapError
        ? `Market Map API returned ${err.status}.`
        : "Could not reach the Market Map API.";
  }

  const totalProjects = sectors.reduce((acc, s) => acc + s.project_count, 0);
  const totalSubsectors = sectors.reduce((acc, s) => acc + s.subsector_count, 0);

  return (
    <section className="relative overflow-hidden">
      <div className="container max-w-6xl py-16 sm:py-20">
        <div className="inline-flex items-center gap-2 rounded-full glass px-3 py-1 font-mono text-[11px] uppercase tracking-wider text-signal-400">
          <span className="h-1.5 w-1.5 animate-pulse-soft rounded-full bg-signal-400" />
          Market Map
        </div>
        <h1 className="mt-5 font-display text-4xl font-semibold leading-[1.05] tracking-tight text-ink-50 sm:text-5xl lg:text-[58px]">
          The live map of the{" "}
          <span className="text-gradient-brand">web3 ecosystem</span>.
        </h1>
        <p className="mt-6 max-w-2xl text-lg leading-relaxed text-ink-100/85">
          Seven sectors, {totalSubsectors || 36} subsectors, curated by the CanHav research
          team. Browse by sector, drill down into subsectors, or jump straight into a
          project.
        </p>

        <div className="mt-8 grid grid-cols-3 gap-2.5 max-w-xl">
          <Stat label="Sectors" value={String(sectors.length || 7)} />
          <Stat label="Subsectors" value={String(totalSubsectors || 36)} />
          <Stat label="Projects" value={String(totalProjects)} />
        </div>

        {error ? (
          <div className="mt-10">
            <ErrorPanel
              title="Market Map data is warming up"
              detail={`${error} Once Supabase is provisioned the sector grid below populates automatically.`}
            />
          </div>
        ) : null}

        <div className="mt-10">
          <SectorGrid sectors={sectors} />
        </div>
      </div>
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-ink-700/60 bg-ink-900/40 p-3">
      <div className="font-mono text-[10px] uppercase tracking-wider text-ink-300">{label}</div>
      <div className="mt-1 font-display text-xl font-semibold text-ink-50">{value}</div>
    </div>
  );
}
