# 10 Upload and Save Moment

Статус: next.

## Источники

Эта глава опирается на актуальные Supabase Flutter/Dart APIs:

- Supabase Storage upload: https://supabase.com/docs/reference/dart/storage-from-upload
- Supabase Storage public URL: https://supabase.com/docs/reference/dart/storage-from-getpublicurl
- Supabase Storage remove: https://supabase.com/docs/reference/dart/storage-from-remove
- Supabase insert/select: https://supabase.com/docs/reference/dart/insert
- Supabase Storage access control: https://supabase.com/docs/guides/storage/security/access-control
- Supabase Storage public buckets: https://supabase.com/docs/guides/storage/buckets/fundamentals

В примерах используются текущие API:

- `storage.from(bucket).upload(path, File(...), fileOptions: FileOptions(...))`;
- `storage.from(bucket).getPublicUrl(path)`;
- `storage.from(bucket).remove([path])`;
- `.insert(...).select(...).single()`;
- Riverpod `NotifierProvider`.

Не используем старый Supabase response API с `.execute()`, `.data`, `.error`.

## Что строим в этой главе

В главе 9 пользователь уже может открыть `/moments/new`, выбрать или снять media, написать текст и сохранить черновик в локальном state. Но этот moment еще не попадает в Supabase.

В главе 10 сделаем настоящий save flow:

- добавим storage policies для bucket `moment-media`;
- передадим координаты текущего центра карты в create route;
- добавим координаты в `CreateMomentDraft`;
- создадим `MomentMediaStorage` service;
- загрузим локальный `PickedMomentMedia` в Supabase Storage;
- получим public URL через `getPublicUrl`;
- создадим row в таблице `moments`;
- покажем stage progress: `uploading media` -> `saving moment`;
- сделаем rollback: если insert row упал после upload, удалим загруженный файл;
- сбросим draft после успешной публикации;
- обновим карту через invalidation nearby provider;
- обновим tests через fake storage/repository.

После главы пользователь сможет:

1. Открыть create moment screen.
2. Выбрать или снять media.
3. Ввести description.
4. Нажать `Publish`.
5. Дождаться upload/save.
6. Вернуться на карту и увидеть новый moment после обновления данных.

Перед этой главой уже исправлен важный UX: кнопка "Show my location" на карте не только запрашивает permission, но и центрирует карту на location puck. Поэтому координаты нового момента в этой главе берем из текущего центра карты: пользователь может сначала нажать location-кнопку, затем открыть create flow.

## Почему это важно

Сохранение moment - это не одна операция. На клиенте это цепочка:

```text
local media file
  -> upload to Supabase Storage
  -> get public URL
  -> insert row into moments
  -> invalidate nearby moments
  -> reset draft
```

Проблема: Supabase Storage upload и Postgres insert не находятся в одной database transaction. Если файл загрузился, а insert в `moments` упал, в bucket останется бесхозный файл.

Поэтому нам нужен rollback:

```text
upload media OK
insert row FAILED
  -> remove uploaded media path
  -> show error
```

Это не идеальная distributed transaction, но для mobile client это практичный и понятный подход.

Похожий Android/backend опыт:

```text
ViewModel
  -> upload file to object storage
  -> save metadata row
  -> if metadata save fails, delete object
```

Во Flutter роль ViewModel у нас выполняет Riverpod controller.

## Словарь главы

`Storage bucket` - контейнер для файлов в Supabase Storage.

`Object path` - путь файла внутри bucket, например `user-id/20260507120000000.jpg`.

`Public URL` - URL, по которому файл можно открыть из public bucket.

`Storage policy` - RLS policy на таблице `storage.objects`, которая разрешает upload/delete/list.

`Rollback` - компенсирующее действие после частичного успеха. В этой главе rollback удаляет файл, если insert row не прошел.

`Stage progress` - прогресс по этапам операции. Это не byte-level upload progress. Простое `upload()` из Supabase Flutter не дает нам стабильного callback-а по байтам, поэтому в этой главе показываем понятные стадии.

`Command` - объект, который описывает намерение сохранить новый moment.

## 1. Как будет работать save flow

Финальный flow главы:

```text
MapScreen
  -> create button
  -> /moments/new?lat=-34.6037&lng=-58.3816
  -> CreateMomentScreen(latitude, longitude)
  -> CreateMomentDraftController.setLocation(...)
  -> user picks media and types text
  -> Publish
  -> CreateMomentSaveController.submit()
  -> MomentMediaStorage.upload(...)
  -> MomentsRepository.createMoment(...)
  -> invalidate nearbyMomentsProvider
  -> reset draft
  -> pop back to map
```

Почему координаты передаем через query parameters:

- create moment должен знать, где поставить точку;
- сейчас у нас нет полноценного current GPS service;
- самая понятная MVP-модель: moment создается в текущем центре карты;
- route можно восстановить без `extra`.

Не используем `state.extra`:

```dart
context.push('/moments/new', extra: _center);
```

Проблема `extra` та же, что в details flow: оно не deep-link-friendly и может потеряться при restore.

## 2. Почему нужен отдельный storage service

Можно положить upload прямо в `SupabaseMomentsRepository`, но тогда repository начнет делать слишком много:

```text
SupabaseMomentsRepository
  -> upload local file
  -> build object path
  -> get public URL
  -> insert database row
  -> rollback file
```

Разделим ответственность:

```text
MomentMediaStorage
  -> работает только с bucket/object files

MomentsRepository
  -> работает с table moments

CreateMomentSaveController
  -> orchestrates upload -> insert -> rollback
```

Это не enterprise-разделение ради разделения. Здесь действительно две разные backend области: Storage и Postgres.

## 3. Storage policies перед кодом Flutter

Bucket `moment-media` уже создан в главе 6 как public:

```sql
insert into storage.buckets (id, name, public)
values ('moment-media', 'moment-media', true)
on conflict (id) do nothing;
```

Но public bucket означает только то, что файл можно читать по URL. Upload/delete все равно требуют policies на `storage.objects`.

Нам нужно разрешить authenticated user-у:

- upload в свою папку;
- select свои объекты для delete/list operations;
- delete свои объекты для rollback.

Путь будет таким:

```text
{auth.uid()}/{timestamp}.{extension}
```

Тогда policy может проверить первую папку:

```sql
(storage.foldername(name))[1] = (select auth.uid())::text
```

## Целевая структура после главы

```text
supabase/
  migrations/
    202605070001_moment_media_storage_policies.sql

lib/
  src/
    app/
      router/
        app_router.dart
    features/
      map/
        presentation/
          screens/
            map_screen.dart
      moments/
        data/
          repositories/
            supabase_moments_repository.dart
          services/
            moment_media_storage.dart
            supabase_moment_media_storage.dart
        domain/
          entities/
            create_moment_command.dart
            create_moment_draft.dart
            picked_moment_media.dart
            uploaded_moment_media.dart
          repositories/
            moments_repository.dart
        presentation/
          controllers/
            create_moment_draft_controller.dart
            create_moment_save_controller.dart
            moments_providers.dart
          screens/
            create_moment_screen.dart
```

## Практика

### Шаг 1. Добавить storage policies migration

Файл:

```text
supabase/migrations/202605070001_moment_media_storage_policies.sql
```

Код:

```sql
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
```

Почему нужен `select` для delete: Supabase Storage `remove()` требует `delete` и `select` permissions.

Почему bucket public, но select policy все равно есть: public URL чтение bypass-ит download access control, но API operations вроде list/remove все еще идут через policies.

Применить migration:

```bash
supabase db push
```

Если работаешь только через Dashboard SQL editor, выполни SQL там, но файл migration все равно оставь в repo.

### Шаг 2. Передать координаты в create route

Файл:

```text
lib/src/app/router/app_router.dart
```

Сначала обнови paths:

```dart
abstract final class AppRoutePaths {
  static const splash = '/splash';
  static const auth = '/auth';
  static const map = '/';
  static const settings = '/settings';
  static const createMomentPath = '/moments/new';
  static const momentDetailsPattern = '/moments/:momentId';

  static String createMoment({
    required double latitude,
    required double longitude,
  }) {
    return Uri(
      path: createMomentPath,
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      },
    ).toString();
  }

  static String momentDetails(String momentId) {
    return '/moments/${Uri.encodeComponent(momentId)}';
  }
}
```

Теперь route:

```dart
GoRoute(
  path: AppRoutePaths.createMomentPath,
  builder: (context, state) {
    final latitude = double.tryParse(state.uri.queryParameters['lat'] ?? '');
    final longitude = double.tryParse(state.uri.queryParameters['lng'] ?? '');

    return CreateMomentScreen(
      latitude: latitude ?? MapCameraCenter.buenosAires.latitude,
      longitude: longitude ?? MapCameraCenter.buenosAires.longitude,
    );
  },
),
```

Добавь import:

```dart
import '../../features/map/domain/entities/map_camera_center.dart';
```

Важно: route `/moments/new` должен стоять перед `/moments/:momentId`, как мы уже исправляли после главы 9.

### Шаг 3. Обновить кнопку create на карте

Файл:

```text
lib/src/features/map/presentation/screens/map_screen.dart
```

Кнопка должна передавать текущий center:

```dart
IconButton(
  tooltip: context.l10n.createMomentTooltip,
  onPressed: () {
    context.push(
      AppRoutePaths.createMoment(
        latitude: _center.latitude,
        longitude: _center.longitude,
      ),
    );
  },
  icon: const Icon(Icons.add_location_alt_outlined),
),
```

Почему `_center`: это state карты. Если пользователь подвинул карту, новый момент создается в центре текущего viewport.

### Шаг 4. Добавить location в draft

Файл:

```text
lib/src/features/moments/domain/entities/create_moment_draft.dart
```

Обнови entity:

```dart
import 'picked_moment_media.dart';

class CreateMomentDraft {
  const CreateMomentDraft({
    this.text = '',
    this.emotion = '',
    this.media,
    this.latitude,
    this.longitude,
  });

  final String text;
  final String emotion;
  final PickedMomentMedia? media;
  final double? latitude;
  final double? longitude;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasMedia => media != null;
  bool get hasLocation => latitude != null && longitude != null;
  bool get canSubmit => hasText && hasMedia && hasLocation;

  CreateMomentDraft copyWith({
    String? text,
    String? emotion,
    PickedMomentMedia? media,
    double? latitude,
    double? longitude,
    bool clearMedia = false,
  }) {
    return CreateMomentDraft(
      text: text ?? this.text,
      emotion: emotion ?? this.emotion,
      media: clearMedia ? null : media ?? this.media,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
```

`canSaveDraft` теперь заменяем на `canSubmit`, потому что глава 10 публикует moment, а не просто сохраняет черновик.

### Шаг 5. Добавить `setLocation` в draft controller

Файл:

```text
lib/src/features/moments/presentation/controllers/create_moment_draft_controller.dart
```

Добавь method:

```dart
void setLocation({
  required double latitude,
  required double longitude,
}) {
  state = state.copyWith(latitude: latitude, longitude: longitude);
}
```

Остальные методы `updateText`, `updateEmotion`, `clearMedia` остаются.

### Шаг 6. Принять coordinates в `CreateMomentScreen`

Файл:

```text
lib/src/features/moments/presentation/screens/create_moment_screen.dart
```

Constructor:

```dart
class CreateMomentScreen extends ConsumerStatefulWidget {
  const CreateMomentScreen({
    required this.latitude,
    required this.longitude,
    super.key,
  });

  final double latitude;
  final double longitude;
}
```

В `initState()` после создания text controllers:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  ref.read(createMomentDraftControllerProvider.notifier)
    ..setLocation(latitude: widget.latitude, longitude: widget.longitude)
    ..restoreLostData();
});
```

Почему через post-frame: мы уже используем post-frame для lost data. Заодно выставляем location после первого build. Можно поставить location и до post-frame через `ref.read(...)`, но единый блок проще читать.

### Шаг 7. Создать `UploadedMomentMedia`

Файл:

```text
lib/src/features/moments/domain/entities/uploaded_moment_media.dart
```

Код:

```dart
class UploadedMomentMedia {
  const UploadedMomentMedia({
    required this.path,
    required this.publicUrl,
    required this.mediaType,
  });

  final String path;
  final String publicUrl;
  final String mediaType;
}
```

`path` нужен для rollback delete. `publicUrl` сохраняем в `moments.media_url`.

### Шаг 8. Создать `CreateMomentCommand`

Файл:

```text
lib/src/features/moments/domain/entities/create_moment_command.dart
```

Код:

```dart
class CreateMomentCommand {
  const CreateMomentCommand({
    required this.authorId,
    required this.latitude,
    required this.longitude,
    required this.text,
    required this.mediaUrl,
    required this.mediaType,
    this.emotion,
  });

  final String authorId;
  final double latitude;
  final double longitude;
  final String text;
  final String? emotion;
  final String mediaUrl;
  final String mediaType;
}
```

Почему command не содержит local file path: к моменту insert-а файл уже загружен в Storage, и database row должен знать только URL/type.

### Шаг 9. Создать storage interface

Файл:

```text
lib/src/features/moments/data/services/moment_media_storage.dart
```

Код:

```dart
import '../../domain/entities/picked_moment_media.dart';
import '../../domain/entities/uploaded_moment_media.dart';

abstract interface class MomentMediaStorage {
  Future<UploadedMomentMedia> upload({
    required String authorId,
    required PickedMomentMedia media,
  });

  Future<void> remove(String path);
}
```

Возвращаем `UploadedMomentMedia`, а не просто URL, потому что rollback должен знать object path.

### Шаг 10. Реализовать Supabase storage service

Файл:

```text
lib/src/features/moments/data/services/supabase_moment_media_storage.dart
```

Код:

```dart
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/picked_moment_media.dart';
import '../../domain/entities/uploaded_moment_media.dart';
import 'moment_media_storage.dart';

class SupabaseMomentMediaStorage implements MomentMediaStorage {
  const SupabaseMomentMediaStorage(this._client);

  static const bucket = 'moment-media';

  final SupabaseClient _client;

  @override
  Future<UploadedMomentMedia> upload({
    required String authorId,
    required PickedMomentMedia media,
  }) async {
    final path = _buildPath(authorId: authorId, media: media);

    await _client.storage.from(bucket).upload(
          path,
          File(media.path),
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: media.mimeType,
          ),
        );

    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);

    return UploadedMomentMedia(
      path: path,
      publicUrl: publicUrl,
      mediaType: media.storageMediaType,
    );
  }

  @override
  Future<void> remove(String path) async {
    await _client.storage.from(bucket).remove([path]);
  }

  String _buildPath({
    required String authorId,
    required PickedMomentMedia media,
  }) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final extension = _extensionFor(media);

    return '$authorId/$timestamp$extension';
  }

  String _extensionFor(PickedMomentMedia media) {
    final dotIndex = media.name.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < media.name.length - 1) {
      return media.name.substring(dotIndex).toLowerCase();
    }

    return switch (media.kind) {
      MomentMediaKind.image => '.jpg',
      MomentMediaKind.video => '.mp4',
    };
  }
}
```

Почему `upsert: false`: если path случайно совпал, мы хотим ошибку, а не тихую замену чужого файла.

Почему path начинается с `authorId`: это связывает client path с storage policy.

### Шаг 11. Добавить storage provider

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

Добавь imports:

```dart
import '../../../../core/backend/supabase_client_provider.dart';
import '../../data/services/moment_media_storage.dart';
import '../../data/services/supabase_moment_media_storage.dart';
```

Provider:

```dart
final momentMediaStorageProvider = Provider<MomentMediaStorage>((ref) {
  return SupabaseMomentMediaStorage(ref.watch(supabaseClientProvider));
});
```

Можно держать provider рядом с `momentsRepositoryProvider`, потому что оба относятся к moments feature data access.

### Шаг 12. Расширить repository interface

Файл:

```text
lib/src/features/moments/domain/repositories/moments_repository.dart
```

Добавь import:

```dart
import '../entities/create_moment_command.dart';
```

Interface:

```dart
abstract interface class MomentsRepository {
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  });

  Future<Moment> fetchMomentById(String id);

  Future<Moment> createMoment(CreateMomentCommand command);
}
```

### Шаг 13. Реализовать insert в Supabase repository

Файл:

```text
lib/src/features/moments/data/repositories/supabase_moments_repository.dart
```

Добавь import:

```dart
import '../../domain/entities/create_moment_command.dart';
```

Метод:

```dart
@override
Future<Moment> createMoment(CreateMomentCommand command) async {
  final response = await _client
      .from('moments')
      .insert({
        'author_id': command.authorId,
        'latitude': command.latitude,
        'longitude': command.longitude,
        'text': command.text.trim(),
        'emotion': _nullableTrim(command.emotion),
        'media_url': command.mediaUrl,
        'media_type': command.mediaType,
      })
      .select('''
        id,
        author_id,
        latitude,
        longitude,
        text,
        emotion,
        media_url,
        media_type,
        created_at,
        profiles(display_name, avatar_url)
      ''')
      .single();

  return MomentDto.fromDetailsJson(response).toDomain();
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}
```

Почему `.select().single()`: после insert нам нужен созданный `Moment`, чтобы можно было открыть details или проверить результат в tests.

### Шаг 14. Создать save state

Файл:

```text
lib/src/features/moments/presentation/controllers/create_moment_save_controller.dart
```

Начни с state:

```dart
import '../../domain/entities/moment.dart';

enum CreateMomentSaveStep {
  idle,
  uploadingMedia,
  savingMoment,
  success,
  failure,
}

class CreateMomentSaveState {
  const CreateMomentSaveState({
    this.step = CreateMomentSaveStep.idle,
    this.createdMoment,
    this.error,
  });

  final CreateMomentSaveStep step;
  final Moment? createdMoment;
  final Object? error;

  bool get isSubmitting {
    return step == CreateMomentSaveStep.uploadingMedia ||
        step == CreateMomentSaveStep.savingMoment;
  }

  double? get progress {
    return switch (step) {
      CreateMomentSaveStep.uploadingMedia => 0.45,
      CreateMomentSaveStep.savingMoment => 0.85,
      CreateMomentSaveStep.success => 1,
      _ => null,
    };
  }
}
```

Почему `progress` nullable: когда операция idle/failure, progress bar не нужен.

### Шаг 15. Реализовать save controller

В том же файле:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../domain/entities/create_moment_command.dart';
import '../../domain/entities/uploaded_moment_media.dart';
import 'create_moment_draft_controller.dart';
import 'moments_providers.dart';

final createMomentSaveControllerProvider =
    NotifierProvider<CreateMomentSaveController, CreateMomentSaveState>(
  CreateMomentSaveController.new,
);

class CreateMomentSaveController extends Notifier<CreateMomentSaveState> {
  @override
  CreateMomentSaveState build() {
    return const CreateMomentSaveState();
  }

  Future<Moment?> submit() async {
    final draft = ref.read(createMomentDraftControllerProvider);
    final media = draft.media;
    final latitude = draft.latitude;
    final longitude = draft.longitude;
    final currentUser = ref.read(currentUserProvider).maybeWhen(
          data: (user) => user,
          orElse: () => null,
        );

    if (media == null ||
        latitude == null ||
        longitude == null ||
        !draft.hasText ||
        currentUser == null) {
      state = const CreateMomentSaveState(step: CreateMomentSaveStep.failure);
      return null;
    }

    UploadedMomentMedia? uploadedMedia;

    try {
      state = const CreateMomentSaveState(
        step: CreateMomentSaveStep.uploadingMedia,
      );

      uploadedMedia = await ref.read(momentMediaStorageProvider).upload(
            authorId: currentUser.id,
            media: media,
          );

      state = const CreateMomentSaveState(
        step: CreateMomentSaveStep.savingMoment,
      );

      final moment = await ref.read(momentsRepositoryProvider).createMoment(
            CreateMomentCommand(
              authorId: currentUser.id,
              latitude: latitude,
              longitude: longitude,
              text: draft.text,
              emotion: draft.emotion,
              mediaUrl: uploadedMedia.publicUrl,
              mediaType: uploadedMedia.mediaType,
            ),
          );

      ref.invalidate(nearbyMomentsProvider);
      ref.read(createMomentDraftControllerProvider.notifier).reset();

      state = CreateMomentSaveState(
        step: CreateMomentSaveStep.success,
        createdMoment: moment,
      );

      return moment;
    } catch (error) {
      if (uploadedMedia != null) {
        await ref.read(momentMediaStorageProvider).remove(uploadedMedia.path);
      }

      state = CreateMomentSaveState(
        step: CreateMomentSaveStep.failure,
        error: error,
      );

      return null;
    }
  }
}
```

Почему controller делает orchestration:

- он знает текущего user-а;
- он знает draft;
- он управляет UI state/progress;
- он может вызвать storage rollback, если repository insert упал.

UI по-прежнему не знает про Supabase.

### Шаг 16. Обновить `CreateMomentScreen`

Файл:

```text
lib/src/features/moments/presentation/screens/create_moment_screen.dart
```

Imports:

```dart
import '../controllers/create_moment_save_controller.dart';
```

В `build`:

```dart
final draft = ref.watch(createMomentDraftControllerProvider);
final saveState = ref.watch(createMomentSaveControllerProvider);
```

AppBar action:

```dart
TextButton(
  onPressed: saveState.isSubmitting ? null : () => _publish(context),
  child: Text(context.l10n.publishMoment),
),
```

Над `ListView` можно оставить текущий layout, но добавь progress первым child:

```dart
if (saveState.isSubmitting) ...[
  LinearProgressIndicator(value: saveState.progress),
  const SizedBox(height: AppSpacing.md),
],
```

Под progress добавь stage label:

```dart
if (saveState.step == CreateMomentSaveStep.uploadingMedia)
  Text(context.l10n.createMomentUploadingMedia),
if (saveState.step == CreateMomentSaveStep.savingMoment)
  Text(context.l10n.createMomentSavingMoment),
```

Метод `_saveDraft` замени на `_publish`:

```dart
Future<void> _publish(BuildContext context) async {
  final isFormValid = _formKey.currentState?.validate() ?? false;
  final draft = ref.read(createMomentDraftControllerProvider);

  if (!isFormValid || !draft.canSubmit) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.createMomentDraftInvalid)),
    );
    return;
  }

  final moment = await ref
      .read(createMomentSaveControllerProvider.notifier)
      .submit();

  if (!context.mounted) {
    return;
  }

  if (moment == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.createMomentSaveError)),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.createMomentSaved)),
  );
  context.pop();
}
```

Обрати внимание: после `await` есть `context.mounted`.

### Шаг 17. Обновить локализацию

Файлы:

```text
lib/l10n/app_en.arb
lib/l10n/app_ru.arb
lib/l10n/app_es.arb
```

EN:

```json
"publishMoment": "Publish",
"createMomentUploadingMedia": "Uploading media...",
"createMomentSavingMoment": "Saving moment...",
"createMomentSaved": "Moment published.",
"createMomentSaveError": "Could not publish this moment."
```

RU:

```json
"publishMoment": "Опубликовать",
"createMomentUploadingMedia": "Загружаем медиа...",
"createMomentSavingMoment": "Сохраняем момент...",
"createMomentSaved": "Момент опубликован.",
"createMomentSaveError": "Не удалось опубликовать этот момент."
```

ES:

```json
"publishMoment": "Publicar",
"createMomentUploadingMedia": "Subiendo medio...",
"createMomentSavingMoment": "Guardando momento...",
"createMomentSaved": "Momento publicado.",
"createMomentSaveError": "No se pudo publicar este momento."
```

После ARB:

```bash
flutter gen-l10n
```

Старый `saveDraft` можно оставить, если он еще используется в tests или тексте. Но на экране теперь должна быть кнопка `Publish`.

### Шаг 18. Обновить widget tests

Тест validation теперь нажимает `Publish`:

```dart
await tester.tap(find.text('Publish'));
```

И ожидает прежние validation strings:

```dart
expect(find.text('Add a short description.'), findsOneWidget);
expect(find.text('Add media and a description first.'), findsOneWidget);
```

Тест открытия create screen может остаться:

```dart
expect(find.text('Create moment'), findsOneWidget);
expect(find.text('What happened here?'), findsOneWidget);
expect(find.text('Add a photo or video'), findsOneWidget);
```

Почему не тестируем реальный upload в widget test: storage upload ходит в сеть и файловую систему. Для widget test достаточно route/form. Save controller лучше покрыть unit-style test с fake providers.

### Шаг 19. Добавить controller test с rollback

Файл:

```text
test/create_moment_save_controller_test.dart
```

Идея теста:

- fake storage upload возвращает `UploadedMomentMedia`;
- fake repository throws на `createMoment`;
- controller должен вызвать `storage.remove(uploaded.path)`;
- state должен стать failure.

Минимальный пример fake storage:

```dart
class FakeMomentMediaStorage implements MomentMediaStorage {
  String? removedPath;

  @override
  Future<UploadedMomentMedia> upload({
    required String authorId,
    required PickedMomentMedia media,
  }) async {
    return const UploadedMomentMedia(
      path: 'user-id/test.jpg',
      publicUrl: 'https://example.com/test.jpg',
      mediaType: 'image',
    );
  }

  @override
  Future<void> remove(String path) async {
    removedPath = path;
  }
}
```

В fake repository можно реализовать только нужный метод:

```dart
class ThrowingMomentsRepository implements MomentsRepository {
  @override
  Future<Moment> createMoment(CreateMomentCommand command) {
    throw StateError('insert failed');
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    throw UnimplementedError();
  }
}
```

Этот тест важнее, чем проверка успешного snackbar-а: rollback - самая рискованная часть главы.

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
2. Открыть карту.
3. Подвинуть карту в место, где хочешь создать moment.
4. Нажать create moment.
5. Выбрать фото из gallery.
6. Ввести description.
7. Нажать `Publish`.
8. Увидеть progress stages.
9. Вернуться на карту.
10. Убедиться, что moment появился рядом с текущим center.
11. Открыть details и проверить media.

Supabase Dashboard проверка:

1. Storage -> `moment-media`.
2. Убедиться, что файл лежит в folder с твоим user id.
3. Table editor -> `moments`.
4. Проверить row: `author_id`, `latitude`, `longitude`, `media_url`, `media_type`.

## Частые ошибки

### Ошибка: upload падает с RLS policy

Проверь:

- migration storage policies применена;
- object path начинается с `auth.uid()`;
- пользователь authenticated;
- bucket id ровно `moment-media`.

### Ошибка: public URL есть, но картинка не открывается

Проверь, что bucket public:

```sql
select id, public
from storage.buckets
where id = 'moment-media';
```

Для этой главы bucket public intentionally. Private media можно сделать позже через signed URLs.

### Ошибка: после failed insert файл остается в bucket

Проверь rollback:

```dart
if (uploadedMedia != null) {
  await ref.read(momentMediaStorageProvider).remove(uploadedMedia.path);
}
```

И проверь storage policy для delete + select.

### Ошибка: новый moment создается в Buenos Aires, хотя карту двигали

Причина: create route не получает текущий `_center`.

Проверь:

```dart
AppRoutePaths.createMoment(
  latitude: _center.latitude,
  longitude: _center.longitude,
)
```

### Ошибка: route `/moments/new` снова открывает details

Route `/moments/new` должен стоять до `/moments/:momentId`.

### Ошибка: тест запускает настоящий Supabase upload

Причина: не override-нуты `momentMediaStorageProvider` или `momentsRepositoryProvider`.

Widget tests не должны ходить в сеть.

### Ошибка: `context.pop()` вызывается после await без mounted check

Правильно:

```dart
final moment = await ref.read(...).submit();
if (!context.mounted) {
  return;
}
context.pop();
```

## Definition of Done

- Storage policies migration добавлена и применена.
- `/moments/new` получает `lat/lng` query parameters.
- Create button передает текущий `_center`.
- `CreateMomentDraft` хранит `latitude` и `longitude`.
- `CreateMomentScreen` принимает coordinates и передает их в draft controller.
- `UploadedMomentMedia` создан.
- `CreateMomentCommand` создан.
- `MomentMediaStorage` и `SupabaseMomentMediaStorage` созданы.
- Storage upload использует `FileOptions(cacheControl, upsert: false, contentType)`.
- Public URL получается через `getPublicUrl`.
- `MomentsRepository.createMoment` добавлен.
- Supabase repository делает `.insert(...).select(...).single()`.
- Save controller показывает upload/save stages.
- Если insert упал после upload, controller удаляет файл через `remove`.
- После успеха draft сбрасывается, nearby moments invalidated.
- UI показывает `Publish`, progress и save error.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная Android-проверка upload/save выполнена.

## Что я буду проверять в ревью

- Не используется старый Supabase `.execute()` API.
- UI не обращается к Supabase напрямую.
- Storage service и moments repository не смешаны без причины.
- Object path начинается с user id и совпадает с storage policies.
- Есть rollback удаления файла при failed insert.
- `context.mounted` проверяется после async save.
- Tests используют fake storage/repository.
- Route `/moments/new` стоит раньше `/moments/:momentId`.
- После save карта обновляется через provider invalidation.

Когда закончишь, напиши:

```text
Глава 10 готова, проверь код.
```
