create table if not exists public.moment_likes (
  moment_id uuid not null references public.moments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (moment_id, user_id)
);

create index if not exists moment_likes_user_id_idx
on public.moment_likes(user_id);

alter table public.moment_likes enable row level security;

drop policy if exists "moment_likes_select_authenticated" on public.moment_likes;
create policy "moment_likes_select_authenticated"
on public.moment_likes
for select
to authenticated
using (true);

drop policy if exists "moment_likes_insert_own" on public.moment_likes;
create policy "moment_likes_insert_own"
on public.moment_likes
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "moment_likes_delete_own" on public.moment_likes;
create policy "moment_likes_delete_own"
on public.moment_likes
for delete
to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.moment_like_summary(target_moment_id uuid)
returns jsonb
language sql
stable
security invoker
as $$
  select jsonb_build_object(
    'moment_id', target_moment_id::text,
    'like_count', (
      select count(*)::int
      from public.moment_likes ml
      where ml.moment_id = target_moment_id
    ),
    'is_liked_by_me', exists (
      select 1
      from public.moment_likes ml
      where ml.moment_id = target_moment_id
        and ml.user_id = (select auth.uid())
    )
  );
$$;

create or replace function public.like_moment(target_moment_id uuid)
returns jsonb
language plpgsql
security invoker
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  insert into public.moment_likes (moment_id, user_id)
  values (target_moment_id, current_user_id)
  on conflict (moment_id, user_id) do nothing;

  return public.moment_like_summary(target_moment_id);
end;
$$;

create or replace function public.unlike_moment(target_moment_id uuid)
returns jsonb
language plpgsql
security invoker
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  delete from public.moment_likes
  where moment_id = target_moment_id
    and user_id = current_user_id;

  return public.moment_like_summary(target_moment_id);
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
    0 as comment_count
  from public.moments m
  join public.profiles p on p.id = m.author_id
  order by
    power(m.latitude - center_lat, 2) + power(m.longitude - center_lng, 2),
    m.created_at desc
  limit least(greatest(limit_count, 1), 100);
$$;
