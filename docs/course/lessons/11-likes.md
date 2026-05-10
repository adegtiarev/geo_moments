# 11 Likes

Статус: done.

## Что строим

В главе 10 создание moment стало настоящим backend flow: media загружается в Supabase Storage, row создается в `moments`, карта обновляется, details открывает опубликованную картинку.

В главе 11 добавим первый social action: лайк и анлайк момента.

После главы пользователь сможет:

1. Открыть moment details.
2. Нажать heart-кнопку.
3. Сразу увидеть измененный счетчик.
4. Получить корректный результат даже при повторном tap или retry.
5. Вернуться на карту и увидеть обновленные counts после refresh.

Это не превращает Geo Moments в социальную сеть. Лайк здесь нужен как маленькая реакция на эмоцию в точке.

## Почему это важно

Лайк кажется простой кнопкой, но технически это хороший учебный пример:

- есть backend state;
- есть текущий пользователь;
- есть race conditions от быстрых taps;
- нужна idempotent операция;
- UI должен быстро реагировать;
- ошибка должна откатить optimistic state.

В Android это обычно выглядело бы так:

```text
Fragment/Compose UI
  -> ViewModel.like(momentId)
  -> optimistic state update
  -> repository.like(momentId)
  -> on failure rollback state
```

Во Flutter у нас похожая схема:

```text
MomentLikeButton
  -> MomentLikeController.setLiked(...)
  -> optimistic state update
  -> MomentLikesRepository.likeMoment/unlikeMoment
  -> rollback on error
```

## Словарь главы

`Like row` - строка в таблице `moment_likes`, которая связывает `moment_id` и `user_id`.

`Idempotent command` - команда, которую безопасно повторить. `likeMoment` после уже поставленного лайка остается successful, а не создает duplicate.

`Optimistic update` - UI обновляется до ответа backend. Если backend упал, UI откатывается.

`Race condition` - ситуация, когда несколько быстрых действий приходят в неожиданном порядке.

`Unique constraint` - database правило, которое запрещает duplicate likes одного пользователя на один moment.

`Summary` - маленький read model для UI: `likeCount` и `isLikedByMe`.

## 1. Как хранить лайки в database

Не добавляем в `moments` поле `liked_by_user_ids`. Это плохо масштабируется и неудобно для RLS.

Правильнее хранить отдельную таблицу:

```text
moments
  id
  text
  ...

moment_likes
  moment_id
  user_id
  created_at
```

Один пользователь может лайкнуть один moment только один раз. Это выражается primary key:

```sql
primary key (moment_id, user_id)
```

Так backend защищает нас даже если UI случайно отправит два одинаковых request-а.

## 2. Почему не делаем `toggleLike`

На первый взгляд удобно сделать один метод:

```dart
Future<void> toggleLike(String momentId);
```

Но `toggle` плохо переживает retry. Представь:

```text
1. пользователь нажал like;
2. request дошел до backend, лайк поставлен;
3. сеть оборвалась до ответа;
4. client делает retry toggle;
5. backend снимает лайк.
```

Пользователь хотел поставить лайк, а retry снял его.

Поэтому в этой главе делаем две idempotent команды:

```dart
Future<MomentLikeSummary> likeMoment(String momentId);
Future<MomentLikeSummary> unlikeMoment(String momentId);
```

Повторный `likeMoment` не ломает состояние. Повторный `unlikeMoment` тоже.

## 3. Optimistic update

Без optimistic update UI будет ждать сеть:

```text
tap -> loading -> backend response -> heart changes
```

Это ощущается медленно. Для лайков лучше:

```text
tap -> heart changes immediately -> backend response confirms
```

Если backend упал:

```text
tap -> heart changes immediately -> backend error -> rollback previous state
```

Важная деталь: пока один like/unlike request выполняется, кнопку временно блокируем. Это не единственная возможная стратегия, но для учебного приложения она понятная и надежная.

## Целевая структура после главы

```text
supabase/
  migrations/
    202605090001_create_moment_likes.sql

lib/
  src/
    features/
      moments/
        data/
          dto/
            moment_like_summary_dto.dart
          repositories/
            supabase_moment_likes_repository.dart
            supabase_moments_repository.dart
        domain/
          entities/
            moment.dart
            moment_like_summary.dart
          repositories/
            moment_likes_repository.dart
        presentation/
          controllers/
            moment_like_controller.dart
            moments_providers.dart
          widgets/
            moment_like_button.dart
            moment_details_content.dart
```

## Практика

### Шаг 1. Добавить migration для `moment_likes`

Файл:

```text
supabase/migrations/202605090001_create_moment_likes.sql
```

Код:

```sql
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
```

Почему `select` открыт для authenticated: счетчик лайков виден всем signed-in пользователям. Это не раскрывает private данные, потому что приложение и так показывает public moments authenticated users.

Почему `insert/delete` только own: пользователь не должен лайкать или удалять лайки от имени другого пользователя.

### Шаг 2. Добавить RPC summary и idempotent commands

В тот же migration добавь функции:

```sql
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
```

Почему RPC возвращает `jsonb`: в Dart проще маппить один object, чем разбирать table result из одной строки.

Почему `security invoker`: функции работают с правами текущего пользователя и не обходят RLS.

### Шаг 3. Обновить `nearby_moments`

В главе 8 мы заранее добавили `likeCount` в `Moment`, но backend пока отдавал `0`. Теперь `nearby_moments` должен вернуть настоящий count.

В migration замени function `public.nearby_moments` на версию с `like_count` и `comment_count`:

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
```

`comment_count` остается `0`, потому что comments появятся в главе 12. Но DTO уже умеет читать это поле, поэтому лучше сохранить shape заранее.

Применить migration:

```bash
supabase db push
```

### Шаг 4. Добавить `copyWith` в `Moment`

Файл:

```text
lib/src/features/moments/domain/entities/moment.dart
```

Добавь method внутрь class `Moment`:

```dart
Moment copyWith({
  int? likeCount,
  int? commentCount,
}) {
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
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
  );
}
```

Почему сейчас только counts: не надо превращать entity в огромный generated model. Добавляем только то, что нужно главе.

### Шаг 5. Создать `MomentLikeSummary`

Файл:

```text
lib/src/features/moments/domain/entities/moment_like_summary.dart
```

Код:

```dart
class MomentLikeSummary {
  const MomentLikeSummary({
    required this.momentId,
    required this.likeCount,
    required this.isLikedByMe,
  });

  final String momentId;
  final int likeCount;
  final bool isLikedByMe;
}
```

Это отдельная domain entity, потому что like button не должен знать SQL/RPC response shape.

### Шаг 6. Создать DTO для summary

Файл:

```text
lib/src/features/moments/data/dto/moment_like_summary_dto.dart
```

Код:

```dart
import '../../domain/entities/moment_like_summary.dart';

class MomentLikeSummaryDto {
  const MomentLikeSummaryDto({
    required this.momentId,
    required this.likeCount,
    required this.isLikedByMe,
  });

  final String momentId;
  final int likeCount;
  final bool isLikedByMe;

  factory MomentLikeSummaryDto.fromJson(Map<String, dynamic> json) {
    return MomentLikeSummaryDto(
      momentId: json['moment_id'] as String,
      likeCount: (json['like_count'] as num).toInt(),
      isLikedByMe: json['is_liked_by_me'] as bool,
    );
  }

  MomentLikeSummary toDomain() {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: likeCount,
      isLikedByMe: isLikedByMe,
    );
  }
}
```

### Шаг 7. Создать repository interface

Файл:

```text
lib/src/features/moments/domain/repositories/moment_likes_repository.dart
```

Код:

```dart
import '../entities/moment_like_summary.dart';

abstract interface class MomentLikesRepository {
  Future<MomentLikeSummary> fetchSummary(String momentId);

  Future<MomentLikeSummary> likeMoment(String momentId);

  Future<MomentLikeSummary> unlikeMoment(String momentId);
}
```

Разделяем `MomentsRepository` и `MomentLikesRepository`, потому что это разные use cases. `MomentsRepository` читает/создает moments. `MomentLikesRepository` выполняет reaction commands.

### Шаг 8. Реализовать Supabase repository

Файл:

```text
lib/src/features/moments/data/repositories/supabase_moment_likes_repository.dart
```

Код:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/moment_like_summary.dart';
import '../../domain/repositories/moment_likes_repository.dart';
import '../dto/moment_like_summary_dto.dart';

class SupabaseMomentLikesRepository implements MomentLikesRepository {
  const SupabaseMomentLikesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MomentLikeSummary> fetchSummary(String momentId) {
    return _summaryRpc('moment_like_summary', momentId);
  }

  @override
  Future<MomentLikeSummary> likeMoment(String momentId) {
    return _summaryRpc('like_moment', momentId);
  }

  @override
  Future<MomentLikeSummary> unlikeMoment(String momentId) {
    return _summaryRpc('unlike_moment', momentId);
  }

  Future<MomentLikeSummary> _summaryRpc(
    String functionName,
    String momentId,
  ) async {
    final response = await _client.rpc<dynamic>(
      functionName,
      params: {'target_moment_id': momentId},
    );

    final json = Map<String, dynamic>.from(response as Map);
    return MomentLikeSummaryDto.fromJson(json).toDomain();
  }
}
```

Не используем старый Supabase `.execute()` API. В текущем коде проекта уже используется прямой `await _client.rpc(...)`, продолжаем тот же стиль.

### Шаг 9. Зарегистрировать provider

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

Добавь imports:

```dart
import '../../data/repositories/supabase_moment_likes_repository.dart';
import '../../domain/repositories/moment_likes_repository.dart';
```

Provider:

```dart
final momentLikesRepositoryProvider = Provider<MomentLikesRepository>((ref) {
  return SupabaseMomentLikesRepository(ref.watch(supabaseClientProvider));
});
```

Держим provider рядом с остальными moments providers, потому что UI будет импортировать один controllers слой.

### Шаг 10. Обновить details fetch count

Файл:

```text
lib/src/features/moments/data/repositories/supabase_moments_repository.dart
```

В `fetchMomentById` после основного select получи summary:

```dart
final moment = MomentDto.fromDetailsJson(response).toDomain();

final likeSummary = await _client.rpc<dynamic>(
  'moment_like_summary',
  params: {'target_moment_id': id},
);
final likeSummaryJson = Map<String, dynamic>.from(likeSummary as Map);

return moment.copyWith(
  likeCount: (likeSummaryJson['like_count'] as num).toInt(),
);
```

Почему не добавляем `like_count` прямо в `.select(...)`: `like_count` не колонка таблицы `moments`. Сейчас проще и понятнее вызвать маленький RPC.

### Шаг 11. Создать like controller state

Файл:

```text
lib/src/features/moments/presentation/controllers/moment_like_controller.dart
```

Начни со state:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'moments_providers.dart';

typedef MomentLikeSeed = ({String momentId, int initialLikeCount});

class MomentLikeState {
  const MomentLikeState({
    required this.momentId,
    required this.likeCount,
    this.isLikedByMe = false,
    this.isBusy = false,
    this.error,
  });

  final String momentId;
  final int likeCount;
  final bool isLikedByMe;
  final bool isBusy;
  final Object? error;

  MomentLikeState copyWith({
    int? likeCount,
    bool? isLikedByMe,
    bool? isBusy,
    Object? error,
    bool clearError = false,
  }) {
    return MomentLikeState(
      momentId: momentId,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : error ?? this.error,
    );
  }
}
```

Почему `MomentLikeSeed` - record: provider family argument должен иметь стабильное equality. Dart records сравниваются по значениям, поэтому `(momentId: 'a', initialLikeCount: 1)` не пересоздает новый provider без причины.

### Шаг 12. Реализовать controller

В том же файле:

```dart
final momentLikeControllerProvider =
    NotifierProvider.family<MomentLikeController, MomentLikeState, MomentLikeSeed>(
  MomentLikeController.new,
);

class MomentLikeController extends Notifier<MomentLikeState> {
  MomentLikeController(this._seed);

  final MomentLikeSeed _seed;

  @override
  MomentLikeState build() {
    unawaited(_loadSummary());

    return MomentLikeState(
      momentId: _seed.momentId,
      likeCount: _seed.initialLikeCount,
    );
  }

  Future<void> setLiked(bool shouldLike) async {
    final previous = state;

    if (previous.isBusy || previous.isLikedByMe == shouldLike) {
      return;
    }

    state = previous.copyWith(
      isLikedByMe: shouldLike,
      likeCount: _optimisticCount(previous, shouldLike),
      isBusy: true,
      clearError: true,
    );

    try {
      final repository = ref.read(momentLikesRepositoryProvider);
      final summary = shouldLike
          ? await repository.likeMoment(_seed.momentId)
          : await repository.unlikeMoment(_seed.momentId);

      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        likeCount: summary.likeCount,
        isLikedByMe: summary.isLikedByMe,
        isBusy: false,
        clearError: true,
      );

      ref.invalidate(momentDetailsProvider(_seed.momentId));
      ref.invalidate(nearbyMomentsProvider);
    } catch (error) {
      if (!ref.mounted) {
        return;
      }

      state = previous.copyWith(isBusy: false, error: error);
    }
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await ref
          .read(momentLikesRepositoryProvider)
          .fetchSummary(_seed.momentId);

      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        likeCount: summary.likeCount,
        isLikedByMe: summary.isLikedByMe,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(error: error);
    }
  }

  int _optimisticCount(MomentLikeState previous, bool shouldLike) {
    if (shouldLike) {
      return previous.likeCount + 1;
    }

    final next = previous.likeCount - 1;
    return next < 0 ? 0 : next;
  }
}
```

Почему `ref.mounted` важен: `_loadSummary()` и `setLiked()` содержат async gaps. Provider может быть disposed, пока request выполняется.

Почему invalidation после success: details и nearby list должны перечитать counts из backend при следующем чтении.

### Шаг 13. Добавить локализацию

Файлы:

```text
lib/l10n/app_en.arb
lib/l10n/app_ru.arb
lib/l10n/app_es.arb
```

EN:

```json
"likeMoment": "Like",
"unlikeMoment": "Unlike",
"momentLikeError": "Could not update like."
```

RU:

```json
"likeMoment": "Лайк",
"unlikeMoment": "Убрать лайк",
"momentLikeError": "Не удалось обновить лайк."
```

ES:

```json
"likeMoment": "Me gusta",
"unlikeMoment": "Quitar me gusta",
"momentLikeError": "No se pudo actualizar el me gusta."
```

После ARB:

```bash
flutter gen-l10n
```

### Шаг 14. Создать `MomentLikeButton`

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_like_button.dart
```

Код:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';
import '../controllers/moment_like_controller.dart';

class MomentLikeButton extends ConsumerWidget {
  const MomentLikeButton({required this.moment, super.key});

  final Moment moment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = (
      momentId: moment.id,
      initialLikeCount: moment.likeCount,
    );
    final likeState = ref.watch(momentLikeControllerProvider(seed));

    ref.listen<Object?>(
      momentLikeControllerProvider(seed).select((state) => state.error),
      (previous, next) {
        if (next == null || previous == next) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.momentLikeError)),
        );
      },
    );

    final isLiked = likeState.isLikedByMe;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isLiked ? context.l10n.unlikeMoment : context.l10n.likeMoment,
          onPressed: likeState.isBusy
              ? null
              : () {
                  ref
                      .read(momentLikeControllerProvider(seed).notifier)
                      .setLiked(!isLiked);
                },
          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('${likeState.likeCount}'),
      ],
    );
  }
}
```

Почему это отдельный widget: details screen не должен знать optimistic update детали. Он просто показывает reaction control.

### Шаг 15. Подключить кнопку в details

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_details_content.dart
```

Добавь import:

```dart
import 'moment_like_button.dart';
```

В нижнем `Row` замени metric лайка:

```dart
Row(
  children: [
    MomentLikeButton(moment: moment),
    const SizedBox(width: AppSpacing.lg),
    _Metric(
      icon: Icons.mode_comment_outlined,
      value: moment.commentCount,
    ),
  ],
),
```

`_Metric` оставляем для comments. В главе 12 comments получат собственный interactive widget.

### Шаг 16. Обновить тесты controller-а

Файл:

```text
test/moment_like_controller_test.dart
```

Минимальные fake classes должны реально использоваться через provider override:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment_like_summary.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_likes_repository.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moment_like_controller.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';

void main() {
  test('likes moment optimistically and stores backend result', () async {
    final repository = FakeMomentLikesRepository();
    final seed = (momentId: 'moment-id', initialLikeCount: 2);
    final container = ProviderContainer(
      overrides: [
        momentLikesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(momentLikeControllerProvider(seed)).likeCount, 2);

    await Future<void>.delayed(Duration.zero);

    await container
        .read(momentLikeControllerProvider(seed).notifier)
        .setLiked(true);

    final state = container.read(momentLikeControllerProvider(seed));

    expect(repository.likeCalls, 1);
    expect(state.isLikedByMe, isTrue);
    expect(state.likeCount, 3);
    expect(state.isBusy, isFalse);
  });

  test('rolls back optimistic like when backend fails', () async {
    final repository = FakeMomentLikesRepository(shouldThrowOnLike: true);
    final seed = (momentId: 'moment-id', initialLikeCount: 2);
    final container = ProviderContainer(
      overrides: [
        momentLikesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);

    await container
        .read(momentLikeControllerProvider(seed).notifier)
        .setLiked(true);

    final state = container.read(momentLikeControllerProvider(seed));

    expect(repository.likeCalls, 1);
    expect(state.isLikedByMe, isFalse);
    expect(state.likeCount, 2);
    expect(state.error, isNotNull);
  });
}

class FakeMomentLikesRepository implements MomentLikesRepository {
  FakeMomentLikesRepository({this.shouldThrowOnLike = false});

  final bool shouldThrowOnLike;
  int likeCalls = 0;

  @override
  Future<MomentLikeSummary> fetchSummary(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 2,
      isLikedByMe: false,
    );
  }

  @override
  Future<MomentLikeSummary> likeMoment(String momentId) async {
    likeCalls += 1;

    if (shouldThrowOnLike) {
      throw StateError('like failed');
    }

    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 3,
      isLikedByMe: true,
    );
  }

  @override
  Future<MomentLikeSummary> unlikeMoment(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 2,
      isLikedByMe: false,
    );
  }
}
```

Почему в тесте есть `overrideWithValue(repository)`: fake repository должен действительно подменять provider. Иначе тест случайно пойдет в настоящий Supabase client.

### Шаг 17. Обновить widget test details

В существующем `test/widget_test.dart` moment уже имеет `likeCount` default `0`. Добавь проверку heart button на details:

```dart
expect(find.byTooltip('Like'), findsOneWidget);
```

Если test падает из-за scrollable content, повтори прием из главы 8:

```dart
await tester.drag(find.byType(ListView), const Offset(0, -500));
await tester.pumpAndSettle();
```

Details content остается scrollable, потому что media занимает первый viewport.

## Проверка

Команды:

```bash
supabase db push
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

Ручная проверка Android:

1. Запустить приложение.
2. Войти в аккаунт.
3. Открыть карту.
4. Открыть details любого moment.
5. Нажать heart.
6. Убедиться, что иконка стала filled, count увеличился сразу.
7. Закрыть details и открыть снова.
8. Убедиться, что liked state и count сохранились.
9. Нажать heart еще раз.
10. Убедиться, что лайк снялся и count уменьшился.

Supabase Dashboard проверка:

1. Открыть Table editor -> `moment_likes`.
2. После like должна появиться строка с `moment_id` и твоим `user_id`.
3. После unlike строка должна исчезнуть.
4. Повторный like не должен создавать duplicate row.

## Частые ошибки

### Ошибка: один пользователь может поставить два лайка

Причина: нет primary key `(moment_id, user_id)`.

Проверь migration:

```sql
primary key (moment_id, user_id)
```

### Ошибка: retry снимает лайк обратно

Причина: сделан `toggleLike`.

Используй idempotent команды:

```dart
likeMoment(momentId);
unlikeMoment(momentId);
```

### Ошибка: UI зависает после быстрого double tap

Причина: кнопка не блокируется на время request-а.

Проверь:

```dart
onPressed: likeState.isBusy ? null : () { ... }
```

### Ошибка: после backend error count остается optimistic

Причина: нет rollback-а на previous state.

В `catch` должно быть:

```dart
state = previous.copyWith(isBusy: false, error: error);
```

### Ошибка: тест использует fake class, но все равно идет в Supabase

Причина: fake class создан, но provider не override-нут.

Проверь:

```dart
ProviderContainer(
  overrides: [
    momentLikesRepositoryProvider.overrideWithValue(repository),
  ],
);
```

### Ошибка: route `/moments/new` снова ломается

Глава 11 не должна менять order routes. Напоминание: `/moments/new` стоит раньше `/moments/:momentId`.

### Ошибка: location button снова только спрашивает permission

Глава 11 не должна трогать map location behavior. Кнопка `Show my location` должна продолжать отправлять focus command в карту.

## Definition of Done

- Migration `moment_likes` добавлена.
- RLS policies разрешают select authenticated, insert/delete только own likes.
- `like_moment` и `unlike_moment` idempotent.
- `nearby_moments` возвращает `like_count`.
- `Moment.copyWith` добавлен только с нужными полями.
- `MomentLikeSummary` и DTO созданы.
- `MomentLikesRepository` создан.
- Supabase implementation использует `rpc(...)`, без deprecated `.execute()`.
- `MomentLikeController` делает optimistic update.
- При ошибке controller откатывает previous state.
- На время request-а heart button disabled.
- Details показывает interactive like button.
- Tests используют fake repository через provider override.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка like/unlike выполнена.

## Что прислать на ревью

После реализации напиши:

```text
Глава 11 готова, проверь код.
```

Я буду проверять:

- idempotency `likeMoment`/`unlikeMoment`;
- наличие unique constraint;
- корректность RLS;
- optimistic update и rollback;
- что fake repository реально используется в tests;
- что details test учитывает scrollable content;
- что глава 11 не ломает upload/save flow главы 10;
- что `/moments/new` все еще стоит перед `/moments/:momentId`;
- что location button все еще центрирует карту.
