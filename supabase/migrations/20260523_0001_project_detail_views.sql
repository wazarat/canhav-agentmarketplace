-- Market Map perf — extend the Sector-2 rollup `*_full_view`s with sector +
-- subsector schema joins so the project detail page can be served from a
-- single PostgREST hit when a view is mapped (see backend `get_project`).
--
-- WHY THIS LANDS NOW.
-- The Market Map tab is slow because (1) the FastAPI backend was rebuilding
-- its httpx client per call, (2) the project detail route made 3-4 sequential
-- PostgREST round-trips, and (3) Next.js had `force-dynamic` everywhere with
-- no cache headers. The connection-reuse + asyncio.gather changes already
-- collapse the project page to ~1 RTT; this migration is the structural
-- counterpart on the SQL side: every rollup view now also returns the
-- sector.common_field_schema + subsector.specific_field_schema in the same
-- row, so the backend can collapse the embedded `select=*,sector(...),
-- subsector(...)` + parallel view fetch into a single GET against the view
-- alone in a follow-up. No backend changes are *required* by this migration
-- — it is additive (CREATE OR REPLACE appends columns; existing consumers
-- see the same columns in the same positions and types).
--
-- WHAT THIS MIGRATION ADDS.
--   Four columns appended to each of the four rollup views:
--     - sector_name                       (sectors.name)
--     - subsector_name                    (subsectors.name)
--     - sector_common_field_schema        (sectors.common_field_schema)
--     - subsector_specific_field_schema   (subsectors.specific_field_schema)
--
--   And two new joins on each view:
--     - left join public.sectors    s_meta  on s_meta.slug   = p.sector_slug
--     - left join public.subsectors sub_meta on sub_meta.slug = p.subsector_slug
--
-- All security_invoker = true; RLS continues to be enforced at the caller.

-- ---------------------------------------------------------------------------
-- 1. public.optimistic_rollup_full_view
-- ---------------------------------------------------------------------------

create or replace view public.optimistic_rollup_full_view
  with (security_invoker = true)
as
  select
    p.id                                                              as project_id,
    p.slug                                                            as slug,
    p.name                                                            as display_name,
    p.description                                                     as description,
    p.website_url                                                     as website_url,
    p.logo_url                                                        as logo_url,
    p.twitter_handle                                                  as twitter_handle,
    p.github_url                                                      as github_url,
    p.status                                                          as status,
    p.sector_slug                                                     as sector_slug,
    p.subsector_slug                                                  as subsector_slug,

    p.entity_role                                                     as entity_role,
    p.framework_subtype                                               as framework_subtype,
    p.instance_subtype                                                as instance_subtype,
    p.lifecycle_status                                                as lifecycle_status,
    p.lifecycle_status_changed_at                                     as lifecycle_status_changed_at,
    p.settlement_layer                                                as settlement_layer,
    p.data_availability_layer                                         as data_availability_layer,
    p.withdrawal_latency_minutes                                      as withdrawal_latency_minutes,

    p.is_aggregate                                                    as is_aggregate,
    p.not_applicable_reason                                           as not_applicable_reason,

    o.slug                                                            as org_slug,
    o.display_name                                                    as org_display_name,
    o.legal_name                                                      as org_legal_name,
    o.entity_type                                                     as org_entity_type,
    o.website_url                                                     as org_website_url,
    o.twitter_handle                                                  as org_twitter_handle,
    o.hq_country                                                      as org_hq_country,
    o.founded_year                                                    as org_founded_year,
    o.total_funding_usd                                               as org_total_funding_usd,
    o.last_funding_round                                              as org_last_funding_round,
    o.last_funding_date                                               as org_last_funding_date,

    fp.slug                                                           as forked_from_slug,
    fp.name                                                           as forked_from_display_name,
    fp.entity_role                                                    as forked_from_role,

    a.sequencer_model                                                 as sequencer_model,
    a.sequencer_decentralization_roadmap                              as sequencer_decentralization_roadmap,
    a.fault_proof_status                                              as fault_proof_status,
    a.challenge_window_days                                           as challenge_window_days,
    a.l2beat_stage                                                    as l2beat_stage,
    a.upgrade_governance_type                                         as upgrade_governance_type,
    a.upgrade_timelock_days                                           as upgrade_timelock_days,
    a.security_council_size                                           as security_council_size,
    a.evm_equivalence_level                                           as evm_equivalence_level,
    a.mev_policy_type                                                 as mev_policy_type,
    a.fee_revenue_band_usd_annual                                     as fee_revenue_band_usd_annual,
    a.fee_as_of_date                                                  as fee_as_of_date,
    a.tvl_usd_band                                                    as tvl_usd_band,
    a.tvl_as_of_date                                                  as tvl_as_of_date,
    a.daily_tx_count_band                                             as daily_tx_count_band,
    a.daily_tx_as_of_date                                             as daily_tx_as_of_date,
    a.native_token_ticker                                             as native_token_ticker,
    a.governance_token_ticker                                         as governance_token_ticker,
    a.superchain_member                                               as superchain_member,
    a.orbit_chain                                                     as orbit_chain,
    a.batch_posting_frequency_seconds                                 as batch_posting_frequency_seconds,
    a.fast_bridge_partner_count                                       as fast_bridge_partner_count,
    a.ecosystem_grant_program_active                                  as ecosystem_grant_program_active,
    a.upgrade_history_count                                           as upgrade_history_count,
    a.inclusion_rationale                                             as inclusion_rationale,
    a.security_model_summary                                          as security_model_summary,
    a.execution_model_summary                                         as execution_model_summary,
    a.settlement_summary                                              as settlement_summary,
    a.governance_summary                                              as governance_summary,
    a.ownership_summary                                               as ownership_summary,
    a.roadmap_summary                                                 as roadmap_summary,
    a.operational_risk_summary                                        as operational_risk_summary,
    a.framework_architecture_summary                                  as framework_architecture_summary,
    a.deployment_model_summary                                        as deployment_model_summary,
    a.interoperability_summary                                        as interoperability_summary,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.data_quality_flags                                              as data_quality_flags,
    a.data_refreshed_at                                               as data_refreshed_at,
    a.data_confidence                                                 as data_confidence,

    p.created_at                                                      as created_at,
    p.updated_at                                                      as updated_at,

    -- Appended by 20260523_0001: schema metadata for single-hit project detail.
    s_meta.name                                                       as sector_name,
    sub_meta.name                                                     as subsector_name,
    s_meta.common_field_schema                                        as sector_common_field_schema,
    sub_meta.specific_field_schema                                    as subsector_specific_field_schema
  from public.projects p
  left join public.organizations o      on o.slug    = p.maintaining_organization
  left join public.projects fp          on fp.id     = p.forked_from
  left join public.optimistic_rollup_attrs a on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'optimistic-rollups';

-- ---------------------------------------------------------------------------
-- 2. public.zk_rollup_full_view
-- ---------------------------------------------------------------------------

create or replace view public.zk_rollup_full_view
  with (security_invoker = true)
as
  select
    p.id                                                              as project_id,
    p.slug                                                            as slug,
    p.name                                                            as display_name,
    p.description                                                     as description,
    p.website_url                                                     as website_url,
    p.logo_url                                                        as logo_url,
    p.twitter_handle                                                  as twitter_handle,
    p.github_url                                                      as github_url,
    p.status                                                          as status,
    p.sector_slug                                                     as sector_slug,
    p.subsector_slug                                                  as subsector_slug,

    p.entity_role                                                     as entity_role,
    p.framework_subtype                                               as framework_subtype,
    p.instance_subtype                                                as instance_subtype,
    p.lifecycle_status                                                as lifecycle_status,
    p.lifecycle_status_changed_at                                     as lifecycle_status_changed_at,
    p.settlement_layer                                                as settlement_layer,
    p.data_availability_layer                                         as data_availability_layer,
    p.withdrawal_latency_minutes                                      as withdrawal_latency_minutes,

    p.is_aggregate                                                    as is_aggregate,
    p.not_applicable_reason                                           as not_applicable_reason,

    o.slug                                                            as org_slug,
    o.display_name                                                    as org_display_name,
    o.legal_name                                                      as org_legal_name,
    o.entity_type                                                     as org_entity_type,
    o.website_url                                                     as org_website_url,
    o.twitter_handle                                                  as org_twitter_handle,
    o.hq_country                                                      as org_hq_country,
    o.founded_year                                                    as org_founded_year,
    o.total_funding_usd                                               as org_total_funding_usd,

    fp.slug                                                           as forked_from_slug,
    fp.name                                                           as forked_from_display_name,
    fp.entity_role                                                    as forked_from_role,

    a.proof_system                                                    as proof_system,
    a.proof_system_summary                                            as proof_system_summary,
    a.trusted_setup_required                                          as trusted_setup_required,
    a.proof_aggregation_strategy                                      as proof_aggregation_strategy,
    a.prover_decentralization                                         as prover_decentralization,
    a.sequencer_model                                                 as sequencer_model,
    a.sequencer_decentralization_roadmap                              as sequencer_decentralization_roadmap,
    a.evm_equivalence_level                                           as evm_equivalence_level,
    a.vm_name                                                         as vm_name,
    a.verifier_address_l1                                             as verifier_address_l1,
    a.verifier_kind                                                   as verifier_kind,
    a.l2beat_stage                                                    as l2beat_stage,
    a.upgrade_governance_type                                         as upgrade_governance_type,
    a.recursion_depth_typical                                         as recursion_depth_typical,
    a.batch_size_typical_tx                                           as batch_size_typical_tx,
    a.prover_hardware_requirement                                     as prover_hardware_requirement,
    a.cryptographic_finality_minutes_min                              as cryptographic_finality_minutes_min,
    a.cryptographic_finality_minutes_max                              as cryptographic_finality_minutes_max,
    a.tvl_usd_band                                                    as tvl_usd_band,
    a.tvl_as_of_date                                                  as tvl_as_of_date,
    a.fee_revenue_band_usd_annual                                     as fee_revenue_band_usd_annual,
    a.fee_as_of_date                                                  as fee_as_of_date,
    a.daily_tx_count_band                                             as daily_tx_count_band,
    a.daily_tx_as_of_date                                             as daily_tx_as_of_date,
    a.based_rollup                                                    as based_rollup,
    a.volition_mode_supported                                         as volition_mode_supported,
    a.zkchain_registry_count                                          as zkchain_registry_count,
    a.security_inheritance_level                                      as security_inheritance_level,
    a.trust_assumptions_summary                                       as trust_assumptions_summary,
    a.state_transition_definition_summary                             as state_transition_definition_summary,
    a.settlement_path_summary                                         as settlement_path_summary,
    a.reorg_failure_model_summary                                     as reorg_failure_model_summary,
    a.proving_cost_summary                                            as proving_cost_summary,
    a.proving_cost_type                                               as proving_cost_type,
    a.prover_bottleneck_summary                                       as prover_bottleneck_summary,
    a.throughput_constraints_summary                                  as throughput_constraints_summary,
    a.cost_sensitivity_summary                                        as cost_sensitivity_summary,
    a.ownership_summary                                               as ownership_summary,
    a.upgrade_summary                                                 as upgrade_summary,
    a.emergency_controls_present                                      as emergency_controls_present,
    a.emergency_controls_summary                                      as emergency_controls_summary,
    a.decentralization_roadmap_credibility                            as decentralization_roadmap_credibility,
    a.developer_adoption_summary                                      as developer_adoption_summary,
    a.mainnet_maturity_band                                           as mainnet_maturity_band,
    a.enterprise_orientation_band                                     as enterprise_orientation_band,
    a.ecosystem_dependency_summary                                    as ecosystem_dependency_summary,
    a.is_reusable_framework                                           as is_reusable_framework,
    a.shared_prover_sequencer_summary                                 as shared_prover_sequencer_summary,
    a.design_philosophy                                               as design_philosophy,
    a.is_single_canonical                                             as is_single_canonical,
    a.multi_rollup_capable                                            as multi_rollup_capable,
    a.deployment_permissioning                                        as deployment_permissioning,
    a.native_cross_rollup_support                                     as native_cross_rollup_support,
    a.cross_rollup_support_summary                                    as cross_rollup_support_summary,
    a.ethereum_composability_model                                    as ethereum_composability_model,
    a.external_bridge_dependency                                      as external_bridge_dependency,
    a.external_bridge_summary                                         as external_bridge_summary,
    a.inclusion_rationale                                             as inclusion_rationale,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.data_quality_flags                                              as data_quality_flags,
    a.data_refreshed_at                                               as data_refreshed_at,
    a.data_confidence                                                 as data_confidence,

    p.created_at                                                      as created_at,
    p.updated_at                                                      as updated_at,

    s_meta.name                                                       as sector_name,
    sub_meta.name                                                     as subsector_name,
    s_meta.common_field_schema                                        as sector_common_field_schema,
    sub_meta.specific_field_schema                                    as subsector_specific_field_schema
  from public.projects p
  left join public.organizations o      on o.slug    = p.maintaining_organization
  left join public.projects fp          on fp.id     = p.forked_from
  left join public.zk_rollup_attrs a    on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'zk-rollups';

-- ---------------------------------------------------------------------------
-- 3. public.l3_framework_full_view
--
-- This view uses INNER JOIN against l3_framework_attrs (cross-subsector
-- members surface via the sidecar, not projects.subsector_slug). Schemas are
-- joined off p.sector_slug / p.subsector_slug — for cross-subsector entities
-- the returned schema metadata reflects the entity's *home* subsector. That
-- matches the project detail page's URL routing (project slugs live under
-- their home subsector).
-- ---------------------------------------------------------------------------

create or replace view public.l3_framework_full_view
  with (security_invoker = true)
as
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
    p.created_at, p.updated_at,

    s_meta.name                       as sector_name,
    sub_meta.name                     as subsector_name,
    s_meta.common_field_schema        as sector_common_field_schema,
    sub_meta.specific_field_schema    as subsector_specific_field_schema
  from public.projects p
  left join public.organizations o on o.slug = p.maintaining_organization
  left join public.projects fp on fp.id = p.forked_from
  inner join public.l3_framework_attrs a on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug;

-- ---------------------------------------------------------------------------
-- 4. public.validium_full_view
-- ---------------------------------------------------------------------------

create or replace view public.validium_full_view
  with (security_invoker = true)
as
  select
    p.id                                                              as project_id,
    p.slug                                                            as slug,
    p.name                                                            as display_name,
    p.description                                                     as description,
    p.website_url                                                     as website_url,
    p.logo_url                                                        as logo_url,
    p.twitter_handle                                                  as twitter_handle,
    p.github_url                                                      as github_url,
    p.status                                                          as status,
    p.sector_slug                                                     as sector_slug,
    p.subsector_slug                                                  as home_subsector_slug,

    p.entity_role                                                     as entity_role,
    p.framework_subtype                                               as framework_subtype,
    p.instance_subtype                                                as instance_subtype,
    p.lifecycle_status                                                as lifecycle_status,
    p.lifecycle_status_changed_at                                     as lifecycle_status_changed_at,
    p.settlement_layer                                                as settlement_layer,
    p.data_availability_layer                                         as data_availability_layer,
    p.withdrawal_latency_minutes                                      as withdrawal_latency_minutes,
    p.is_aggregate                                                    as is_aggregate,
    p.not_applicable_reason                                           as project_not_applicable_reason,

    o.slug                                                            as org_slug,
    o.display_name                                                    as org_display_name,
    o.legal_name                                                      as org_legal_name,
    o.entity_type                                                     as org_entity_type,

    fp.slug                                                           as forked_from_slug,
    fp.name                                                           as forked_from_display_name,

    mp.slug                                                           as migrated_to_slug,
    mp.name                                                           as migrated_to_display_name,

    m.role_in_subsector                                               as role_in_subsector,
    m.primary_membership                                              as is_primary_member,

    a.rollup_variant                                                  as rollup_variant,
    a.rollup_variant_text                                             as rollup_variant_text,
    a.execution_proof_type                                            as execution_proof_type,
    a.execution_proof_type_text                                       as execution_proof_type_text,
    a.da_location                                                     as da_location,
    a.da_location_text                                                as da_location_text,
    a.da_mode_switching                                               as da_mode_switching,
    a.da_provider_type                                                as da_provider_type,
    a.da_withholding_risk_bool                                        as da_withholding_risk_bool,
    a.da_withholding_risk_text                                        as da_withholding_risk_text,
    a.who_controls_da_text                                            as who_controls_da_text,
    a.settlement_layer_enum                                           as settlement_layer_enum,
    a.ethereum_verification_scope                                     as ethereum_verification_scope,
    a.failure_blast_radius                                            as failure_blast_radius,
    a.protocol_ownership_text                                         as protocol_ownership_text,
    a.da_committee_governance                                         as da_committee_governance,
    a.upgrade_authority_level                                         as upgrade_authority_level,
    a.ops_complexity_level                                            as ops_complexity_level,
    a.user_exit_risk_level                                            as user_exit_risk_level,
    a.production_status                                               as production_status,
    a.production_status_as_of_date                                    as production_status_as_of_date,
    a.ecosystem_lock_in_level                                         as ecosystem_lock_in_level,
    a.bridge_required_bool                                            as bridge_required_bool,
    a.migration_path_available                                        as migration_path_available,
    a.inclusion_rationale                                             as inclusion_rationale,
    a.inclusion_qualifier_note                                        as inclusion_qualifier_note,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.data_quality_flags                                              as data_quality_flags,
    a.not_applicable_reason                                           as sidecar_not_applicable_reason,
    a.data_refreshed_at                                               as data_refreshed_at,
    a.data_confidence                                                 as data_confidence,

    p.created_at                                                      as created_at,
    p.updated_at                                                      as updated_at,

    s_meta.name                                                       as sector_name,
    sub_meta.name                                                     as subsector_name,
    s_meta.common_field_schema                                        as sector_common_field_schema,
    sub_meta.specific_field_schema                                    as subsector_specific_field_schema
  from public.subsector_memberships m
  join public.projects p on p.id = m.project_id
  left join public.organizations o on o.slug = p.maintaining_organization
  left join public.projects fp on fp.id = p.forked_from
  left join public.projects mp on mp.id = p.migrated_to_project
  left join public.validium_attrs a on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where m.subsector_slug = 'validiums-volitions-hybrid';
