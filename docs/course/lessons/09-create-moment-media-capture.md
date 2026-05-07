# 09 Create Moment: Media Capture

Статус: done.

## Источники

Эта глава опирается на актуальные API пакетов и platform behavior:

- `image_picker` 1.2.x: используем `ImagePicker.pickImage`, `ImagePicker.pickVideo`, `XFile`, `retrieveLostData()`. Package page: https://pub.dev/packages/image_picker
- `permission_handler` 12.x: используем `Permission.camera`, не используем старые storage permissions.
- `go_router` 17.2.x: используем `context.push(...)` и route constants.
- `flutter_riverpod` 3.3.x: используем `Provider`, `NotifierProvider`, `Notifier`.

В примерах не используются старые API:

- не используем `getImage`;
- не используем `getVideo`;
- не используем `PickedFile`;
- не используем `Permission.storage`;
- не используем Android `READ_EXTERNAL_STORAGE` как основную стратегию gallery picker;
- не используем `withOpacity`.

## Что строим в этой главе

В главе 8 пользователь уже может открыть details screen конкретного момента. Но пока приложение только читает seed moments из Supabase.

В этой главе добавим первый кусок create flow:

- route `/moments/new`;
- кнопку создания момента на `MapScreen`;
- экран `CreateMomentScreen`;
- выбор фото из gallery;
- съемку фото с camera;
- выбор видео из gallery;
- запись видео с camera;
- локальный draft state через Riverpod;
- восстановление потерянного media pick result на Android через `retrieveLostData()`;
- form validation: media + text обязательны;
- preview выбранного media;
- widget tests без запуска native picker.

Важно: в этой главе мы еще не загружаем media в Supabase Storage и не создаем row в `moments`. Это будет глава 10. Сейчас цель - научиться безопасно получать локальный файл и держать черновик в state.

После главы пользователь сможет:

1. Нажать кнопку создания на карте.
2. Открыть экран нового момента.
3. Выбрать или снять фото/видео.
4. Написать текст и emotion.
5. Сохранить черновик локально в Riverpod state.
6. Вернуться на карту.

## Почему это важно

Media capture - одна из границ между Flutter UI и платформой.

Обычный TextField живет целиком во Flutter. Но camera/gallery flow работает иначе:

```text
Flutter screen
  -> image_picker plugin
  -> Android/iOS native picker or camera app
  -> temporary local file
  -> Flutter gets XFile
  -> app stores draft metadata in state
```

Из-за этого появляются новые риски:

- пользователь может отменить picker;
- Android может уничтожить `MainActivity`, пока открыт picker;
- camera permission может быть denied;
- local file path еще не значит, что файл уже загружен в backend;
- UI нельзя привязывать напрямую к plugin API, иначе тесты станут хрупкими.

Поэтому мы построим маленькую прослойку:

```text
CreateMomentScreen
  -> CreateMomentDraftController
  -> MomentMediaPicker interface
  -> ImagePickerMomentMediaPicker
  -> image_picker plugin
```

Это похоже на Android-подход:

```text
Fragment
  -> ViewModel
  -> MediaPicker abstraction / ActivityResultContract
  -> Uri/File draft
```

Во Flutter роль ViewModel здесь выполняет Riverpod `Notifier`.

## Словарь главы

`XFile` - файл, который возвращает `image_picker`. Это не `dart:io File`, а кроссплатформенная обертка с `path`, `name`, `mimeType`.

`Draft` - локальный черновик создания момента. Он еще не сохранен в Supabase.

`Media kind` - тип выбранного media: image или video.

`ImageSource.camera` - источник camera.

`ImageSource.gallery` - источник gallery/system picker.

`retrieveLostData()` - метод `image_picker` для Android-сценария, когда приложение было уничтожено во время picker flow.

`Notifier` - Riverpod controller, который хранит mutable state и exposes команды.

`Provider override` - подмена provider-а в тесте, чтобы вместо native plugin использовать fake.

## 1. Как будет устроен create flow

Сначала смотрим всю цепочку, чтобы код не казался набором отдельных классов.

```text
MapScreen AppBar add button
  -> context.push('/moments/new')
  -> CreateMomentScreen
  -> user taps photo/video action
  -> CreateMomentDraftController calls MomentMediaPicker
  -> ImagePickerMomentMediaPicker calls image_picker
  -> XFile is converted to PickedMomentMedia
  -> draft state updates
  -> UI shows media preview
  -> user enters text/emotion
  -> Save draft validates state
  -> draft stays in Riverpod
  -> user returns to map
```

Почему сохраняем draft, а не сразу вставляем fake marker на карту:

- глава 10 будет делать настоящий upload/save;
- fake marker сейчас усложнит data consistency;
- карта уже показывает данные из Supabase, не локальные черновики;
- нам важно отделить "выбрать файл" от "загрузить файл".

## 2. Почему не вызываем `ImagePicker` прямо из widget-а

Можно написать прямо в button:

```dart
final picker = ImagePicker();
final file = await picker.pickImage(source: ImageSource.gallery);
```

Для маленького demo это работает. Для курса и тестируемого приложения лучше так не делать:

- widget начинает знать про plugin;
- widget test может случайно вызвать native channel;
- сложнее обработать lost data;
- сложнее переиспользовать logic для фото и видео;
- сложнее подготовить upload в главе 10.

Поэтому делаем интерфейс:

```dart
abstract interface class MomentMediaPicker {
  Future<PickedMomentMedia?> pickImageFromGallery();
  Future<PickedMomentMedia?> takePhoto();
  Future<PickedMomentMedia?> pickVideoFromGallery();
  Future<PickedMomentMedia?> recordVideo();
  Future<PickedMomentMedia?> retrieveLostData();
}
```

UI будет работать с controller-ом, controller - с интерфейсом, production implementation - с `image_picker`.

## 3. Permissions: что просим, а что не просим

В этой главе есть два разных действия:

```text
Gallery picker -> system picker
Camera capture -> camera permission
```

Для gallery не добавляем старые Android storage permissions. На современных Android storage permissions стали сложнее, а `image_picker` использует системные picker-ы. В учебном MVP не надо заранее просить `Permission.storage`.

Для camera capture добавляем camera permission:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

И для iOS добавляем usage descriptions:

```xml
<key>NSCameraUsageDescription</key>
<string>Geo Moments uses the camera to capture moments.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Geo Moments lets you choose media for a moment.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Geo Moments uses the microphone when recording videos.</string>
```

Почему нужен microphone description: video recording через camera может использовать microphone. Без этого iOS может завершить flow или показать некорректный permission behavior.

## 4. Android lost data flow

На Android picker/camera может открыть другую Activity. Если системе не хватает памяти, она может уничтожить `MainActivity` приложения. Когда пользователь вернется, Flutter screen создастся заново, а результат picker-а надо восстановить.

`image_picker` для этого дает:

```dart
final response = await picker.retrieveLostData();
```

В этой главе `CreateMomentScreen` вызовет восстановление один раз после первого build:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  ref.read(createMomentDraftControllerProvider.notifier).restoreLostData();
});
```

Это не значит, что каждый screen должен так делать. Это нужно именно там, где пользователь работает с image picker flow.

## Целевая структура после главы

```text
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
          services/
            image_picker_moment_media_picker.dart
            moment_media_picker.dart
        domain/
          entities/
            create_moment_draft.dart
            picked_moment_media.dart
        presentation/
          controllers/
            create_moment_draft_controller.dart
          screens/
            create_moment_screen.dart
          widgets/
            create_moment_media_preview.dart
```

В этой главе media picker лежит в `data/services`, потому что это plugin/data-source boundary. Draft entity лежит в `domain/entities`, потому что он не должен знать про Flutter widgets или `image_picker`.

## Практика

### Шаг 1. Добавить dependency `image_picker`

Файл:

```text
pubspec.yaml
```

Добавь:

```yaml
dependencies:
  image_picker: ^1.2.2
```

Затем:

```bash
flutter pub get
```

Проверка:

```bash
flutter pub deps | findstr image_picker
```

На macOS/Linux команда будет другая:

```bash
flutter pub deps | grep image_picker
```

Главное: в коде дальше используем `pickImage`, `pickVideo`, `XFile`.

### Шаг 2. Добавить Android camera permission

Файл:

```text
android/app/src/main/AndroidManifest.xml
```

Рядом с уже добавленными location permissions добавь:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

Почему `required="false"`: приложение может работать и без camera hardware, потому что пользователь может выбрать media из gallery.

Не добавляй здесь старые storage permissions как основной путь. Gallery flow в этом уроке идет через `image_picker` и системный picker.

### Шаг 3. Добавить iOS usage descriptions

Файл:

```text
ios/Runner/Info.plist
```

Внутри `<dict>` добавь:

```xml
<key>NSCameraUsageDescription</key>
<string>Geo Moments uses the camera to capture moments.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Geo Moments lets you choose media for a moment.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Geo Moments uses the microphone when recording videos.</string>
```

На Windows ты не соберешь iOS, но файл должен быть готов для будущей проверки на macOS.

### Шаг 4. Создать entity `PickedMomentMedia`

Файл:

```text
lib/src/features/moments/domain/entities/picked_moment_media.dart
```

Код:

```dart
enum MomentMediaKind {
  image,
  video,
}

class PickedMomentMedia {
  const PickedMomentMedia({
    required this.kind,
    required this.path,
    required this.name,
    this.mimeType,
  });

  final MomentMediaKind kind;
  final String path;
  final String name;
  final String? mimeType;

  String get storageMediaType {
    return switch (kind) {
      MomentMediaKind.image => 'image',
      MomentMediaKind.video => 'video',
    };
  }
}
```

Почему не используем `XFile` в domain entity:

- `XFile` - деталь plugin-а;
- domain draft должен хранить простые данные;
- upload layer в главе 10 сможет читать `path` и `mimeType`.

### Шаг 5. Создать entity `CreateMomentDraft`

Файл:

```text
lib/src/features/moments/domain/entities/create_moment_draft.dart
```

Код:

```dart
import 'picked_moment_media.dart';

class CreateMomentDraft {
  const CreateMomentDraft({
    this.text = '',
    this.emotion = '',
    this.media,
  });

  final String text;
  final String emotion;
  final PickedMomentMedia? media;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasMedia => media != null;
  bool get canSaveDraft => hasText && hasMedia;

  CreateMomentDraft copyWith({
    String? text,
    String? emotion,
    PickedMomentMedia? media,
    bool clearMedia = false,
  }) {
    return CreateMomentDraft(
      text: text ?? this.text,
      emotion: emotion ?? this.emotion,
      media: clearMedia ? null : media ?? this.media,
    );
  }
}
```

Почему `emotion` пока обычная строка: emotion taxonomy можно сделать позже. Сейчас важнее пройти полный media capture flow.

### Шаг 6. Создать media picker interface

Файл:

```text
lib/src/features/moments/data/services/moment_media_picker.dart
```

Код:

```dart
import '../../domain/entities/picked_moment_media.dart';

abstract interface class MomentMediaPicker {
  Future<PickedMomentMedia?> pickImageFromGallery();
  Future<PickedMomentMedia?> takePhoto();
  Future<PickedMomentMedia?> pickVideoFromGallery();
  Future<PickedMomentMedia?> recordVideo();
  Future<PickedMomentMedia?> retrieveLostData();
}
```

Возвращаем nullable result, потому что пользователь может закрыть picker без выбора файла.

### Шаг 7. Реализовать picker через `image_picker`

Файл:

```text
lib/src/features/moments/data/services/image_picker_moment_media_picker.dart
```

Код:

```dart
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/picked_moment_media.dart';
import 'moment_media_picker.dart';

class ImagePickerMomentMediaPicker implements MomentMediaPicker {
  ImagePickerMomentMediaPicker(this._picker);

  final ImagePicker _picker;

  @override
  Future<PickedMomentMedia?> pickImageFromGallery() {
    return _pick(
      kind: MomentMediaKind.image,
      pick: () => _picker.pickImage(source: ImageSource.gallery),
    );
  }

  @override
  Future<PickedMomentMedia?> takePhoto() {
    return _pick(
      kind: MomentMediaKind.image,
      pick: () => _picker.pickImage(source: ImageSource.camera),
    );
  }

  @override
  Future<PickedMomentMedia?> pickVideoFromGallery() {
    return _pick(
      kind: MomentMediaKind.video,
      pick: () => _picker.pickVideo(source: ImageSource.gallery),
    );
  }

  @override
  Future<PickedMomentMedia?> recordVideo() {
    return _pick(
      kind: MomentMediaKind.video,
      pick: () => _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      ),
    );
  }

  @override
  Future<PickedMomentMedia?> retrieveLostData() async {
    final response = await _picker.retrieveLostData();

    if (response.exception != null) {
      throw response.exception!;
    }

    final files = response.files;
    if (files == null || files.isEmpty) {
      return null;
    }

    final file = files.first;
    return _fromXFile(file, _guessKind(file));
  }

  Future<PickedMomentMedia?> _pick({
    required MomentMediaKind kind,
    required Future<XFile?> Function() pick,
  }) async {
    final file = await pick();
    if (file == null) {
      return null;
    }

    return _fromXFile(file, kind);
  }

  PickedMomentMedia _fromXFile(XFile file, MomentMediaKind kind) {
    return PickedMomentMedia(
      kind: kind,
      path: file.path,
      name: file.name,
      mimeType: file.mimeType,
    );
  }

  MomentMediaKind _guessKind(XFile file) {
    final mimeType = file.mimeType;
    if (mimeType != null && mimeType.startsWith('video/')) {
      return MomentMediaKind.video;
    }

    final name = file.name.toLowerCase();
    if (name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.m4v')) {
      return MomentMediaKind.video;
    }

    return MomentMediaKind.image;
  }
}
```

Почему `retrieveLostData` делает guess: Android lost data response возвращает файлы, но не всегда дает тот же высокий уровень intent, с которого ты стартовал. Для MVP достаточно определить video по MIME/name. Если позже нужна стопроцентная точность, можно хранить last requested picker action отдельно.

### Шаг 8. Создать providers и controller

Файл:

```text
lib/src/features/moments/presentation/controllers/create_moment_draft_controller.dart
```

Код:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/image_picker_moment_media_picker.dart';
import '../../data/services/moment_media_picker.dart';
import '../../domain/entities/create_moment_draft.dart';
import '../../domain/entities/picked_moment_media.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) {
  return ImagePicker();
});

final momentMediaPickerProvider = Provider<MomentMediaPicker>((ref) {
  return ImagePickerMomentMediaPicker(ref.watch(imagePickerProvider));
});

final createMomentDraftControllerProvider =
    NotifierProvider<CreateMomentDraftController, CreateMomentDraft>(
  CreateMomentDraftController.new,
);

class CreateMomentDraftController extends Notifier<CreateMomentDraft> {
  @override
  CreateMomentDraft build() {
    return const CreateMomentDraft();
  }

  void updateText(String value) {
    state = state.copyWith(text: value);
  }

  void updateEmotion(String value) {
    state = state.copyWith(emotion: value);
  }

  void clearMedia() {
    state = state.copyWith(clearMedia: true);
  }

  void reset() {
    state = const CreateMomentDraft();
  }

  Future<void> pickImageFromGallery() {
    return _pickMedia(
      () => ref.read(momentMediaPickerProvider).pickImageFromGallery(),
    );
  }

  Future<void> takePhoto() async {
    final granted = await _ensureCameraPermission();
    if (!granted) {
      return;
    }

    await _pickMedia(
      () => ref.read(momentMediaPickerProvider).takePhoto(),
    );
  }

  Future<void> pickVideoFromGallery() {
    return _pickMedia(
      () => ref.read(momentMediaPickerProvider).pickVideoFromGallery(),
    );
  }

  Future<void> recordVideo() async {
    final granted = await _ensureCameraPermission();
    if (!granted) {
      return;
    }

    await _pickMedia(
      () => ref.read(momentMediaPickerProvider).recordVideo(),
    );
  }

  Future<void> restoreLostData() {
    return _pickMedia(
      () => ref.read(momentMediaPickerProvider).retrieveLostData(),
    );
  }

  Future<void> _pickMedia(
    Future<PickedMomentMedia?> Function() pick,
  ) async {
    final media = await pick();
    if (media == null) {
      return;
    }

    state = state.copyWith(media: media);
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
}
```

Повторение: `Notifier` хранит state и команды. UI не меняет поля draft напрямую, а вызывает методы controller-а.

Почему provider не `autoDispose`: draft должен пережить уход со screen-а в рамках текущей сессии. В главе 10 upload flow сможет прочитать этот draft после возврата.

### Шаг 9. Добавить route helper

Файл:

```text
lib/src/app/router/app_router.dart
```

Импорт:

```dart
import '../../features/moments/presentation/screens/create_moment_screen.dart';
```

В `AppRoutePaths` добавь:

```dart
static const createMoment = '/moments/new';
```

В routes добавь перед `momentDetailsPattern`:

```dart
GoRoute(
  path: AppRoutePaths.createMoment,
  builder: (context, state) => const CreateMomentScreen(),
),
```

Почему перед details route: `/moments/new` и `/moments/:momentId` могут конфликтовать концептуально. `go_router` обычно матчится по точному path, но читателю проще видеть static route перед dynamic route.

### Шаг 10. Добавить кнопку создания на карту

Файл:

```text
lib/src/features/map/presentation/screens/map_screen.dart
```

В `AppBar.actions` добавь кнопку перед location:

```dart
IconButton(
  tooltip: context.l10n.createMomentTooltip,
  onPressed: () => context.push(AppRoutePaths.createMoment),
  icon: const Icon(Icons.add_location_alt_outlined),
),
```

Итоговый порядок actions:

```text
create moment
enable location
settings
```

Почему create button в `AppBar`: сейчас map является главным рабочим экраном. Floating action button тоже допустим, но на карте он может перекрывать controls и markers. Для текущего layout `AppBar` проще и стабильнее.

### Шаг 11. Создать media preview widget

Файл:

```text
lib/src/features/moments/presentation/widgets/create_moment_media_preview.dart
```

Код:

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/picked_moment_media.dart';

class CreateMomentMediaPreview extends StatelessWidget {
  const CreateMomentMediaPreview({
    required this.media,
    required this.onClear,
    super.key,
  });

  final PickedMomentMedia? media;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (media == null)
                _EmptyPreview(label: context.l10n.createMomentMediaEmpty)
              else if (media!.kind == MomentMediaKind.image)
                Image.file(
                  File(media!.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _EmptyPreview(label: context.l10n.createMomentMediaError);
                  },
                )
              else
                _VideoPreview(fileName: media!.name),
              if (media != null)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: IconButton.filledTonal(
                    tooltip: context.l10n.removeMedia,
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: AppSpacing.xl,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

Почему video пока не проигрываем: playback добавляет controller lifecycle, buffering, dispose и error states. В главе 9 нам нужен capture/draft flow. Реальный video player можно добавить позже, когда появится media upload и details playback.

### Шаг 12. Создать `CreateMomentScreen`

Файл:

```text
lib/src/features/moments/presentation/screens/create_moment_screen.dart
```

Код:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_breakpoints.dart';
import '../../../../core/ui/app_spacing.dart';
import '../controllers/create_moment_draft_controller.dart';
import '../widgets/create_moment_media_preview.dart';

class CreateMomentScreen extends ConsumerStatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  ConsumerState<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends ConsumerState<CreateMomentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textController;
  late final TextEditingController _emotionController;

  @override
  void initState() {
    super.initState();

    final draft = ref.read(createMomentDraftControllerProvider);
    _textController = TextEditingController(text: draft.text);
    _emotionController = TextEditingController(text: draft.emotion);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createMomentDraftControllerProvider.notifier).restoreLostData();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _emotionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(createMomentDraftControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.createMomentTitle),
        actions: [
          TextButton(
            onPressed: () => _saveDraft(context, draft.canSaveDraft),
            child: Text(context.l10n.saveDraft),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = AppBreakpoints.isTabletWidth(constraints.maxWidth);
            final maxWidth = isTablet ? 720.0 : double.infinity;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    CreateMomentMediaPreview(
                      media: draft.media,
                      onClear: () {
                        ref.read(createMomentDraftControllerProvider.notifier).clearMedia();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MediaActions(onError: _showPickError),
                    const SizedBox(height: AppSpacing.lg),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _textController,
                            decoration: InputDecoration(
                              labelText: context.l10n.createMomentTextLabel,
                              border: const OutlineInputBorder(),
                            ),
                            maxLines: 4,
                            maxLength: 280,
                            textInputAction: TextInputAction.newline,
                            onChanged: (value) {
                              ref.read(createMomentDraftControllerProvider.notifier).updateText(value);
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return context.l10n.createMomentTextRequired;
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _emotionController,
                            decoration: InputDecoration(
                              labelText: context.l10n.createMomentEmotionLabel,
                              border: const OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.done,
                            onChanged: (value) {
                              ref.read(createMomentDraftControllerProvider.notifier).updateEmotion(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _saveDraft(BuildContext context, bool canSaveDraft) {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || !canSaveDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createMomentDraftInvalid)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.createMomentDraftSaved)),
    );
    context.pop();
  }

  void _showPickError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.createMomentMediaPickError)),
    );
  }
}

class _MediaActions extends ConsumerWidget {
  const _MediaActions({required this.onError});

  final void Function(BuildContext context) onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createMomentDraftControllerProvider.notifier);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          onPressed: () => _runPicker(context, controller.pickImageFromGallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(context.l10n.pickPhoto),
        ),
        OutlinedButton.icon(
          onPressed: () => _runPicker(context, controller.takePhoto),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(context.l10n.takePhoto),
        ),
        OutlinedButton.icon(
          onPressed: () => _runPicker(context, controller.pickVideoFromGallery),
          icon: const Icon(Icons.video_library_outlined),
          label: Text(context.l10n.pickVideo),
        ),
        OutlinedButton.icon(
          onPressed: () => _runPicker(context, controller.recordVideo),
          icon: const Icon(Icons.videocam_outlined),
          label: Text(context.l10n.recordVideo),
        ),
      ],
    );
  }

  Future<void> _runPicker(
    BuildContext context,
    Future<void> Function() pick,
  ) async {
    try {
      await pick();
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      onError(context);
    }
  }
}
```

Почему здесь `ConsumerStatefulWidget`:

- screen использует `TextEditingController`;
- controller-ы нужно создать один раз и dispose-нуть;
- screen одновременно читает Riverpod state через `ref`;
- поэтому `ConsumerStatefulWidget` подходит лучше, чем `ConsumerWidget`.

Почему `context.mounted` после `await`: picker открывает platform UI, screen мог быть закрыт до возвращения результата. После await нельзя безопасно использовать `BuildContext`, пока не проверили `mounted`.

### Шаг 13. Добавить локализацию

Файлы:

```text
lib/l10n/app_en.arb
lib/l10n/app_ru.arb
lib/l10n/app_es.arb
```

EN:

```json
"createMomentTooltip": "Create moment",
"createMomentTitle": "Create moment",
"saveDraft": "Save draft",
"createMomentMediaEmpty": "Add a photo or video",
"createMomentMediaError": "Could not show this media",
"removeMedia": "Remove media",
"pickPhoto": "Pick photo",
"takePhoto": "Take photo",
"pickVideo": "Pick video",
"recordVideo": "Record video",
"createMomentTextLabel": "What happened here?",
"createMomentEmotionLabel": "Emotion",
"createMomentTextRequired": "Add a short description.",
"createMomentDraftInvalid": "Add media and a description first.",
"createMomentDraftSaved": "Draft saved.",
"createMomentMediaPickError": "Could not pick media."
```

RU:

```json
"createMomentTooltip": "Создать момент",
"createMomentTitle": "Создать момент",
"saveDraft": "Сохранить черновик",
"createMomentMediaEmpty": "Добавь фото или видео",
"createMomentMediaError": "Не удалось показать это медиа",
"removeMedia": "Удалить медиа",
"pickPhoto": "Выбрать фото",
"takePhoto": "Снять фото",
"pickVideo": "Выбрать видео",
"recordVideo": "Записать видео",
"createMomentTextLabel": "Что здесь произошло?",
"createMomentEmotionLabel": "Эмоция",
"createMomentTextRequired": "Добавь короткое описание.",
"createMomentDraftInvalid": "Сначала добавь медиа и описание.",
"createMomentDraftSaved": "Черновик сохранен.",
"createMomentMediaPickError": "Не удалось выбрать медиа."
```

ES:

```json
"createMomentTooltip": "Crear momento",
"createMomentTitle": "Crear momento",
"saveDraft": "Guardar borrador",
"createMomentMediaEmpty": "Agrega una foto o video",
"createMomentMediaError": "No se pudo mostrar este medio",
"removeMedia": "Quitar medio",
"pickPhoto": "Elegir foto",
"takePhoto": "Tomar foto",
"pickVideo": "Elegir video",
"recordVideo": "Grabar video",
"createMomentTextLabel": "¿Qué pasó aquí?",
"createMomentEmotionLabel": "Emoción",
"createMomentTextRequired": "Agrega una descripción breve.",
"createMomentDraftInvalid": "Agrega un medio y una descripción primero.",
"createMomentDraftSaved": "Borrador guardado.",
"createMomentMediaPickError": "No se pudo elegir el medio."
```

После ARB:

```bash
flutter gen-l10n
```

### Шаг 14. Обновить widget tests

Нам нужно проверить route и форму, но не запускать native picker.

В `test/widget_test.dart` текущий `buildTestApp()` уже подменяет auth, map и moments. Добавь тест:

```dart
testWidgets('opens create moment screen', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Create moment'));
  await tester.pumpAndSettle();

  expect(find.text('Create moment'), findsOneWidget);
  expect(find.text('What happened here?'), findsOneWidget);
  expect(find.text('Add a photo or video'), findsOneWidget);
});
```

Добавь тест validation:

```dart
testWidgets('requires media and text before saving draft', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Create moment'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Save draft'));
  await tester.pumpAndSettle();

  expect(find.text('Add a short description.'), findsOneWidget);
  expect(find.text('Add media and a description first.'), findsOneWidget);
});
```

Почему не тестируем camera/gallery в widget test: это plugin/platform flow. Его лучше проверять вручную на Android emulator/device. Unit test для controller-а можно добавить позже, когда появится upload behavior.

Если хочешь протестировать picker action без native plugin, подмени `momentMediaPickerProvider` fake-реализацией. Но для этой главы достаточно route + validation.

## Проверка

Команды:

```bash
flutter pub get
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

Ручная проверка Android:

1. Запустить приложение на emulator/device.
2. Войти в приложение, если сессии нет.
3. На карте нажать кнопку create moment.
4. Увидеть экран `Create moment`.
5. Нажать `Pick photo`, выбрать фото, увидеть preview.
6. Нажать remove media, убедиться, что preview очистился.
7. Нажать `Take photo`, разрешить camera permission, снять фото.
8. Ввести description и emotion.
9. Нажать `Save draft`, вернуться на карту.
10. Повторить для `Pick video` или `Record video`, если emulator/device поддерживает camera/video.

iOS:

- проверить `Info.plist` keys;
- полноценную проверку выполнить позже на macOS/iPhone.

## Частые ошибки

### Ошибка: используются `getImage` или `PickedFile`

Причина: найден старый tutorial.

Правильно:

```dart
final file = await picker.pickImage(source: ImageSource.gallery);
```

Тип:

```dart
XFile?
```

### Ошибка: gallery требует storage permission

Не начинай с `Permission.storage`. Для текущего `image_picker` flow gallery должен идти через system picker. Старые storage permissions особенно плохо ложатся на Android 13+.

### Ошибка: camera permission не появляется

Проверь:

- `android.permission.CAMERA` есть в `AndroidManifest.xml`;
- app переустановлен после изменения manifest;
- пользователь не выбрал "Don't ask again";
- emulator/device имеет camera или gallery fallback.

### Ошибка: iOS picker падает

Проверь `Info.plist`:

```xml
NSCameraUsageDescription
NSPhotoLibraryUsageDescription
NSMicrophoneUsageDescription
```

### Ошибка: после picker-а нельзя показать SnackBar

Причина: использовали `BuildContext` после `await` без проверки.

Правильно:

```dart
await pick();
if (!context.mounted) {
  return;
}
```

### Ошибка: widget test пытается открыть native picker

Причина: тест нажал button, который вызывает real `ImagePicker`.

Решение:

- не тестировать plugin flow в widget test;
- или override-нуть `momentMediaPickerProvider` fake implementation.

### Ошибка: draft пропадает после закрытия screen

Проверь, что provider не `autoDispose`:

```dart
NotifierProvider<CreateMomentDraftController, CreateMomentDraft>
```

Для этой главы draft должен жить в памяти до reset/upload.

### Ошибка: видео пытается проигрываться без controller lifecycle

Не добавляй video playback в эту главу. Покажи video placeholder. Реальный player требует отдельного lifecycle-разбора.

## Definition of Done

- `image_picker` добавлен в `pubspec.yaml`.
- Android camera permission и optional camera feature добавлены.
- iOS camera/photo/microphone usage descriptions добавлены.
- `PickedMomentMedia` создан.
- `CreateMomentDraft` создан.
- `MomentMediaPicker` interface создан.
- `ImagePickerMomentMediaPicker` использует `pickImage`, `pickVideo`, `XFile`, `retrieveLostData()`.
- `CreateMomentDraftController` хранит draft state.
- Camera actions проверяют `Permission.camera`.
- Route `/moments/new` добавлен.
- `MapScreen` открывает create screen.
- `CreateMomentScreen` показывает media preview, actions, description и emotion input.
- Save draft валидирует media + text.
- Widget tests проверяют create route и validation.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная Android-проверка photo/video picker выполнена.

## Что я буду проверять в ревью

- Нет deprecated `image_picker` API.
- Нет старого Android storage permission как обязательного пути.
- UI не вызывает `ImagePicker` напрямую.
- Plugin boundary спрятан за `MomentMediaPicker`.
- Domain entities не импортируют Flutter widgets или `image_picker`.
- `BuildContext` не используется после `await` без `context.mounted`.
- Android lost data flow не забыт.
- Draft state остается в Riverpod и не пишет в Supabase раньше главы 10.
- Тексты локализованы EN/RU/ES.
- Tests не запускают native picker.

Когда закончишь, напиши:

```text
Глава 9 готова, проверь код.
```
