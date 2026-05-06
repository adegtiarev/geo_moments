# 06 Supabase Schema, RLS, and Seed Data

Статус: done.

## Источники

Эта глава опирается на актуальные Supabase docs:

- [Local development with schema migrations](https://supabase.com/docs/guides/cli/local-development)
- [Supabase CLI getting started](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)

Ключевой принцип из Supabase docs: RLS должен быть включен для таблиц в exposed schema, например `public`. Если таблица создана через raw SQL, RLS нужно включить явно.

## Что строим в этой главе

До этого момента Supabase был подключен, auth работал, но данных приложения еще не было.

В этой главе мы создаем первую backend-модель Geo Moments:

- SQL migration files в репозитории;
- таблица `profiles`;
- таблица `moments`;
- Row Level Security policies;
- storage bucket `moment-media`;
- seed data для dev;
- Flutter domain/data layer для чтения moments;
- отображение списка моментов в текущем map placeholder UI.

После главы приложение должно показывать реальные seed moments из Supabase, пока без настоящей карты.

## Почему это важно

Backend-часть портфолио оценивается не только по тому, что приложение "что-то грузит". Важно показать:

- схема данных лежит в Git;
- RLS включен;
- policies явно описывают доступ;
- client app не использует service role key;
- Flutter UI не дергает Supabase напрямую;
- данные проходят через repository/domain layer.

Это особенно важно для Supabase, потому что `anon/publishable key` публичен. Защита строится на RLS, а не на скрытии ключа в приложении.

## Словарь главы

`migration` - SQL-файл, который описывает изменение схемы базы.

`RLS` - Row Level Security, механизм Postgres для ограничения строк на уровне таблицы.

`policy` - правило доступа для SELECT/INSERT/UPDATE/DELETE.

`auth.uid()` - Supabase helper, который возвращает id текущего authenticated user или `null`.

`authenticated` - Postgres role для вошедших пользователей Supabase.

`anon` - role для неавторизованных запросов.

`storage bucket` - контейнер Supabase Storage для файлов.

`seed data` - тестовые данные для разработки.

`DTO` - data transfer object, структура для парсинга backend JSON.

## 1. Почему миграции даже если SQL можно выполнить в Dashboard

В Supabase Dashboard есть SQL editor. Он удобен для выполнения SQL.

Но если изменения живут только в dashboard:

- новый чат/разработчик не поймет, какая схема нужна;
- нельзя воспроизвести проект с нуля;
- сложно ревьюить backend changes;
- портфолио теряет ценность.

Поэтому делаем так:

```text
supabase/migrations/202605050001_create_profiles_and_moments.sql
```

Этот файл коммитим. Выполнить его можно:

- через Supabase SQL editor вручную;
- или через Supabase CLI `supabase db push`, если CLI настроен.

Для курса сейчас достаточно SQL editor, но файл migration все равно должен быть в Git.

## 2. Почему начинаем с `profiles` и `moments`

Geo Moments позже будет иметь:

- profiles;
- moments;
- likes;
- comments;
- push tokens;
- storage objects.

Но сразу создавать все таблицы не нужно. В этой главе нам нужны только:

```text
profiles
moments
```

`profiles` нужен, чтобы связать публичную информацию пользователя с `auth.users`.

`moments` нужен, чтобы показать первые реальные точки/моменты из backend.

Likes/comments сделаем позже, когда дойдем до соответствующих глав.

## 3. Таблица `profiles`

`auth.users` находится в Supabase auth schema. Мы не пишем туда напрямую.

В public schema создаем свою таблицу:

```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

`id` совпадает с `auth.users.id`.

Почему так:

- легко связать moment author с profile;
- при удалении auth user можно удалить profile cascade;
- UI не зависит от закрытой auth schema.

## 4. Profile bootstrap trigger

После OAuth Supabase создает `auth.users` row. Нам нужно автоматически создать `public.profiles`.

Для этого используем trigger:

```sql
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
```

Trigger:

```sql
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
```

Если пользователь уже создан до trigger-а, profile для него можно создать seed SQL-ом вручную.

## 5. Таблица `moments`

Минимальная версия:

```sql
create table public.moments (
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
```

Пока media optional. В следующих главах добавим camera/upload.

Координаты храним как `double precision`. PostGIS пока не подключаем, чтобы не усложнять. Для MVP nearby query можно сделать приблизительно по latitude/longitude.

## 6. RLS policies

Включить RLS:

```sql
alter table public.profiles enable row level security;
alter table public.moments enable row level security;
```

Profiles:

- authenticated users могут читать profiles;
- user может обновлять только свой profile.

Moments:

- authenticated users могут читать moments;
- authenticated user может создавать moments только с `author_id = auth.uid()`;
- author может обновлять/удалять свои moments.

Почему `to authenticated`:

Supabase docs рекомендуют указывать role в policies. Это не только яснее, но и помогает не запускать лишние проверки для `anon`.

Почему явно проверяем `auth.uid() is not null`:

`auth.uid()` возвращает `null` для unauthenticated request. Лучше писать намерение явно.

## 7. RPC для nearby moments

Можно сначала читать:

```dart
supabase.from('moments').select()
```

Но приложению нужна "карта рядом". Сделаем SQL function:

```sql
public.nearby_moments(center_lat, center_lng, limit_count)
```

Без PostGIS используем простую сортировку по квадрату расстояния:

```sql
power(latitude - center_lat, 2) + power(longitude - center_lng, 2)
```

Это не точная геодезия, но для seed/dev и учебного MVP достаточно. Когда дойдем до карты и реального nearby UX, можно обсудить PostGIS.

## 8. Seed data и текущий user id

Так как `moments.author_id` ссылается на `profiles.id`, seed data должен быть привязан к существующему пользователю.

Порядок:

1. Войти в приложение через Google.
2. Открыть Supabase Dashboard -> Authentication -> Users.
3. Скопировать UUID своего пользователя.
4. В seed SQL заменить:

```sql
'00000000-0000-0000-0000-000000000000'
```

на свой user id.

Это лучше, чем отключать FK или создавать fake auth user.

## 9. Flutter data flow для moments

Сделаем:

```text
Supabase RPC
  -> MomentDto
  -> Moment entity
  -> MomentsRepository
  -> Riverpod provider
  -> NearbyMomentsList widget
```

UI не должен писать:

```dart
Supabase.instance.client.from('moments')
```

UI должен читать provider:

```dart
final moments = ref.watch(nearbyMomentsProvider);
```

Это сохраняет архитектурную линию курса.

## Целевая структура после главы

```text
supabase/
  migrations/
    202605050001_create_profiles_and_moments.sql
    202605050002_seed_dev_moments.sql
lib/
  src/
    features/
      moments/
        data/
          dto/
            moment_dto.dart
          repositories/
            supabase_moments_repository.dart
        domain/
          entities/
            moment.dart
          repositories/
            moments_repository.dart
        presentation/
          controllers/
            moments_providers.dart
          widgets/
            nearby_moments_list.dart
```

## Практика

### Шаг 1. Создать migration file

Создай папку:

```text
supabase/migrations
```

Файл:

```text
supabase/migrations/202605050001_create_profiles_and_moments.sql
```

SQL:

```sql
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
```

### Шаг 2. Добавить profile trigger

В тот же migration:

```sql
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
```

### Шаг 3. Добавить RLS policies

В тот же migration:

```sql
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
```

### Шаг 4. Добавить nearby RPC

В тот же migration:

```sql
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
```

### Шаг 5. Создать storage bucket

Можно сделать через SQL:

```sql
insert into storage.buckets (id, name, public)
values ('moment-media', 'moment-media', true)
on conflict (id) do nothing;
```

Пока bucket public для простоты просмотра media. Перед release можно пересмотреть. Upload policies добавим в media chapter.

### Шаг 6. Выполнить migration

Вариант A: SQL editor.

1. Открой Supabase Dashboard.
2. SQL Editor.
3. Вставь весь SQL из migration file.
4. Run.

Вариант B: Supabase CLI.

Если CLI настроен:

```bash
supabase link --project-ref <project-ref>
supabase db push
```

Для курса вариант A нормален. Главное: migration file остается в Git.

### Шаг 7. Создать seed file

Файл:

```text
supabase/migrations/202605050002_seed_dev_moments.sql
```

SQL:

```sql
-- Replace this value with your Supabase Auth user id from Authentication -> Users.
do $$
declare
  seed_author_id uuid := '00000000-0000-0000-0000-000000000000';
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
```

Перед выполнением замени UUID на свой `auth.users.id`. Если не заменить, SQL упадет из-за foreign key или создаст невозможную связь, если FK ослаблен. FK ослаблять не нужно.

### Шаг 8. Создать `Moment` entity

Файл:

```text
lib/src/features/moments/domain/entities/moment.dart
```

Код:

```dart
class Moment {
  const Moment({
    required this.id,
    required this.authorId,
    required this.latitude,
    required this.longitude,
    required this.text,
    required this.mediaType,
    required this.createdAt,
    this.emotion,
    this.mediaUrl,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  final String id;
  final String authorId;
  final double latitude;
  final double longitude;
  final String text;
  final String mediaType;
  final DateTime createdAt;
  final String? emotion;
  final String? mediaUrl;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
}
```

### Шаг 9. Создать DTO

Файл:

```text
lib/src/features/moments/data/dto/moment_dto.dart
```

Код:

```dart
import '../../domain/entities/moment.dart';

class MomentDto {
  const MomentDto({
    required this.id,
    required this.authorId,
    required this.latitude,
    required this.longitude,
    required this.text,
    required this.mediaType,
    required this.createdAt,
    this.emotion,
    this.mediaUrl,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  final String id;
  final String authorId;
  final double latitude;
  final double longitude;
  final String text;
  final String mediaType;
  final DateTime createdAt;
  final String? emotion;
  final String? mediaUrl;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  factory MomentDto.fromJson(Map<String, dynamic> json) {
    return MomentDto(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      text: json['text'] as String,
      mediaType: json['media_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      emotion: json['emotion'] as String?,
      mediaUrl: json['media_url'] as String?,
      authorDisplayName: json['author_display_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
    );
  }

  Moment toDomain() {
    return Moment(
      id: id,
      authorId: authorId,
      latitude: latitude,
      longitude: longitude,
      text: text,
      mediaType: mediaType,
      createdAt: createdAt,
      emotion: emotion,
      mediaUrl: mediaUrl,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
    );
  }
}
```

### Шаг 10. Repository interface

Файл:

```text
lib/src/features/moments/domain/repositories/moments_repository.dart
```

Код:

```dart
import '../entities/moment.dart';

abstract interface class MomentsRepository {
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  });
}
```

### Шаг 11. Supabase repository

Файл:

```text
lib/src/features/moments/data/repositories/supabase_moments_repository.dart
```

Код:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/moment.dart';
import '../../domain/repositories/moments_repository.dart';
import '../dto/moment_dto.dart';

class SupabaseMomentsRepository implements MomentsRepository {
  const SupabaseMomentsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'nearby_moments',
      params: {
        'center_lat': latitude,
        'center_lng': longitude,
        'limit_count': limit,
      },
    );

    return response
        .cast<Map<String, dynamic>>()
        .map(MomentDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();
  }
}
```

Если analyzer ругается на generic `rpc<List<dynamic>>`, используй:

```dart
final response = await _client.rpc(
  'nearby_moments',
  params: {...},
) as List<dynamic>;
```

### Шаг 12. Providers

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

Код:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../data/repositories/supabase_moments_repository.dart';
import '../../domain/entities/moment.dart';
import '../../domain/repositories/moments_repository.dart';

final momentsRepositoryProvider = Provider<MomentsRepository>((ref) {
  return SupabaseMomentsRepository(ref.watch(supabaseClientProvider));
});

final nearbyMomentsProvider = FutureProvider<List<Moment>>((ref) {
  final repository = ref.watch(momentsRepositoryProvider);

  return repository.fetchNearbyMoments(
    latitude: -34.6037,
    longitude: -58.3816,
  );
});
```

Координаты пока hardcoded Buenos Aires. В map/geolocation chapter заменим на текущую позицию/центр карты.

### Шаг 13. Widget для списка моментов

Файл:

```text
lib/src/features/moments/presentation/widgets/nearby_moments_list.dart
```

Код:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_spacing.dart';
import '../controllers/moments_providers.dart';

class NearbyMomentsList extends ConsumerWidget {
  const NearbyMomentsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moments = ref.watch(nearbyMomentsProvider);

    return moments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Could not load moments: $error'),
      data: (items) {
        if (items.isEmpty) {
          return const Text('No moments yet.');
        }

        return ListView.separated(
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final moment = items[index];

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(moment.text),
              subtitle: Text(moment.authorDisplayName ?? moment.authorId),
              leading: const Icon(Icons.place_outlined),
            );
          },
        );
      },
    );
  }
}
```

Тексты error/empty позже локализуем. Если хочешь закрепить l10n сейчас, добавь keys в ARB.

### Шаг 14. Подключить список в map UI

В `MapScreen` найди `_NearbyMomentsSummary`.

Можно заменить содержимое summary card:

```dart
const NearbyMomentsList()
```

Если `ListView` находится внутри `Column`, нужен ограниченный размер. Например:

```dart
SizedBox(
  height: 220,
  child: NearbyMomentsList(),
)
```

Для tablet side panel можно дать `Expanded`.

Главная цель: увидеть seed moments в UI без настоящей карты.

### Шаг 15. Обновить тесты

Widget tests не должны ходить в Supabase. Override `nearbyMomentsProvider`:

```dart
nearbyMomentsProvider.overrideWith((ref) async {
  return const [
    Moment(
      id: 'moment-1',
      authorId: 'test-user-id',
      latitude: -34.6037,
      longitude: -58.3816,
      text: 'Test moment',
      mediaType: 'none',
      createdAt: DateTime(2026, 5, 5),
      authorDisplayName: 'Test User',
    ),
  ];
});
```

Если `DateTime` в const не подходит, сделай non-const list.

Проверка:

```dart
expect(find.text('Test moment'), findsOneWidget);
```

## Проверка

Backend:

1. Выполнить migration SQL.
2. Sign in в приложении.
3. Скопировать user id из Supabase Authentication -> Users.
4. Подставить user id в seed SQL.
5. Выполнить seed SQL.
6. Проверить в Table Editor, что `profiles` и `moments` заполнены.

Flutter:

```bash
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

Ручная проверка:

1. Войти в приложение.
2. Увидеть карту-placeholder.
3. Увидеть список seed moments.
4. Открыть Settings.
5. Sign out все еще работает.
6. После sign in moments снова видны.

## Частые ошибки

### Ошибка: `permission denied for table moments`

Причина: RLS включен, но policy не подходит текущему role/user.

Проверить:

- user authenticated;
- policy `moments_select_authenticated` создана;
- request идет после sign in.

### Ошибка: seed insert fails из-за foreign key

Причина: `seed_author_id` не существует в `auth.users`/`profiles`.

Решение:

1. Sign in через приложение.
2. Скопировать настоящий user id.
3. Использовать его в seed SQL.

### Ошибка: Flutter парсинг падает на `List<dynamic>`

Supabase RPC возвращает dynamic JSON. Нужно явно привести:

```dart
final rows = response as List<dynamic>;
final maps = rows.cast<Map<String, dynamic>>();
```

### Ошибка: UI test ходит в реальный Supabase

Причина: не override-нут `nearbyMomentsProvider` или repository.

Решение: подставить fake provider result в `ProviderScope`.

### Ошибка: unauthenticated user видит данные

Проверить policies. В этой главе `moments_select_authenticated` должен быть `to authenticated`, не `to anon`.

## Definition of Done

- В `supabase/migrations` есть SQL schema migration.
- `profiles` и `moments` созданы в Supabase.
- RLS включен на обеих таблицах.
- Policies созданы явно.
- `moment-media` bucket создан.
- Seed data добавлена для текущего authenticated user.
- Flutter имеет `Moment`, DTO, repository interface, Supabase repository.
- UI показывает список moments из Supabase.
- Widget tests используют fake moments.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка загрузки seed moments выполнена.

## Что я буду проверять в ревью

- RLS включен.
- Нет service role key в app/repo.
- SQL migration лежит в Git, а не только в dashboard.
- UI не дергает Supabase напрямую.
- DTO корректно отделен от domain entity.
- Тесты не зависят от настоящего Supabase.
- Seed data не ломает FK и не требует отключать constraints.

Когда закончишь, напиши:

```text
Глава 6 готова, проверь код.
```
