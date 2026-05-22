import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ExternalLink, ShieldCheck } from "lucide-react";

import { Breadcrumbs } from "@/components/market-map/Breadcrumbs";
import { getProject, MarketMapError, type ProjectDetail } from "@/lib/market-map";

// Fields whose values are semicolon- or newline-separated lists in the source sheet.
// Rendering them as bullets dramatically improves scannability.
const LIST_FIELDS = new Set([
  "supported_networks",
  "role_in_consensus",
  "reason_for_inclusion",
  "practitioner_validation_check",
]);

// Fields whose values are long-form prose paragraphs. We render them with
// whitespace-pre-line so author line breaks survive.
const PROSE_FIELDS = new Set([
  "practitioner_note",
  "practitioner_validation_check",
  "reason_for_inclusion",
  // Rollup & Scaling Frameworks long-form sidecar fields (surfaced via the
  // backend's `_merge_sector2_view` projection).
  "inclusion_rationale",
  "security_model_summary",
  "execution_model_summary",
  "settlement_summary",
  "governance_summary",
  "ownership_summary",
  "roadmap_summary",
  "operational_risk_summary",
  "framework_architecture_summary",
  "deployment_model_summary",
  "interoperability_summary",
  // Sector 3 (Monetary & Access Rails) long-form fields.
  "peg_enforcement_mechanism",
  "stress_event_behavior",
  "decentralization_impact",
  "yield_mechanism_description",
  "historical_regulatory_actions",
  "reserve_composition",
  "primary_function",
  "primary_use_case",
  "ethereum_deployment",
  "ethereum_support",
  "regulatory_status",
  "governance_control",
  "redemption_availability",
  "collateralization_requirement",
]);

function splitList(value: string): string[] {
  return value
    .split(/[;\n]+/)
    .map((s) => s.trim().replace(/^[-•]\s*/, ""))
    .filter(Boolean);
}

function isCanonicalProject(p: ProjectDetail): boolean {
  const sector = (p.sector_attributes ?? {}) as Record<string, unknown>;
  const productionStatus =
    typeof sector.production_status === "string" ? sector.production_status.toLowerCase() : "";
  const entityType = typeof sector.entity_type === "string" ? sector.entity_type.toLowerCase() : "";
  return productionStatus === "canonical" || entityType.includes("specification");
}

interface PageProps {
  params: { slug: string };
}

export const dynamic = "force-dynamic";

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

function FieldRow({
  label,
  value,
  alignTop = false,
}: {
  label: string;
  value: React.ReactNode;
  alignTop?: boolean;
}) {
  return (
    <div
      className={`flex flex-col gap-1 border-b border-ink-700/40 py-3 last:border-b-0 sm:flex-row sm:gap-6 ${
        alignTop ? "sm:items-start" : "sm:items-baseline"
      }`}
    >
      <dt className="font-mono text-[10px] uppercase tracking-wider text-ink-300 sm:w-56 sm:shrink-0 sm:pt-0.5">
        {label}
      </dt>
      <dd className="min-w-0 flex-1 text-sm text-ink-100">{value}</dd>
    </div>
  );
}

function humanLabel(key: string, schema?: Record<string, unknown> | null): string {
  const props = (schema?.properties as Record<string, { title?: string; description?: string }> | undefined) ?? {};
  return props[key]?.title ?? key.replace(/_/g, " ");
}

function formatValue(value: unknown, key?: string): React.ReactNode {
  if (value === null || value === undefined || value === "") return <span className="text-ink-300">—</span>;
  if (typeof value === "boolean") return value ? "yes" : "no";
  if (typeof value === "number") return value.toLocaleString();
  if (Array.isArray(value)) {
    if (value.length === 0) return <span className="text-ink-300">—</span>;
    // Array of plain objects -> stacked card list (forward-compatible; not used by
    // Sector 3 v1 but sets the renderer up for arrays-of-objects in future bundles).
    if (value.every((v) => v !== null && typeof v === "object" && !Array.isArray(v))) {
      return (
        <ul className="space-y-2">
          {value.map((item, i) => {
            const obj = item as Record<string, unknown>;
            return (
              <li
                key={i}
                className="rounded-md border border-ink-700/40 bg-ink-900/40 px-3 py-2 text-xs"
              >
                <dl className="space-y-0.5">
                  {Object.entries(obj).map(([k, v]) => (
                    <div key={k} className="flex gap-2">
                      <dt className="font-mono uppercase tracking-wider text-ink-300">
                        {k.replace(/_/g, " ")}:
                      </dt>
                      <dd className="text-ink-100">{formatValue(v)}</dd>
                    </div>
                  ))}
                </dl>
              </li>
            );
          })}
        </ul>
      );
    }
    // String arrays >= 2 items render as bullets for scannability; single-element
    // arrays render inline so they don't waste vertical space.
    if (value.length >= 2 && value.every((v) => typeof v === "string")) {
      return (
        <ul className="space-y-1.5">
          {(value as string[]).map((it, i) => (
            <li key={i} className="flex gap-2 text-ink-100">
              <span className="mt-1.5 inline-block h-1 w-1 shrink-0 rounded-full bg-electric-500/70" />
              <span>{it}</span>
            </li>
          ))}
        </ul>
      );
    }
    return value.join(", ");
  }
  if (typeof value === "object") return <code className="text-xs text-ink-300">{JSON.stringify(value)}</code>;
  const raw = String(value);
  if (key && LIST_FIELDS.has(key)) {
    const items = splitList(raw);
    if (items.length > 1) {
      return (
        <ul className="space-y-1.5">
          {items.map((it, i) => (
            <li key={i} className="flex gap-2 text-ink-100">
              <span className="mt-1.5 inline-block h-1 w-1 shrink-0 rounded-full bg-electric-500/70" />
              <span>{it}</span>
            </li>
          ))}
        </ul>
      );
    }
  }
  if (key && PROSE_FIELDS.has(key)) {
    return <p className="whitespace-pre-line leading-relaxed text-ink-100/90">{raw}</p>;
  }
  return raw;
}

function fieldNeedsTopAlign(key: string, value?: unknown): boolean {
  if (LIST_FIELDS.has(key) || PROSE_FIELDS.has(key)) return true;
  if (Array.isArray(value) && value.length >= 2) return true;
  return false;
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
  const canonical = isCanonicalProject(project);

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

        {canonical && (
          <div className="mt-6 inline-flex items-center gap-1.5 rounded-full border border-amber-300/40 bg-amber-300/10 px-3 py-1 font-mono text-[10px] uppercase tracking-[0.18em] text-amber-200">
            <ShieldCheck className="h-3.5 w-3.5" />
            Canonical Specification — authoritative source for this subsector
          </div>
        )}

        <div className="mt-4 flex flex-wrap items-baseline gap-4">
          <h1
            className={`font-display text-4xl font-semibold tracking-tight sm:text-5xl ${
              canonical
                ? "bg-gradient-to-r from-amber-200 via-ink-50 to-amber-200 bg-clip-text text-transparent"
                : "text-ink-50"
            }`}
          >
            {project.name}
          </h1>
          {project.status && (
            <span className="rounded-full border border-ink-700/80 bg-ink-900/50 px-3 py-1 font-mono text-[10px] uppercase tracking-wider text-ink-100">
              {project.status}
            </span>
          )}
        </div>
        {(() => {
          const sa = (project.sector_attributes ?? {}) as Record<string, unknown>;
          const org = typeof sa.maintaining_organization === "string" ? sa.maintaining_organization : null;
          return org ? (
            <p className="mt-2 text-sm text-ink-300">
              Maintained by <span className="text-ink-100">{org}</span>
            </p>
          ) : null;
        })()}

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
            accent={canonical ? "amber" : "default"}
          >
            <dl>
              {sectorAttrs.map(([key, value]) => (
                <FieldRow
                  key={key}
                  label={humanLabel(key, project.sector?.common_field_schema)}
                  value={formatValue(value, key)}
                  alignTop={fieldNeedsTopAlign(key, value)}
                />
              ))}
            </dl>
          </Section>
        )}

        {subsectorAttrs.length > 0 && (
          <Section
            title={`${project.subsector?.name ?? "Subsector"} attributes`}
            subtitle="Fields specific to this subsector."
            accent={canonical ? "amber" : "default"}
          >
            <dl>
              {subsectorAttrs.map(([key, value]) => (
                <FieldRow
                  key={key}
                  label={humanLabel(key, project.subsector?.specific_field_schema)}
                  value={formatValue(value, key)}
                  alignTop={fieldNeedsTopAlign(key, value)}
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
  accent = "default",
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  accent?: "default" | "amber";
}) {
  const border =
    accent === "amber" ? "border-amber-300/20" : "border-ink-700/60";
  const bg = accent === "amber" ? "bg-amber-300/[0.03]" : "bg-ink-900/40";
  return (
    <div className={`mt-10 rounded-2xl border ${border} ${bg} p-5 sm:p-6`}>
      <h2 className="font-display text-lg font-semibold text-ink-50">{title}</h2>
      {subtitle && <p className="mt-1 text-xs text-ink-300">{subtitle}</p>}
      <div className="mt-4">{children}</div>
    </div>
  );
}
