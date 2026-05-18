import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ExternalLink } from "lucide-react";

import { Breadcrumbs } from "@/components/market-map/Breadcrumbs";
import { getProject, MarketMapError, type ProjectDetail } from "@/lib/market-map";

interface PageProps {
  params: { slug: string };
}

export const revalidate = 60;

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const project = await getProject(params.slug).catch(() => null);
  if (!project) {
    return { title: "Market Map — Project" };
  }
  return {
    title: `${project.name} — Market Map`,
    description: project.description ?? undefined,
  };
}

function FieldRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1 border-b border-ink-700/40 py-2.5 last:border-b-0 sm:flex-row sm:items-baseline sm:gap-6">
      <dt className="font-mono text-[10px] uppercase tracking-wider text-ink-300 sm:w-48 sm:shrink-0">
        {label}
      </dt>
      <dd className="text-sm text-ink-100">{value}</dd>
    </div>
  );
}

function humanLabel(key: string, schema?: Record<string, unknown> | null): string {
  const props = (schema?.properties as Record<string, { title?: string; description?: string }> | undefined) ?? {};
  return props[key]?.title ?? key.replace(/_/g, " ");
}

function formatValue(value: unknown): React.ReactNode {
  if (value === null || value === undefined || value === "") return <span className="text-ink-300">—</span>;
  if (typeof value === "boolean") return value ? "yes" : "no";
  if (typeof value === "number") return value.toLocaleString();
  if (Array.isArray(value)) return value.join(", ");
  if (typeof value === "object") return <code className="text-xs text-ink-300">{JSON.stringify(value)}</code>;
  return String(value);
}

function formatFunding(usd: number | null): string {
  if (!usd || usd <= 0) return "—";
  if (usd >= 1_000_000_000) return `$${(usd / 1_000_000_000).toFixed(1)}B`;
  if (usd >= 1_000_000) return `$${(usd / 1_000_000).toFixed(1)}M`;
  if (usd >= 1_000) return `$${(usd / 1_000).toFixed(0)}K`;
  return `$${usd}`;
}

export default async function ProjectPage({ params }: PageProps) {
  let project: ProjectDetail | null = null;
  try {
    project = await getProject(params.slug);
  } catch (err) {
    if (err instanceof MarketMapError && err.status === 404) {
      notFound();
    }
    throw err;
  }

  if (!project) notFound();

  const sectorAttrs = Object.entries(project.sector_attributes ?? {});
  const subsectorAttrs = Object.entries(project.subsector_attributes ?? {});

  return (
    <section className="relative overflow-hidden">
      <div className="container max-w-4xl py-12 sm:py-16">
        <Breadcrumbs
          crumbs={[
            { label: "Market Map", href: "/market-map" },
            {
              label: project.sector?.name ?? project.sector_slug,
              href: `/market-map/${project.sector_slug}`,
            },
            {
              label: project.subsector?.name ?? project.subsector_slug,
              href: `/market-map/${project.sector_slug}/${project.subsector_slug}`,
            },
            { label: project.name },
          ]}
        />

        <div className="mt-6 flex flex-wrap items-baseline gap-4">
          <h1 className="font-display text-4xl font-semibold tracking-tight text-ink-50 sm:text-5xl">
            {project.name}
          </h1>
          {project.status && (
            <span className="rounded-full border border-ink-700/80 bg-ink-900/50 px-3 py-1 font-mono text-[10px] uppercase tracking-wider text-ink-100">
              {project.status}
            </span>
          )}
        </div>

        {project.description && (
          <p className="mt-4 max-w-2xl text-ink-100/85">{project.description}</p>
        )}

        <div className="mt-6 flex flex-wrap items-center gap-4 text-sm">
          {project.website_url && (
            <a
              href={project.website_url}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 text-electric-400 hover:text-white"
            >
              Website <ExternalLink className="h-3.5 w-3.5" />
            </a>
          )}
          {project.twitter_handle && (
            <a
              href={`https://x.com/${project.twitter_handle}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 text-electric-400 hover:text-white"
            >
              @{project.twitter_handle} <ExternalLink className="h-3.5 w-3.5" />
            </a>
          )}
          {project.github_url && (
            <a
              href={project.github_url}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 text-electric-400 hover:text-white"
            >
              GitHub <ExternalLink className="h-3.5 w-3.5" />
            </a>
          )}
        </div>

        <Section title="Overview">
          <dl>
            <FieldRow label="Stage" value={formatValue(project.stage)} />
            <FieldRow label="Status" value={formatValue(project.status)} />
            <FieldRow label="Founded" value={formatValue(project.founded_year)} />
            <FieldRow label="HQ" value={formatValue(project.hq_country)} />
            <FieldRow label="Team size" value={formatValue(project.team_size_range)} />
            <FieldRow label="Total funding" value={formatFunding(project.total_funding_usd)} />
            <FieldRow label="Last round" value={formatValue(project.last_funding_round)} />
            <FieldRow label="Last round date" value={formatValue(project.last_funding_date)} />
          </dl>
        </Section>

        {sectorAttrs.length > 0 && (
          <Section
            title={`${project.sector?.name ?? "Sector"} attributes`}
            subtitle="Fields common to every project in this sector."
          >
            <dl>
              {sectorAttrs.map(([key, value]) => (
                <FieldRow
                  key={key}
                  label={humanLabel(key, project.sector?.common_field_schema)}
                  value={formatValue(value)}
                />
              ))}
            </dl>
          </Section>
        )}

        {subsectorAttrs.length > 0 && (
          <Section
            title={`${project.subsector?.name ?? "Subsector"} attributes`}
            subtitle="Fields specific to this subsector."
          >
            <dl>
              {subsectorAttrs.map(([key, value]) => (
                <FieldRow
                  key={key}
                  label={humanLabel(key, project.subsector?.specific_field_schema)}
                  value={formatValue(value)}
                />
              ))}
            </dl>
          </Section>
        )}

        <div className="mt-12">
          <Link
            href={`/market-map/${project.sector_slug}/${project.subsector_slug}`}
            className="font-mono text-[11px] uppercase tracking-wider text-ink-300 hover:text-electric-400"
          >
            ← Back to {project.subsector?.name ?? project.subsector_slug}
          </Link>
        </div>
      </div>
    </section>
  );
}

function Section({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="mt-10 rounded-2xl border border-ink-700/60 bg-ink-900/40 p-5 sm:p-6">
      <h2 className="font-display text-lg font-semibold text-ink-50">{title}</h2>
      {subtitle && <p className="mt-1 text-xs text-ink-300">{subtitle}</p>}
      <div className="mt-4">{children}</div>
    </div>
  );
}
