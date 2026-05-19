-- M8.5 logos: Supabase Storage bucket for project / maintaining-org logos.
--
-- File naming convention (enforced by upload_logo.py, NOT by SQL):
--   <maintaining-org-slug>.webp
-- so that multiple projects under the same org share one file. Examples:
--   sigma-prime.webp (used by lighthouse)
--   consensys.webp   (used by teku, also future Linea/MetaMask entries)
--
-- Files are optimized to <=256x256 WebP (quality 85) by the upload script before they
-- hit the bucket — keeps every logo well under 30KB so the UI stays snappy.

insert into storage.buckets (id, name, public)
  values ('project-logos', 'project-logos', true)
  on conflict (id) do update set public = excluded.public;

-- Public read: anyone can GET
drop policy if exists "project_logos_public_read" on storage.objects;
create policy "project_logos_public_read"
  on storage.objects for select
  using (bucket_id = 'project-logos');

-- Writes only via the service_role key. The anon and authenticated roles get nothing.
drop policy if exists "project_logos_service_write" on storage.objects;
create policy "project_logos_service_write"
  on storage.objects for insert
  to service_role
  with check (bucket_id = 'project-logos');

drop policy if exists "project_logos_service_update" on storage.objects;
create policy "project_logos_service_update"
  on storage.objects for update
  to service_role
  using (bucket_id = 'project-logos')
  with check (bucket_id = 'project-logos');

drop policy if exists "project_logos_service_delete" on storage.objects;
create policy "project_logos_service_delete"
  on storage.objects for delete
  to service_role
  using (bucket_id = 'project-logos');
