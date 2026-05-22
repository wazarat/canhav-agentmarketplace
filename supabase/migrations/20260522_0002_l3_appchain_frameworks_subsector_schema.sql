-- M8.12 — Sector 2 / L3 & Appchain Frameworks subsector schema.
--
-- Adds public.l3_framework_attrs (sidecar) + public.l3_framework_full_view.
--
-- The L3 subsector hosts cross-subsector engines (op-stack from M8.10,
-- zk-stack from M8.11) alongside 5 new framework rows (arbitrum-orbit,
-- polygon-cdk, avalanche-hypersdk, caldera, conduit). Cross-subsector
-- members live as ONE row in public.projects (home subsector retained) plus
-- a row in public.subsector_memberships AND a row in this sidecar. The
-- l3_framework_full_view INNER JOINs to the sidecar to surface every entity
-- that participates in this subsector, regardless of where its home is.
--
-- Sidecar layout: 11 dual-enum split fields + 18 free-text preserved fields
-- + 1 snapshot-with-as_of_date (number_of_chains_deployed) + practitioner
-- columns + data_quality_flags.
--
-- See:
--   - .cursor/skills/market-map/sectors/rollup-scaling-frameworks/
--       subsectors/l3-appchain-frameworks.{md,narrative.md,data-sources.md,fields-to-add.md}
--   - docs/DECISIONS.md (M8.12 entry).

create table if not exists public.l3_framework_attrs (
  project_id uuid primary key references public.projects(id) on delete cascade,

  -- Tier 1 enum splits (paired with _text free-text companions).
  framework_archetype text,
    -- l3-framework | appchain-framework | rollup-factory | rollup-as-a-service | appchain-sdk-custom-vm
  framework_archetype_text text,
  framework_subtype text,
    -- engine | chain-launch-sdk | rollup-as-a-service | application-specific-engine
  abstraction_level text,
    -- low | medium | high | very-high
  abstraction_level_text text,
  engineering_burden_level text,
    -- none | minimal | limited | moderate | significant
  engineering_burden_text text,
  evm_compatibility_level text,
    -- evm-equivalent | evm-compatible | non-evm-custom | mixed-config-defined
  evm_compatibility_text text,
  configurable_parameters_text text,
  sequencer_model_options text,
    -- single | shared | decentralized | configurable | customizable
  sequencer_model_text text,
  upgrade_authority_level text,
    -- framework-controlled | chain-controlled | hybrid | dao-governed
  upgrade_model_text text,
  settlement_layer_kind text,
    -- ethereum-l1-direct | ethereum-l1-via-l2 | configurable
  settlement_layer_text text,
  security_inheritance_mode text,
    -- full-l1 | partial-l1 | configurable | partial-anchored | inherited-upstream
  security_inheritance_text text,
  security_inheritance_as_of_date date,
  proof_inheritance text,
    -- optimistic-inherited | validity-inherited | configurable | none-or-anchored | upstream-defined
  proof_inheritance_text text,
  security_topology text,
    -- isolated-per-chain | shared-across-deployments | configurable
  security_topology_text text,
  enables_l3s_bool boolean,
  enables_l3s_text text,

  -- Free-text preserves.
  base_layer_dependency_text text,
  failure_propagation_text text,
  latency_tradeoffs_text text,
  framework_ownership_text text,
  upgrade_control_text text,
  emergency_controls_text text,

  -- Risk + cost levels (dual-enum).
  sovereignty_level text,
    -- low | low-to-moderate | moderate | high
  sovereignty_text text,
  ops_complexity_level text,
    -- minimal | low | moderate | high
  ops_complexity_text text,
  fixed_vs_variable_costs_text text,
  infrastructure_responsibility_text text,
  vendor_lock_in_level text,
    -- low | low-to-moderate | moderate | moderate-to-high | high
  vendor_lock_in_text text,

  -- Snapshot with as_of_date companion.
  number_of_chains_deployed integer,
  number_of_chains_deployed_as_of_date date,
  number_of_chains_deployed_text text,

  -- Ecosystem fields.
  types_of_users_text text,
  ecosystem_alignment_text text,
  concentration_risk_level text,
    -- low | moderate | high
  concentration_risk_text text,

  -- Interop.
  native_interop_support_text text,
  composability_with_base_text text,
  cross_rollup_messaging_text text,
  external_bridge_required_bool boolean,
    -- nullable for OP Stack corrupted cell (data_gaps G-2)
  external_bridge_text text,

  -- Identity / context.
  inclusion_rationale text,
  practitioner_note text,
  practitioner_validation_check text,

  -- Audit.
  data_quality_flags text[] not null default '{}',
  not_applicable_reason text,
    -- 'data_unavailable' for OP Stack external_bridge corrupted cell
  data_refreshed_at timestamptz,
  data_confidence text default 'estimate',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.l3_framework_attrs is
  '1:1 sidecar for L3 & Appchain Frameworks subsector. Hosts 7 rows: 5 NEW '
  'projects (arbitrum-orbit, polygon-cdk, avalanche-hypersdk, caldera, conduit) '
  'plus 2 cross-subsector members (op-stack from M8.10, zk-stack from M8.11) '
  'whose home subsector lives elsewhere but who carry L3-specific attrs here.';

alter table public.l3_framework_attrs enable row level security;
drop policy if exists "l3_framework_attrs_public_read" on public.l3_framework_attrs;
create policy "l3_framework_attrs_public_read" on public.l3_framework_attrs for select using (true);

drop trigger if exists trg_l3_framework_attrs_updated_at on public.l3_framework_attrs;
create trigger trg_l3_framework_attrs_updated_at before update on public.l3_framework_attrs
  for each row execute procedure public.touch_updated_at();

-- View: INNER JOIN to sidecar so cross-subsector members surface here
-- regardless of projects.subsector_slug.
drop view if exists public.l3_framework_full_view;
create view public.l3_framework_full_view with (security_invoker = true) as
  select p.id as project_id, p.slug, p.name as display_name, p.description,
    p.website_url, p.logo_url, p.twitter_handle, p.github_url, p.status,
    p.sector_slug, p.subsector_slug,
    p.entity_role, p.framework_subtype as project_framework_subtype,
    p.instance_subtype, p.lifecycle_status, p.lifecycle_status_changed_at,
    p.settlement_layer, p.data_availability_layer, p.withdrawal_latency_minutes,
    p.is_aggregate, p.not_applicable_reason as project_not_applicable_reason,
    o.slug as org_slug, o.display_name as org_display_name, o.legal_name as org_legal_name,
    o.entity_type as org_entity_type, o.website_url as org_website_url,
    o.twitter_handle as org_twitter_handle, o.hq_country as org_hq_country,
    o.founded_year as org_founded_year, o.total_funding_usd as org_total_funding_usd,
    fp.slug as forked_from_slug, fp.name as forked_from_display_name,
    fp.entity_role as forked_from_role,
    a.framework_archetype, a.framework_archetype_text,
    a.framework_subtype as l3_framework_subtype,
    a.abstraction_level, a.abstraction_level_text,
    a.engineering_burden_level, a.engineering_burden_text,
    a.evm_compatibility_level, a.evm_compatibility_text,
    a.configurable_parameters_text,
    a.sequencer_model_options, a.sequencer_model_text,
    a.upgrade_authority_level, a.upgrade_model_text,
    a.settlement_layer_kind, a.settlement_layer_text,
    a.security_inheritance_mode, a.security_inheritance_text,
    a.security_inheritance_as_of_date,
    a.proof_inheritance, a.proof_inheritance_text,
    a.security_topology, a.security_topology_text,
    a.enables_l3s_bool, a.enables_l3s_text,
    a.base_layer_dependency_text, a.failure_propagation_text, a.latency_tradeoffs_text,
    a.framework_ownership_text, a.upgrade_control_text, a.emergency_controls_text,
    a.sovereignty_level, a.sovereignty_text,
    a.ops_complexity_level, a.ops_complexity_text,
    a.fixed_vs_variable_costs_text, a.infrastructure_responsibility_text,
    a.vendor_lock_in_level, a.vendor_lock_in_text,
    a.number_of_chains_deployed, a.number_of_chains_deployed_as_of_date,
    a.number_of_chains_deployed_text,
    a.types_of_users_text, a.ecosystem_alignment_text,
    a.concentration_risk_level, a.concentration_risk_text,
    a.native_interop_support_text, a.composability_with_base_text, a.cross_rollup_messaging_text,
    a.external_bridge_required_bool, a.external_bridge_text,
    a.inclusion_rationale, a.practitioner_note, a.practitioner_validation_check,
    a.data_quality_flags, a.not_applicable_reason as sidecar_not_applicable_reason,
    a.data_refreshed_at, a.data_confidence,
    p.created_at, p.updated_at
  from public.projects p
  left join public.organizations o on o.slug = p.maintaining_organization
  left join public.projects fp on fp.id = p.forked_from
  inner join public.l3_framework_attrs a on a.project_id = p.id;

comment on view public.l3_framework_full_view is
  'Frontend convenience view: projects + orgs + lineage + l3 sidecar joined. '
  'INNER JOIN to sidecar because membership in this subsector is defined by '
  'sidecar presence (cross-subsector members like op-stack and zk-stack live '
  'here via sidecar + subsector_memberships, not via projects.subsector_slug). '
  'M8.12.';
