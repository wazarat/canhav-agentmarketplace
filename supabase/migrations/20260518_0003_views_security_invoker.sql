-- Follow-up to migration 0001: recreate the summary views with security_invoker=true so they
-- enforce RLS using the *caller's* role rather than the view-owner's. Otherwise the views are
-- created with SECURITY DEFINER and would silently bypass our row-level security policies.
--
-- See: https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view

drop view if exists public.sector_summary;
drop view if exists public.subsector_summary;

create view public.sector_summary
  with (security_invoker = true)
as
  select
    s.slug                                                                  as sector_slug,
    s.name                                                                  as sector_name,
    s.description                                                           as sector_description,
    s.display_order                                                         as sector_display_order,
    count(distinct sub.slug)                                                as subsector_count,
    coalesce(sum(case when p.id is not null then 1 else 0 end), 0)::int     as project_count
  from public.sectors s
  left join public.subsectors sub on sub.sector_slug = s.slug
  left join public.projects  p   on p.subsector_slug = sub.slug
  group by s.slug, s.name, s.description, s.display_order
  order by s.display_order;

create view public.subsector_summary
  with (security_invoker = true)
as
  select
    sub.slug                                  as subsector_slug,
    sub.name                                  as subsector_name,
    sub.description                           as subsector_description,
    sub.display_order                         as subsector_display_order,
    sub.sector_slug                           as sector_slug,
    sub.source_sheet_id                       as source_sheet_id,
    sub.source_sheet_gid                      as source_sheet_gid,
    coalesce(count(p.id), 0)::int             as project_count
  from public.subsectors sub
  left join public.projects p on p.subsector_slug = sub.slug
  group by sub.slug, sub.name, sub.description, sub.display_order, sub.sector_slug,
           sub.source_sheet_id, sub.source_sheet_gid
  order by sub.sector_slug, sub.display_order;

-- Also pin the search_path on touch_updated_at() so it can't be hijacked by a shadowing
-- function in a search_path schema the caller controls. (Advisor 0011.)
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
