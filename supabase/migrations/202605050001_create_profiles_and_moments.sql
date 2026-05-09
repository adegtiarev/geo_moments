create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create table if not exists public.moments (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  text text not null check (char_length(text) <= 280),
  emotion text,
  media_url text,
  media_type text not null default 'none' check (media_type in ('none', 'image', 'video')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists moments_created_at_idx on public.moments(created_at desc);
create index if not exists moments_author_id_idx on public.moments(author_id);
create index if not exists moments_location_idx on public.moments(latitude, longitude);

create trigger moments_set_updated_at
before update on public.moments
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.moments enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "moments_select_authenticated" on public.moments;
create policy "moments_select_authenticated"
on public.moments
for select
to authenticated
using (true);

drop policy if exists "moments_insert_own" on public.moments;
create policy "moments_insert_own"
on public.moments
for insert
to authenticated
with check ((select auth.uid()) = author_id);

drop policy if exists "moments_update_own" on public.moments;
create policy "moments_update_own"
on public.moments
for update
to authenticated
using ((select auth.uid()) = author_id)
with check ((select auth.uid()) = author_id);

drop policy if exists "moments_delete_own" on public.moments;
create policy "moments_delete_own"
on public.moments
for delete
to authenticated
using ((select auth.uid()) = author_id);

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
  author_avatar_url text
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
    p.avatar_url as author_avatar_url
  from public.moments m
  join public.profiles p on p.id = m.author_id
  order by
    power(m.latitude - center_lat, 2) + power(m.longitude - center_lng, 2),
    m.created_at desc
  limit least(greatest(limit_count, 1), 100);
$$;

insert into storage.buckets (id, name, public)
values ('moment-media', 'moment-media', true)
on conflict (id) do nothing;
