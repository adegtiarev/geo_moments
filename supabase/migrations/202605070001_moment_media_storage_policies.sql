insert into storage.buckets (id, name, public)
values ('moment-media', 'moment-media', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "moment_media_insert_own_folder" on storage.objects;
create policy "moment_media_insert_own_folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'moment-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "moment_media_select_own_folder" on storage.objects;
create policy "moment_media_select_own_folder"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'moment-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "moment_media_delete_own_folder" on storage.objects;
create policy "moment_media_delete_own_folder"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'moment-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);