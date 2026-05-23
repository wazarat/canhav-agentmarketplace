import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { EyeOff, ExternalLink, ShieldCheck } from "lucide-react";

import { Breadcrumbs } from "@/components/market-map/Breadcrumbs";
import { getProject, MarketMapError, type ProjectDetail } from "@/lib/market-map";

// Fields whose values are semicolon- or newline-separated lists in the source sheet.
// Rendering them as bullets dramatically improves scannability.
const LIST_FIELDS = new Set([
  "supported_networks",
  "role_in_consensus",
  "reason_for_inclusion",
  "practitioner_validation_check",
  // Sector 6 (Advanced Compute & Integration) list-shaped raw fields. The
  // importer dual-writes the canonical m2m rows into project_chains /
  // project_composes_with / project_token_standards / project_custodians /
  // project_identifier_standards / project_credential_standards, but the
  // raw semicolon-separated source string is preserved in subsector_attributes
  // so the project page still renders list bullets without an extra fetch.
  "chains_supported_raw",
  "supported_chains_raw",
  "composable_with_raw",
  "token_standard_raw",
  "identifier_standard_raw",
  "credential_standard_raw",
  "jurisdictions_raw",
  "custodians_raw",
]);

// Fields whose values are long-form prose paragraphs. We render them with
// whitespace-pre-line so author line breaks survive.
const PROSE_FIELDS = new Set([
  "practitioner_note",
  "practitioner_validation_check",
  "reason_for_inclusion",
  // Rollup & Scaling Frameworks long-form sidecar fields (surfaced via the
  // backend's SUBSECTOR_VIEW_REGISTRY projection).
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
  // Sector 4 (DeFi Systems Architecture) long-form fields.
  "description",
  "systemic_risk_exposure_text",
  "historical_stress_text",
  "historical_stress_events_text",
  "dependency_concentration_risk_text",
  "oracle_dependencies_text",
  "oracle_failure_mode_text",
  "upstream_dependencies_text",
  "downstream_consumers_text",
  "primary_role_in_defi",
  "avs_summary_text",
  "composes_on_text",
  "settlement_layer_text",
  "credit_issuance_mechanism",
  "liquidation_mechanism_text",
  "interest_rate_model_text",
  "redemption_mechanism_text",
  "slashing_conditions",
  "slashing_authority_text",
  "validator_selection_governance",
  "risk_transformation_text",
  "strategy_management_text",
  "rebalancing_logic_text",
  "strategy_change_control_text",
  "funding_premium_logic_text",
  "pricing_source_text",
  "margin_model_text",
  "liquidation_cascade_risk_text",
  "oracle_dependency_risk_text",
  "governance_override_risk_text",
  "slashing_contagion_risk_text",
  "operator_concentration_risk_text",
  "validator_concentration_risk_text",
  "governance_centralization_risk_text",
  "risk_isolation_text",
  "parameter_control_text",
  "risk_parameter_control_text",
  "exit_liquidity_risk",
  "accepted_as_collateral_text",
  "upgrade_admin_controls",
  "capital_lockups_text",
  "principal_protection_text",
  "leverage_usage_text",
  "underlying_yield_sources_text",
  "strategy_scope",
  "execution_mechanism_text",
  "price_discovery_method_text",
  "lp_model_text",
  "capital_efficiency_text",
  "mev_exposure_text",
  "fee_control_text",
  "integration_footprint",
  "lending_architecture_text",
  "collateral_class_text",
  // Sector 5 (Data & Consensus Infrastructure) long-form fields. Most narrative
  // cells come straight from the source sheet and run multiple paragraphs.
  "primary_role_in_stack",
  "ethereum_clients_supported",
  "execution_consensus_coverage",
  "rpc_interfaces_supported",
  "archive_node_support",
  "historical_depth",
  "geographic_distribution",
  "uptime_sla_claims",
  "decentralization_model",
  "censorship_resistance_characteristics",
  "client_diversity_risk",
  "known_outages_or_incidents",
  "pricing_model",
  "cost_sensitivity_at_scale",
  "rate_limits_throttling_model",
  "typical_users",
  "downstream_dependency_risk",
  "replaceability_score",
  // Oracles & DA & Indexing & Analytics shared narrative keys.
  "oracle_type",
  "primary_data_domain",
  "on_chain_footprint",
  "data_source_model",
  "verification_mechanism",
  "who_can_submit_data",
  "who_can_challenge_data",
  "freshness_guarantees",
  "correctness_guarantees",
  "availability_guarantees",
  "failure_handling_dispute_resolution",
  "security_model",
  "cost_model",
  "value_at_risk_alignment",
  "typical_protocol_dependencies",
  "downstream_economic_impact_if_incorrect",
  "centralization_risk_note",
  "known_exploits_or_incidents",
  "oracle_dependency_criticality",
  "da_type",
  "primary_da_consumer",
  "execution_coupling",
  "data_publication_method",
  "availability_guarantee_model",
  "who_can_withhold_data",
  "who_detects_withholding",
  "primary_failure_mode",
  "time_to_detect_failure",
  "recovery_path",
  "impact_of_da_failure",
  "cost_vs_ethereum_da",
  "scaling_characteristics",
  "known_incidents_or_risks",
  "da_dependency_criticality",
  "long_term_viability_risk",
  "indexer_type",
  "primary_data_coverage",
  "primary_users",
  "indexing_model",
  "query_interface",
  "real_time_support",
  "reorg_handling_strategy",
  "data_freshness_guarantees",
  "backfill_capability",
  "failure_modes",
  "rate_limits_quotas",
  "known_incidents_or_gaps",
  "indexing_dependency_criticality",
  "operational_complexity",
  "analytics_type",
  "primary_audience",
  "primary_inputs",
  "core_models_used",
  "time_horizon",
  "explainability_level",
  "data_freshness_dependence",
  "assumption_sensitivity",
  "known_biases_blind_spots",
  "typical_decision_impact",
  "narrative_influence_level",
  "decision_dependency_criticality",
  "epistemic_risk_level",
  // Sector 6 (Advanced Compute & Integration) long-form prose fields. Most
  // come from the source sheet's "Practitioner's Note" / "Description Long"
  // columns and span multiple sentences; rendering them with whitespace-pre-line
  // preserves the author's line breaks.
  "one_line_description",
  "description_long",
  "primary_use_case",
  "primary_use_cases",
  "primary_users",
  "primary_customers",
  "primary_participants_primary",
  "primary_participants_secondary",
  "primary_agent_function",
  "target_users",
  "inference_planning_method",
  "human_override_capability",
  "replayability",
  "failure_handling",
  "agent_identity_model",
  "permissioning_model",
  "permissioning_model_primary",
  "permissioning_model_secondary",
  "sybil_resistance",
  "fee_incentive_model",
  "fee_model",
  "value_accrual_primary",
  "value_accrual_secondary",
  "external_dependencies_primary",
  "external_dependencies_secondary",
  "primary_risk_factor_1",
  "primary_risk_factor_2",
  "censorship_resistance",
  "censorship_freeze_risk",
  "censorship_geographic_risk",
  "upgrade_governance_control",
  "upgrade_control",
  "defensibility_source",
  "sector_adjacency_risk",
  "scope_annotation",
  // RWA-specific narrative fields.
  "asset_issuer",
  "legal_structure",
  "jurisdiction_legal_enforceability",
  "redemption_rights",
  "investor_rights",
  "kyc_aml_enforcement",
  "transfer_restrictions",
  "bidirectional_sync",
  "final_source_of_truth",
  "cash_flow_handling",
  "dispute_resolution",
  "key_trusted_parties",
  "composable_with_defi",
  "scalability_constraints",
  // Identity-specific narrative fields.
  "reputation_attestation_type",
  "social_graph_model",
  "who_can_issue_credentials",
  "revocation_mechanism",
  "role_permission_enforcement",
  "centralized_dependency_value",
  "centralized_dependency_detail",
  "on_chain_verifiability_value",
  "on_chain_verifiability_detail",
  "smart_contract_composability_value",
  "smart_contract_composability_detail",
  "cross_protocol_reusability",
  // DePIN-specific narrative fields.
  "hardware_ownership_model",
  "coordinator_topology",
  "governance_control_dimension",
  "slashing_or_penalty_mechanism_detail",
  "slashing_detail",
  "minimum_physical_requirements",
  "on_chain_settlement_scope",
  "reward_distribution",
  "anti_cheating",
  "trusted_components",
  "token_incentive_model",
  "cost_structure_operators",
  "geographic_distribution_detail",
  "governance_model",
  // Cross-Chain Compute-specific narrative fields.
  "execution_location_primary",
  "execution_location_secondary",
  "execution_type_primary",
  "execution_type_secondary",
  "verification_mechanism_primary",
  "verification_mechanism_secondary",
  "verification_strength_tier",
  "who_verifies_execution_primary",
  "who_verifies_execution_secondary",
  "dispute_resolution_model",
  "finality_anchor",
  "trust_assumptions",
  "incentive_alignment",
]);

// RWA disclosure fields per ISS-S6-011 (Cursor + User decision: visible with
// "Not disclosed" badge rather than hidden). When the project's subsector is
// `real-world-assets-rwas` and one of these keys is absent or null, the
// project page renders a NotDisclosed badge instead of an em-dash so readers
// can see at a glance that a regulatory primitive is missing from the source
// data rather than from the model. Keys are intentionally the same shape as
// the rwa_details columns so the importer's dual-write path Just Works.
const RWA_DISCLOSURE_FIELDS = [
  "jurisdictions_raw",
  "asset_issuer",
  "asset_issuer_as_of_date",
  "legal_structure",
  "jurisdiction_legal_enforceability",
  "permissioning_model_primary",
  "custodians_raw",
  "custodians_as_of_date",
  "redemption_rights",
  "investor_rights",
  "kyc_aml_enforcement",
  "transfer_restrictions",
] as const;

const RWA_DISCLOSURE_FIELD_SET: ReadonlySet<string> = new Set(RWA_DISCLOSURE_FIELDS);

function isAbsentValue(value: unknown): boolean {
  if (value === null || value === undefined) return true;
  if (typeof value === "string" && value.trim() === "") return true;
  if (Array.isArray(value) && value.length === 0) return true;
  return false;
}

function NotDisclosedBadge() {
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full border border-ink-700/60 bg-ink-900/60 px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider text-ink-300"
      title="Source disclosed no value for this field. Treat absence as 'not disclosed', not 'not applicable'."
    >
      <EyeOff className="h-3 w-3" />
      Not disclosed
    </span>
  );
}

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

  // RWA disclosure UX (ISS-S6-011): inject any RWA disclosure key that's
  // missing from JSONB so the project page can render a "Not disclosed" badge
  // for it, instead of silently dropping the row. Only applied when the
  // project's primary subsector is `real-world-assets-rwas`.
  const isRwaSubsector = project.subsector_slug === "real-world-assets-rwas";
  if (isRwaSubsector) {
    const existingKeys = new Set(subsectorAttrs.map(([k]) => k));
    for (const k of RWA_DISCLOSURE_FIELDS) {
      if (!existingKeys.has(k)) subsectorAttrs.push([k, null]);
    }
  }

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
            subtitle={
              isRwaSubsector
                ? "Fields specific to this subsector. Regulatory and custodial fields render a 'Not disclosed' badge when the source disclosed no value (ISS-S6-011)."
                : "Fields specific to this subsector."
            }
            accent={canonical ? "amber" : "default"}
          >
            <dl>
              {subsectorAttrs.map(([key, value]) => {
                const renderAsBadge =
                  isRwaSubsector &&
                  RWA_DISCLOSURE_FIELD_SET.has(key) &&
                  isAbsentValue(value);
                return (
                  <FieldRow
                    key={key}
                    label={humanLabel(key, project.subsector?.specific_field_schema)}
                    value={renderAsBadge ? <NotDisclosedBadge /> : formatValue(value, key)}
                    alignTop={fieldNeedsTopAlign(key, value)}
                  />
                );
              })}
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
