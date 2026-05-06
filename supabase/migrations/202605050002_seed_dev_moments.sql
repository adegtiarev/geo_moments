do $$
declare
  seed_author_id uuid := '8bf1faa8-5cdf-4893-9665-b7e72e6319c6';
begin
  insert into public.profiles (id, display_name)
  values (seed_author_id, 'Geo Moments Dev User')
  on conflict (id) do nothing;

  insert into public.moments (author_id, latitude, longitude, text, emotion, media_type)
  values
    (seed_author_id, -34.6037, -58.3816, 'Great coffee near the city center', 'coffee', 'none'),
    (seed_author_id, -34.6083, -58.3712, 'Nice place for an evening walk', 'calm', 'none'),
    (seed_author_id, -34.6118, -58.4173, 'Sunset looked unreal here', 'sunset', 'none');
end $$;