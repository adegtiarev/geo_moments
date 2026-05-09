create table if not exists public.moment_comments (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.moment_comments(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists moment_comments_moment_created_at_idx
on public.moment_comments(moment_id, created_at desc);

create index if not exists moment_comments_parent_id_idx
on public.moment_comments(parent_id);

create trigger moment_comments_set_updated_at
before update on public.moment_comments
for each row execute function public.set_updated_at();

create or replace function public.validate_moment_comment_parent()
returns trigger
language plpgsql
as $$
declare
  parent_moment_id uuid;
  parent_parent_id uuid;
begin
  if new.parent_id is null then
    return new;
  end if;

  select moment_id, parent_id
  into parent_moment_id, parent_parent_id
  from public.moment_comments
  where id = new.parent_id;

  if parent_moment_id is null then
    raise exception 'Parent comment does not exist';
  end if;

  if parent_moment_id <> new.moment_id then
    raise exception 'Reply parent must belong to the same moment';
  end if;

  if parent_parent_id is not null then
    raise exception 'Replies can only be one level deep';
  end if;

  return new;
end;
$$;

drop trigger if exists moment_comments_validate_parent
on public.moment_comments;

create trigger moment_comments_validate_parent
before insert or update of parent_id, moment_id
on public.moment_comments
for each row execute function public.validate_moment_comment_parent();

alter table public.moment_comments enable row level security;

drop policy if exists "moment_comments_select_authenticated" on public.moment_comments;
create policy "moment_comments_select_authenticated"
on public.moment_comments
for select
to authenticated
using (true);

drop policy if exists "moment_comments_insert_own" on public.moment_comments;
create policy "moment_comments_insert_own"
on public.moment_comments
for insert
to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "moment_comments_update_own" on public.moment_comments;
create policy "moment_comments_update_own"
on public.moment_comments
for update
to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

drop policy if exists "moment_comments_delete_own" on public.moment_comments;
create policy "moment_comments_delete_own"
on public.moment_comments
for delete
to authenticated
using ((select auth.uid()) = author_id);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'moment_comments'
  ) then
    alter publication supabase_realtime
    add table public.moment_comments;
  end if;
end $$;

create or replace function public.moment_comments_page(
  target_moment_id uuid,
  page_limit integer default 20,
  before_created_at timestamptz default null
)
returns table (
  id uuid,
  moment_id uuid,
  author_id uuid,
  parent_id uuid,
  body text,
  created_at timestamptz,
  updated_at timestamptz,
  author_display_name text,
  author_avatar_url text
)
language sql
stable
as $$
  with root_comments as (
    select
      c.*,
      c.created_at as root_created_at
    from public.moment_comments c
    where c.moment_id = target_moment_id
      and c.parent_id is null
      and (
        before_created_at is null
        or c.created_at < before_created_at
      )
    order by c.created_at desc
    limit least(greatest(page_limit, 1), 50)
  ),
  selected_comments as (
    select root_comments.*
    from root_comments

    union all

    select
      replies.*,
      roots.root_created_at
    from public.moment_comments replies
    join root_comments roots on roots.id = replies.parent_id
  )
  select
    c.id,
    c.moment_id,
    c.author_id,
    c.parent_id,
    c.body,
    c.created_at,
    c.updated_at,
    p.display_name as author_display_name,
    p.avatar_url as author_avatar_url
  from selected_comments c
  join public.profiles p on p.id = c.author_id
  order by
    c.root_created_at desc,
    c.parent_id is not null,
    c.created_at asc;
$$;

create or replace function public.create_moment_comment(
  target_moment_id uuid,
  comment_body text,
  parent_comment_id uuid default null
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  inserted public.moment_comments;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  insert into public.moment_comments (
    moment_id,
    author_id,
    parent_id,
    body
  )
  values (
    target_moment_id,
    auth.uid(),
    parent_comment_id,
    trim(comment_body)
  )
  returning * into inserted;

  return jsonb_build_object(
    'id', inserted.id::text,
    'moment_id', inserted.moment_id::text,
    'author_id', inserted.author_id::text,
    'parent_id', inserted.parent_id::text,
    'body', inserted.body,
    'created_at', inserted.created_at,
    'updated_at', inserted.updated_at,
    'author_display_name', (
      select display_name from public.profiles where id = inserted.author_id
    ),
    'author_avatar_url', (
      select avatar_url from public.profiles where id = inserted.author_id
    )
  );
end;
$$;

create or replace function public.nearby_moments(
  center_lat double precision,
  center_lng double precision,
  limit_count integer default 50
)
returns table (
  id uuid,
  author_id uuid,
  latitude double precision,
  longitude double precision,
  text text,
  emotion text,
  media_url text,
  media_type text,
  created_at timestamptz,
  author_display_name text,
  author_avatar_url text,
  like_count integer,
  comment_count integer
)
language sql
stable
as $$
  select
    m.id,
    m.author_id,
    m.latitude,
    m.longitude,
    m.text,
    m.emotion,
    m.media_url,
    m.media_type,
    m.created_at,
    p.display_name as author_display_name,
    p.avatar_url as author_avatar_url,
    (
      select count(*)::int
      from public.moment_likes ml
      where ml.moment_id = m.id
    ) as like_count,
    (
      select count(*)::int
      from public.moment_comments mc
      where mc.moment_id = m.id
    ) as comment_count
  from public.moments m
  join public.profiles p on p.id = m.author_id
  order by
    power(m.latitude - center_lat, 2) + power(m.longitude - center_lng, 2),
    m.created_at desc
  limit least(greatest(limit_count, 1), 100);
$$;

create or replace function public.moment_comment_count(target_moment_id uuid)
returns integer
language sql
stable
as $$
  select count(*)::int
  from public.moment_comments
  where moment_id = target_moment_id;
$$;
