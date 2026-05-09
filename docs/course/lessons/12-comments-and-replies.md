# 12 Comments and Replies

Статус: next.

## Что строим

В главе 11 у Geo Moments появилась первая реакция: пользователь может поставить и убрать лайк, счетчик обновляется оптимистично, а состояние сохраняется в Supabase.

В главе 12 добавим обсуждение момента:

- список комментариев на экране details;
- отправку нового комментария;
- ответы на комментарии с одним уровнем вложенности;
- счетчик комментариев;
- realtime обновление открытого обсуждения;
- базовую пагинацию;
- аккуратный input, который не ломается при keyboard и длинном тексте.

После главы пользователь сможет открыть moment details, написать комментарий, ответить на чужой комментарий и увидеть новые сообщения без ручного refresh.

## Почему это важно

Комментарии сложнее лайков. Лайк - это маленькая idempotent команда. Комментарий - это пользовательский контент:

- его нужно валидировать;
- его нужно хранить в отдельной таблице;
- у него есть автор;
- он может появиться из realtime, пока экран открыт;
- список может стать длинным;
- input должен удобно работать на телефоне.

В Android/backend опыте это похоже на:

```text
Details screen
  -> comments ViewModel
  -> repository.fetchPage(momentId)
  -> repository.addComment(...)
  -> websocket/realtime invalidates current page
```

Во Flutter роль ViewModel снова выполняет Riverpod controller, а Supabase Realtime заменяет websocket boilerplate.

## Словарь главы

`Comment` - текстовая запись под moment.

`Reply` - ответ на комментарий. В этой главе разрешаем только один уровень replies: comment -> replies. Reply на reply не создаем.

`Root comment` - комментарий без `parent_id`.

`Thread` - root comment вместе с replies.

`Realtime subscription` - подписка на изменения таблицы Supabase через websocket channel.

`Pagination` - загрузка списка частями. В этой главе грузим первые N root comments и replies к ним.

`Cursor` - значение, после которого загружаем следующую страницу. Для comments удобно использовать `created_at`.

## 1. Как будем моделировать comments

Не добавляем comments внутрь `moments`. Comments - отдельная сущность:

```text
moments
  id
  ...

moment_comments
  id
  moment_id
  author_id
  parent_id
  body
  created_at
```

`parent_id = null` означает root comment.

`parent_id = <comment id>` означает reply.

Ограничение "только один уровень replies" лучше держать в database, а не только в UI. UI можно обойти, а database constraint/trigger защитит данные.

## 2. Почему replies только одного уровня

Бесконечные nested comments быстро усложняют:

- layout;
- accessibility;
- pagination;
- realtime reconciliation;
- moderation.

Для Geo Moments достаточно короткого обсуждения вокруг эмоции в точке. Один уровень replies дает диалог, но не превращает приложение в форум.

```text
Comment A
  Reply A1
  Reply A2

Comment B
  Reply B1
```

Reply на `Reply A1` в этой главе запрещен.

## 3. Как работает realtime

Без realtime flow такой:

```text
open details -> fetch comments -> user waits -> manually refresh
```

С realtime:

```text
open details
  -> fetch comments page
  -> subscribe to inserts for this moment
  -> another user adds comment
  -> channel receives event
  -> controller refetches current page
```

В этой главе не будем вручную вставлять payload в дерево comments. Это возможно, но требует аккуратно обрабатывать ordering, replies и duplicates.

Для учебного этапа проще и надежнее:

```dart
callback: (_) {
  unawaited(refresh());
}
```

То есть realtime event говорит: "данные изменились, перечитай список".

## 4. Какой Supabase Realtime API используем

В установленном `supabase_flutter 2.12.4` актуальный API такой:

```dart
final channel = supabase.channel('moment-comments:$momentId');

channel
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'moment_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'moment_id',
        value: momentId,
      ),
      callback: (payload) {
        // refresh comments
      },
    )
    .subscribe();
```

При dispose:

```dart
await supabase.removeChannel(channel);
```

Не используем старые realtime APIs и не используем Supabase `.execute()`.

## Целевая структура после главы

```text
supabase/
  migrations/
    202605090003_create_moment_comments.sql

lib/
  src/
    features/
      moments/
        data/
          dto/
            moment_comment_dto.dart
          repositories/
            supabase_moment_comments_repository.dart
        domain/
          entities/
            moment_comment.dart
            create_comment_command.dart
          repositories/
            moment_comments_repository.dart
        presentation/
          controllers/
            moment_comments_controller.dart
            moments_providers.dart
          widgets/
            moment_comment_list.dart
            moment_comment_tile.dart
            moment_comment_input.dart
            moment_details_content.dart
```

## Практика

### Шаг 1. Добавить migration для comments

Файл:

```text
supabase/migrations/202605090003_create_moment_comments.sql
```

Код:

```sql
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
```

Почему `trim(body)` в check: строка из пробелов не должна быть валидным комментарием.

Почему `parent_id` nullable: один table хранит и comments, и replies.

### Шаг 2. Добавить trigger для одного уровня replies

В тот же migration добавь:

```sql
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
```

Это защищает backend от reply на reply, даже если UI ошибется.

### Шаг 3. Добавить RLS policies

В тот же migration:

```sql
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
```

В этой главе UI не делает edit/delete, но policies можно добавить сразу. Это не усложняет Flutter-код и делает backend завершенным.

### Шаг 4. Включить realtime для таблицы

В тот же migration:

```sql
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
```

Если Supabase project не разрешает выполнить это из migration, включи таблицу вручную:

```text
Supabase Dashboard -> Database -> Replication -> supabase_realtime -> moment_comments
```

### Шаг 5. Добавить RPC для comments page

В тот же migration добавь function, которая возвращает root comments и replies к ним:

```sql
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
    select c.*
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
    select *
    from root_comments

    union all

    select replies.*
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
    coalesce(c.parent_id, c.id),
    c.parent_id is not null,
    c.created_at asc;
$$;
```

Почему root comments загружаем `desc`, а финальный результат сортируем иначе: сначала выбираем свежую страницу root comments, затем группируем root comment и его replies для UI.

### Шаг 6. Добавить command functions

В тот же migration:

```sql
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
```

Почему command возвращает JSON: Flutter может сразу показать созданный comment, даже до следующего realtime refresh.

### Шаг 7. Обновить comment counts

В migration `202605090003_create_moment_comments.sql` переопредели `nearby_moments`, чтобы `comment_count` стал настоящим:

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
```

Применить migration:

```bash
supabase db push
```

Если CLI не настроен, выполни SQL через Supabase Dashboard SQL Editor.

### Шаг 8. Создать `MomentComment`

Файл:

```text
lib/src/features/moments/domain/entities/moment_comment.dart
```

Код:

```dart
class MomentComment {
  const MomentComment({
    required this.id,
    required this.momentId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.replies = const [],
  });

  final String id;
  final String momentId;
  final String authorId;
  final String? parentId;
  final String body;
  final DateTime createdAt;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final List<MomentComment> replies;

  bool get isReply => parentId != null;

  MomentComment copyWith({
    List<MomentComment>? replies,
  }) {
    return MomentComment(
      id: id,
      momentId: momentId,
      authorId: authorId,
      parentId: parentId,
      body: body,
      createdAt: createdAt,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      replies: replies ?? this.replies,
    );
  }
}
```

Domain entity не импортирует Flutter widgets и не знает про Supabase.

### Шаг 9. Создать command entity

Файл:

```text
lib/src/features/moments/domain/entities/create_comment_command.dart
```

Код:

```dart
class CreateCommentCommand {
  const CreateCommentCommand({
    required this.momentId,
    required this.body,
    this.parentId,
  });

  final String momentId;
  final String body;
  final String? parentId;

  bool get isReply => parentId != null;
}
```

`authorId` не передаем из UI: backend берет автора из `auth.uid()` внутри RPC. Так нельзя отправить comment от имени другого user-а.

### Шаг 10. Создать DTO

Файл:

```text
lib/src/features/moments/data/dto/moment_comment_dto.dart
```

Код:

```dart
import '../../domain/entities/moment_comment.dart';

class MomentCommentDto {
  const MomentCommentDto({
    required this.id,
    required this.momentId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  final String id;
  final String momentId;
  final String authorId;
  final String? parentId;
  final String body;
  final DateTime createdAt;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  factory MomentCommentDto.fromJson(Map<String, dynamic> json) {
    return MomentCommentDto(
      id: json['id'] as String,
      momentId: json['moment_id'] as String,
      authorId: json['author_id'] as String,
      parentId: json['parent_id'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorDisplayName: json['author_display_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
    );
  }

  MomentComment toDomain() {
    return MomentComment(
      id: id,
      momentId: momentId,
      authorId: authorId,
      parentId: parentId,
      body: body,
      createdAt: createdAt,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
    );
  }
}
```

### Шаг 11. Создать repository interface

Файл:

```text
lib/src/features/moments/domain/repositories/moment_comments_repository.dart
```

Код:

```dart
import '../entities/create_comment_command.dart';
import '../entities/moment_comment.dart';

abstract interface class MomentCommentsRepository {
  Future<List<MomentComment>> fetchCommentsPage({
    required String momentId,
    int limit = 20,
    DateTime? before,
  });

  Future<MomentComment> createComment(CreateCommentCommand command);
}
```

Один метод `createComment` покрывает и root comments, и replies, потому что `parentId` optional.

### Шаг 12. Реализовать Supabase repository

Файл:

```text
lib/src/features/moments/data/repositories/supabase_moment_comments_repository.dart
```

Код:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/create_comment_command.dart';
import '../../domain/entities/moment_comment.dart';
import '../../domain/repositories/moment_comments_repository.dart';
import '../dto/moment_comment_dto.dart';

class SupabaseMomentCommentsRepository implements MomentCommentsRepository {
  const SupabaseMomentCommentsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MomentComment>> fetchCommentsPage({
    required String momentId,
    int limit = 20,
    DateTime? before,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'moment_comments_page',
      params: {
        'target_moment_id': momentId,
        'page_limit': limit,
        'before_created_at': before?.toUtc().toIso8601String(),
      },
    );

    final flat = response
        .cast<Map<String, dynamic>>()
        .map(MomentCommentDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();

    return _toTree(flat);
  }

  @override
  Future<MomentComment> createComment(CreateCommentCommand command) async {
    final response = await _client.rpc<dynamic>(
      'create_moment_comment',
      params: {
        'target_moment_id': command.momentId,
        'comment_body': command.body,
        'parent_comment_id': command.parentId,
      },
    );

    final json = Map<String, dynamic>.from(response as Map);
    return MomentCommentDto.fromJson(json).toDomain();
  }

  List<MomentComment> _toTree(List<MomentComment> flat) {
    final roots = <String, MomentComment>{};
    final repliesByParent = <String, List<MomentComment>>{};

    for (final comment in flat) {
      final parentId = comment.parentId;
      if (parentId == null) {
        roots[comment.id] = comment;
      } else {
        repliesByParent.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    return roots.values.map((root) {
      return root.copyWith(replies: repliesByParent[root.id] ?? const []);
    }).toList();
  }
}
```

Почему tree строим в repository: UI должен получать удобную domain модель, а не flat SQL rows.

### Шаг 13. Добавить provider

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

Imports:

```dart
import '../../data/repositories/supabase_moment_comments_repository.dart';
import '../../domain/repositories/moment_comments_repository.dart';
```

Provider:

```dart
final momentCommentsRepositoryProvider =
    Provider<MomentCommentsRepository>((ref) {
  return SupabaseMomentCommentsRepository(ref.watch(supabaseClientProvider));
});
```

### Шаг 14. Создать comments controller

Файл:

```text
lib/src/features/moments/presentation/controllers/moment_comments_controller.dart
```

Код:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../domain/entities/create_comment_command.dart';
import '../../domain/entities/moment_comment.dart';
import 'moments_providers.dart';

final momentCommentsControllerProvider = AsyncNotifierProvider.family<
    MomentCommentsController,
    List<MomentComment>,
    String>(MomentCommentsController.new);

class MomentCommentsController
    extends AsyncNotifier<List<MomentComment>> {
  MomentCommentsController(this._momentId);

  final String _momentId;
  RealtimeChannel? _channel;

  @override
  Future<List<MomentComment>> build() async {
    _subscribeToRealtime();
    return _fetch();
  }

  Future<void> addRootComment(String body) {
    return _create(body: body);
  }

  Future<void> addReply({
    required String parentId,
    required String body,
  }) {
    return _create(body: body, parentId: parentId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> _create({
    required String body,
    String? parentId,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final previous = state.valueOrNull ?? const <MomentComment>[];

    state = await AsyncValue.guard(() async {
      await ref.read(momentCommentsRepositoryProvider).createComment(
            CreateCommentCommand(
              momentId: _momentId,
              parentId: parentId,
              body: trimmed,
            ),
          );

      final comments = await _fetch();

      ref.invalidate(momentDetailsProvider(_momentId));
      ref.invalidate(nearbyMomentsProvider);

      return comments;
    });

    if (state.hasError && previous.isNotEmpty) {
      state = AsyncError(state.error!, state.stackTrace!)
          .copyWithPrevious(AsyncData(previous));
    }
  }

  Future<List<MomentComment>> _fetch() {
    return ref.read(momentCommentsRepositoryProvider).fetchCommentsPage(
          momentId: _momentId,
        );
  }

  void _subscribeToRealtime() {
    if (_channel != null) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    final channel = client.channel('moment-comments:$_momentId');
    _channel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'moment_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'moment_id',
            value: _momentId,
          ),
          callback: (_) {
            unawaited(refresh());
          },
        )
        .subscribe();

    ref.onDispose(() {
      final activeChannel = _channel;
      if (activeChannel != null) {
        unawaited(client.removeChannel(activeChannel));
      }
    });
  }
}
```

Если `copyWithPrevious` недоступен в установленной Riverpod версии, упростить catch можно так:

```dart
if (state.hasError && previous.isNotEmpty) {
  state = AsyncData(previous);
}
```

Главная идея: не очищать список при failed submit.

### Шаг 15. Добавить локализацию

Файлы:

```text
lib/l10n/app_en.arb
lib/l10n/app_ru.arb
lib/l10n/app_es.arb
```

EN:

```json
"commentsTitle": "Comments",
"commentsEmpty": "No comments yet.",
"commentInputHint": "Write a comment",
"replyInputHint": "Write a reply",
"sendComment": "Send",
"replyToComment": "Reply",
"cancelReply": "Cancel reply",
"commentSendError": "Could not send comment."
```

RU:

```json
"commentsTitle": "Комментарии",
"commentsEmpty": "Комментариев пока нет.",
"commentInputHint": "Написать комментарий",
"replyInputHint": "Написать ответ",
"sendComment": "Отправить",
"replyToComment": "Ответить",
"cancelReply": "Отменить ответ",
"commentSendError": "Не удалось отправить комментарий."
```

ES:

```json
"commentsTitle": "Comentarios",
"commentsEmpty": "Todavía no hay comentarios.",
"commentInputHint": "Escribe un comentario",
"replyInputHint": "Escribe una respuesta",
"sendComment": "Enviar",
"replyToComment": "Responder",
"cancelReply": "Cancelar respuesta",
"commentSendError": "No se pudo enviar el comentario."
```

После ARB:

```bash
flutter gen-l10n
```

### Шаг 16. Создать input widget

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_comment_input.dart
```

Код:

```dart
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';

class MomentCommentInput extends StatefulWidget {
  const MomentCommentInput({
    required this.onSubmit,
    this.isReply = false,
    this.isSubmitting = false,
    super.key,
  });

  final ValueChanged<String> onSubmit;
  final bool isReply;
  final bool isSubmitting;

  @override
  State<MomentCommentInput> createState() => _MomentCommentInputState();
}

class _MomentCommentInputState extends State<MomentCommentInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !widget.isSubmitting,
            minLines: 1,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: widget.isReply
                  ? context.l10n.replyInputHint
                  : context.l10n.commentInputHint,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          tooltip: context.l10n.sendComment,
          onPressed: widget.isSubmitting ? null : _submit,
          icon: const Icon(Icons.send_outlined),
        ),
      ],
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    widget.onSubmit(text);
    _controller.clear();
  }
}
```

Почему `TextField`, а не `TextFormField`: это inline composer, а не form screen. Валидации достаточно в `_submit` и backend check.

### Шаг 17. Создать comment tile

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_comment_tile.dart
```

Код:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment_comment.dart';

class MomentCommentTile extends StatelessWidget {
  const MomentCommentTile({
    required this.comment,
    required this.onReply,
    this.isReply = false,
    super.key,
  });

  final MomentComment comment;
  final ValueChanged<MomentComment> onReply;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final author = comment.authorDisplayName ?? comment.authorId;
    final localeName = Localizations.localeOf(context).toString();
    final createdAt = DateFormat.yMMMd(
      localeName,
    ).add_Hm().format(comment.createdAt.toLocal());

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? AppSpacing.xl : 0,
        top: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(author, style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(comment.body),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(createdAt, style: textTheme.bodySmall),
              if (!isReply) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => onReply(comment),
                  child: Text(context.l10n.replyToComment),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
```

Для production UI позже можно заменить UUID fallback на hidden author, как мы сделали в details author. В этой главе лучше сначала стабилизировать data flow.

### Шаг 18. Создать comments list

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_comment_list.dart
```

Код:

```dart
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment_comment.dart';
import 'moment_comment_tile.dart';

class MomentCommentList extends StatelessWidget {
  const MomentCommentList({
    required this.comments,
    required this.onReply,
    super.key,
  });

  final List<MomentComment> comments;
  final ValueChanged<MomentComment> onReply;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(context.l10n.commentsEmpty),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final comment in comments) ...[
          MomentCommentTile(comment: comment, onReply: onReply),
          for (final reply in comment.replies)
            MomentCommentTile(
              comment: reply,
              onReply: onReply,
              isReply: true,
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
```

Не используем nested `ListView` внутри details `ListView`. Это частая причина scroll/test проблем. Comments list здесь обычный `Column` внутри уже существующего scrollable details.

### Шаг 19. Встроить comments в details content

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_details_content.dart
```

Сейчас это `StatelessWidget`. Преврати его в `ConsumerStatefulWidget`, потому что нужен local state `replyTarget`.

Imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/moment_comments_controller.dart';
import 'moment_comment_input.dart';
import 'moment_comment_list.dart';
```

Схема build:

```dart
class MomentDetailsContent extends ConsumerStatefulWidget {
  const MomentDetailsContent({required this.moment, super.key});

  final Moment moment;

  @override
  ConsumerState<MomentDetailsContent> createState() =>
      _MomentDetailsContentState();
}

class _MomentDetailsContentState extends ConsumerState<MomentDetailsContent> {
  MomentComment? _replyTarget;

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final comments = ref.watch(momentCommentsControllerProvider(moment.id));
    final isSubmitting = comments.isLoading && comments.valueOrNull != null;

    return ListView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      children: [
        // existing media/text/author/date/emotion/metrics content
        const SizedBox(height: AppSpacing.xl),
        Text(context.l10n.commentsTitle, style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        comments.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(momentCommentsControllerProvider(moment.id));
            },
            icon: const Icon(Icons.refresh_outlined),
            label: Text(context.l10n.retry),
          ),
          data: (items) => MomentCommentList(
            comments: items,
            onReply: (comment) {
              setState(() {
                _replyTarget = comment;
              });
            },
          ),
        ),
        if (_replyTarget != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InputChip(
            label: Text('${context.l10n.replyToComment}: ${_replyTarget!.authorDisplayName ?? ''}'),
            onDeleted: () {
              setState(() {
                _replyTarget = null;
              });
            },
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        MomentCommentInput(
          isReply: _replyTarget != null,
          isSubmitting: isSubmitting,
          onSubmit: (body) async {
            final target = _replyTarget;
            final controller = ref.read(
              momentCommentsControllerProvider(moment.id).notifier,
            );

            if (target == null) {
              await controller.addRootComment(body);
            } else {
              await controller.addReply(parentId: target.id, body: body);
            }

            if (!mounted) {
              return;
            }

            setState(() {
              _replyTarget = null;
            });
          },
        ),
      ],
    );
  }
}
```

При вставке не удаляй существующий media/text/like block. Добавь comments после likes/comments metrics.

Почему bottom padding зависит от `MediaQuery.viewInsetsOf(context).bottom`: при открытой клавиатуре composer не должен оказаться под keyboard.

### Шаг 20. Обновить details comment count

Файл:

```text
lib/src/features/moments/data/repositories/supabase_moments_repository.dart
```

В `fetchMomentById` после загрузки moment можно дочитать count:

```dart
final commentCount = await _client
    .from('moment_comments')
    .count(CountOption.exact)
    .eq('moment_id', id);
```

Если API count в текущей версии неудобен, проще добавить RPC:

```sql
create or replace function public.moment_comment_count(target_moment_id uuid)
returns integer
language sql
stable
as $$
  select count(*)::int
  from public.moment_comments
  where moment_id = target_moment_id;
$$;
```

И в Dart:

```dart
final count = await _client.rpc<int>(
  'moment_comment_count',
  params: {'target_moment_id': id},
);

return moment.copyWith(commentCount: count);
```

Для главы 12 выбери RPC: он стабильнее и одинаково читается с остальными backend helpers.

### Шаг 21. Добавить tests

Файл:

```text
test/moment_comments_controller_test.dart
```

Покрыть минимум:

- initial fetch возвращает comments;
- `addRootComment` вызывает fake repository с `parentId == null`;
- `addReply` вызывает fake repository с `parentId`;
- fake repository реально используется через provider override.

Скелет:

```dart
class FakeMomentCommentsRepository implements MomentCommentsRepository {
  final created = <CreateCommentCommand>[];

  @override
  Future<List<MomentComment>> fetchCommentsPage({
    required String momentId,
    int limit = 20,
    DateTime? before,
  }) async {
    return [
      MomentComment(
        id: 'comment-1',
        momentId: momentId,
        authorId: 'user-1',
        body: 'First comment',
        createdAt: DateTime.utc(2026, 5, 9),
        authorDisplayName: 'Test User',
      ),
    ];
  }

  @override
  Future<MomentComment> createComment(CreateCommentCommand command) async {
    created.add(command);
    return MomentComment(
      id: 'created-comment',
      momentId: command.momentId,
      authorId: 'user-1',
      parentId: command.parentId,
      body: command.body,
      createdAt: DateTime.utc(2026, 5, 9),
      authorDisplayName: 'Test User',
    );
  }
}
```

В widget test для details добавь проверку, что comments section есть после scroll:

```dart
await tester.drag(find.byType(ListView), const Offset(0, -700));
await tester.pumpAndSettle();

expect(find.text('Comments'), findsOneWidget);
expect(find.text('Write a comment'), findsOneWidget);
```

Не забывай: details content scrollable, поэтому тест должен scroll-ить.

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

1. Открыть приложение.
2. Открыть details любого moment.
3. Пролистать до comments.
4. Написать root comment.
5. Убедиться, что comment появился.
6. Нажать `Reply` под comment.
7. Написать reply.
8. Убедиться, что reply отображается с отступом.
9. Открыть этот же moment на втором устройстве или после hot restart.
10. Проверить, что comments загружаются из Supabase.
11. Если есть второй клиент, проверить realtime: comment появляется без ручного refresh.

Supabase Dashboard проверка:

1. Table editor -> `moment_comments`.
2. Root comment имеет `parent_id = null`.
3. Reply имеет `parent_id = id root comment`.
4. Reply на reply должен падать.
5. Replication для `moment_comments` включена.

## Частые ошибки

### Ошибка: comments не появляются в realtime

Проверь:

- таблица `moment_comments` добавлена в `supabase_realtime`;
- приложение подписано на правильный `moment_id`;
- filter использует `column: 'moment_id'`;
- пользователь authenticated.

### Ошибка: reply можно отправить на reply

Причина: validation есть только в UI.

Проверь trigger `validate_moment_comment_parent`.

### Ошибка: widget test не видит comments input

Details content scrollable. Нужно проскроллить:

```dart
await tester.drag(find.byType(ListView), const Offset(0, -700));
await tester.pumpAndSettle();
```

### Ошибка: fake repository создан, но тест ходит в Supabase

Проверь provider override:

```dart
momentCommentsRepositoryProvider.overrideWithValue(repository)
```

Fake class должен реально использоваться, как в главе 11.

### Ошибка: клавиатура закрывает input

Проверь bottom padding:

```dart
bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg
```

### Ошибка: route `/moments/new` опять открывает details

Глава 12 не должна менять routing order. `/moments/new` остается перед `/moments/:momentId`.

### Ошибка: details снова не открывается из-за author profile

Не удаляй fallback из `SupabaseMomentsRepository`: если embedded `profiles(...)` не сработал, repository должен дочитать profile отдельным запросом.

## Definition of Done

- `moment_comments` table создана.
- RLS policies добавлены.
- Reply depth ограничен database trigger-ом.
- Realtime для `moment_comments` включен.
- RPC `moment_comments_page` возвращает root comments и replies.
- RPC `create_moment_comment` создает root comment или reply от `auth.uid()`.
- `nearby_moments` возвращает настоящий `comment_count`.
- Domain entities и DTO созданы.
- `MomentCommentsRepository` создан.
- Supabase implementation использует актуальный `rpc(...)`.
- `MomentCommentsController` загружает comments и подписывается на realtime.
- Realtime channel удаляется через `removeChannel` при dispose.
- Details показывает comments section.
- Input не скрывается под keyboard.
- Reply mode можно включить и отменить.
- Tests используют fake repository через provider override.
- Widget tests учитывают scrollable details.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка root comment/reply/realtime выполнена.

## Что прислать на ревью

После реализации напиши:

```text
Глава 12 готова, проверь код.
```

Я буду проверять:

- что comments не ломают details loading;
- что root comments и replies правильно группируются;
- что reply на reply невозможно сохранить;
- что realtime subscription не течет после dispose;
- что fake classes реально override-ят providers в tests;
- что UI не содержит UUID автора, если display name доступен;
- что `/moments/new` route order не сломан;
- что location button все еще центрирует карту;
- что лайки главы 11 продолжают работать.
