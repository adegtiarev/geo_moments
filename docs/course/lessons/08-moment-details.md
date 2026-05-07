# 08 Moment Details

Статус: next.

## Источники

Эта глава опирается на уже подключенные в проекте пакеты и их актуальные API:

- `go_router` 17.2.2: используем `state.pathParameters`, не старые `params`.
- `flutter_riverpod` 3.3.1: используем `Provider`, `FutureProvider.family`, `AsyncValue.when`.
- `intl`: пакет уже доступен через `flutter_localizations`; используем `DateFormat` для человекочитаемой даты.
- Supabase Flutter 2.12.4: используем repository layer, UI не обращается к `SupabaseClient` напрямую.

Главное правило этой главы: сначала строим понятный details flow, а не добавляем likes/comments/media upload раньше времени. Счетчики и media UI подготовим как отображение данных, но реальные likes/comments/upload появятся в следующих главах.

## Что строим в этой главе

В главе 7 marker tap открывает короткий bottom sheet. Это хорошо для быстрого preview, но недостаточно для продукта.

В этой главе добавим:

- route `/moments/:momentId`;
- чтение `momentId` из path parameters;
- repository method `fetchMomentById`;
- `momentDetailsProvider(momentId)`;
- `MomentPreviewCard` для bottom sheet и list items;
- `MomentDetailsScreen`;
- loading/error/not-found states;
- image/video/none media presentation;
- placeholder counters для likes/comments;
- navigation из marker bottom sheet и из nearby list;
- tests, которые не ходят в Supabase и не запускают native Mapbox.

После главы пользователь сможет:

1. Нажать marker.
2. Увидеть preview bottom sheet.
3. Нажать "View details".
4. Открыть отдельный экран details.
5. Вернуться назад к карте без потери navigation stack.

## Почему это важно

Карта отвечает на вопрос "что рядом?". Details screen отвечает на вопрос "что именно произошло?".

Если оставить только bottom sheet:

- сложно показать media;
- сложно добавить comments;
- сложно сделать deep link на конкретный moment;
- невозможно нормально открыть момент из push notification;
- UI будет перегружать карту.

Поэтому в продукте будет два уровня:

```text
Map marker tap
  -> quick preview bottom sheet
  -> full details route /moments/:momentId
```

Это похоже на Android-подход:

```text
Map Fragment
  -> BottomSheetDialogFragment preview
  -> Details Fragment/Activity with route argument
```

Во Flutter с `go_router` route argument обычно приходит через path parameter:

```text
/moments/test-moment-id
```

И экран читает:

```dart
final momentId = state.pathParameters['momentId']!;
```

## Словарь главы

`Route` - описание экрана в router-е.

`Path parameter` - часть URL, например `:momentId` в `/moments/:momentId`.

`Deep link friendly route` - route, который можно восстановить только из URL, без `extra`.

`state.extra` - объект, который можно передать при navigation, но он не надежен для deep links/browser restore. В этой главе не полагаемся на него.

`Details screen` - полноценный экран конкретной сущности.

`Preview card` - компактное представление moment, которое можно использовать в bottom sheet или списке.

`Skeleton` - простой loading placeholder, показывающий структуру будущего контента.

`Not found state` - состояние, когда route валидный, но данных для id нет или пользователь не имеет доступа.

## 1. Как устроен flow после этой главы

Сначала важно увидеть всю цепочку. Мы не начинаем с кода `MomentDetailsScreen`, потому что экран - только конец flow.

Цепочка будет такая:

```text
Mapbox marker tap
  -> MapboxMapPanel находит Moment по annotation customData
  -> MapScreen._showMomentPreview(moment)
  -> MomentPreviewSheet(moment)
  -> user taps "View details"
  -> context.push(AppRoutePaths.momentDetails(moment.id))
  -> GoRouter matches /moments/:momentId
  -> MomentDetailsScreen(momentId)
  -> momentDetailsProvider(momentId)
  -> MomentsRepository.fetchMomentById(momentId)
  -> Supabase select
  -> MomentDetailsContent
```

Список nearby moments будет использовать ту же route:

```text
NearbyMomentsList item tap
  -> context.push(AppRoutePaths.momentDetails(moment.id))
```

Так у marker и list item будет один destination.

## 2. Почему path parameter лучше `extra`

В `go_router` можно сделать так:

```dart
context.push('/moments/${moment.id}', extra: moment);
```

Это удобно, потому что экран может взять `state.extra as Moment`. Но это плохая основа для details route:

- при cold start `extra` может отсутствовать;
- deep link `/moments/abc` не содержит объект `Moment`;
- позже push notification принесет только id;
- тестировать route по id проще.

Поэтому выбираем path parameter:

```dart
GoRoute(
  path: '/moments/:momentId',
  builder: (context, state) {
    final momentId = state.pathParameters['momentId']!;
    return MomentDetailsScreen(momentId: momentId);
  },
)
```

Навигация:

```dart
context.push(AppRoutePaths.momentDetails(moment.id));
```

Helper:

```dart
static String momentDetails(String momentId) {
  return '/moments/${Uri.encodeComponent(momentId)}';
}
```

Почему `Uri.encodeComponent`: route segment должен быть безопасным. UUID обычно безопасен, но helper полезен как привычка.

## 3. Как details screen получает данные

Не передаем весь `Moment` через constructors от карты до details. Передаем только id.

Provider:

```dart
final momentDetailsProvider = FutureProvider.family<Moment, String>((ref, id) {
  return ref.watch(momentsRepositoryProvider).fetchMomentById(id);
});
```

Экран:

```dart
class MomentDetailsScreen extends ConsumerWidget {
  const MomentDetailsScreen({
    required this.momentId,
    super.key,
  });

  final String momentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moment = ref.watch(momentDetailsProvider(momentId));

    return moment.when(
      loading: () => const MomentDetailsSkeleton(),
      error: (_, _) => const MomentDetailsErrorView(),
      data: (moment) => MomentDetailsContent(moment: moment),
    );
  }
}
```

Повторение: `ConsumerWidget` - это `StatelessWidget` с `WidgetRef`. Здесь локального mutable state нет, поэтому `ConsumerStatefulWidget` не нужен.

## 4. Что меняем в repository

Сейчас repository умеет читать nearby moments:

```dart
Future<List<Moment>> fetchNearbyMoments(...)
```

Добавим чтение одной записи:

```dart
Future<Moment> fetchMomentById(String id);
```

Почему не делаем отдельный `MomentDetailsRepository`:

- domain entity та же;
- data source тот же Supabase;
- feature все еще маленькая;
- отдельный repository пока не уменьшит сложность.

## 5. Как читать один moment из Supabase

В главе 6 RPC `nearby_moments` возвращает плоскую строку:

```text
author_display_name
author_avatar_url
```

Для details можно сделать обычный select из `moments` с вложенным profile:

```dart
final response = await _client
    .from('moments')
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
    .eq('id', id)
    .single();
```

Supabase/PostgREST вернет примерно:

```json
{
  "id": "moment-1",
  "author_id": "user-1",
  "latitude": -34.6037,
  "longitude": -58.3816,
  "text": "Great coffee near the city center",
  "emotion": "coffee",
  "media_url": null,
  "media_type": "none",
  "created_at": "2026-05-05T12:00:00Z",
  "profiles": {
    "display_name": "Geo Moments Dev User",
    "avatar_url": null
  }
}
```

Значит DTO должен уметь парсить два формата:

- flat RPC row;
- nested details row.

Не делай парсинг прямо в repository. Лучше добавить factory в `MomentDto`.

## 6. Media presentation без upload complexity

`Moment` уже имеет:

```dart
final String mediaType;
final String? mediaUrl;
```

В details screen показываем:

```text
mediaType == 'image' && mediaUrl != null -> Image.network
mediaType == 'video' && mediaUrl != null -> video placeholder tile
otherwise -> no media placeholder
```

Почему video placeholder, а не `video_player` прямо сейчас:

- video playback потянет lifecycle, controller dispose, buffering states;
- chapter 9-10 будут про media capture/upload;
- сейчас цель details route, state и layout.

Это не обман: UI будет готов к video state, а реальное воспроизведение можно добавить позже, когда media flow появится полностью.

## 7. Loading, error, empty

Details screen должен иметь states:

```text
loading -> skeleton
error -> retry/error view
data -> content
```

Почему для details нет empty state:

- route `/moments/:id` означает "открой конкретный moment";
- если данных нет, это not found/error;
- empty state нужен списку, но не details экрану.

В этой главе можно объединить network error и not found в один дружелюбный экран:

```text
Could not load this moment.
```

Позже можно различать 404, permission denied и network error.

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
          widgets/
            moment_preview_sheet.dart
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
          screens/
            moment_details_screen.dart
          widgets/
            moment_details_content.dart
            moment_details_skeleton.dart
            moment_error_view.dart
            moment_media_view.dart
            moment_preview_card.dart
            nearby_moments_list.dart
```

Файлов получится больше, чем в прошлой главе, но каждый маленький и с понятной ролью.

## Практика

### Шаг 1. Расширить `Moment`

Файл:

```text
lib/src/features/moments/domain/entities/moment.dart
```

Добавь counters:

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
    this.likeCount = 0,
    this.commentCount = 0,
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
  final int likeCount;
  final int commentCount;
}
```

Почему default `0`: likes/comments tables появятся позже. Сейчас existing seed data не содержит счетчиков, но UI already может показать `0`.

### Шаг 2. Обновить DTO

Файл:

```text
lib/src/features/moments/data/dto/moment_dto.dart
```

Добавь поля:

```dart
final int likeCount;
final int commentCount;
```

Constructor:

```dart
this.likeCount = 0,
this.commentCount = 0,
```

В `fromJson` для flat RPC:

```dart
likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
```

Добавь factory для nested Supabase row:

```dart
factory MomentDto.fromDetailsJson(Map<String, dynamic> json) {
  final profile = json['profiles'];
  final profileJson = profile is Map<String, dynamic> ? profile : null;

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
    authorDisplayName: profileJson?['display_name'] as String?,
    authorAvatarUrl: profileJson?['avatar_url'] as String?,
    likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
    commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
  );
}
```

В `toDomain()` передай counters:

```dart
likeCount: likeCount,
commentCount: commentCount,
```

### Шаг 3. Расширить repository interface

Файл:

```text
lib/src/features/moments/domain/repositories/moments_repository.dart
```

Добавь:

```dart
Future<Moment> fetchMomentById(String id);
```

Полный interface:

```dart
abstract interface class MomentsRepository {
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  });

  Future<Moment> fetchMomentById(String id);
}
```

### Шаг 4. Реализовать `fetchMomentById`

Файл:

```text
lib/src/features/moments/data/repositories/supabase_moments_repository.dart
```

Код:

```dart
@override
Future<Moment> fetchMomentById(String id) async {
  final response = await _client
      .from('moments')
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
      .eq('id', id)
      .single();

  return MomentDto.fromDetailsJson(response).toDomain();
}
```

Если analyzer считает `response` слишком dynamic, уточни:

```dart
final json = Map<String, dynamic>.from(response);
return MomentDto.fromDetailsJson(json).toDomain();
```

Почему здесь нет прямого Supabase в UI: repository скрывает формат backend response. Экран получает только `Moment`.

### Шаг 5. Добавить details provider

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

Добавь:

```dart
final momentDetailsProvider = FutureProvider.family<Moment, String>((ref, id) {
  final repository = ref.watch(momentsRepositoryProvider);
  return repository.fetchMomentById(id);
});
```

Теперь у нас два provider-а:

```text
nearbyMomentsProvider(center) -> List<Moment>
momentDetailsProvider(id) -> Moment
```

### Шаг 6. Добавить route helper

Файл:

```text
lib/src/app/router/app_router.dart
```

Обнови `AppRoutePaths`:

```dart
abstract final class AppRoutePaths {
  static const splash = '/splash';
  static const auth = '/auth';
  static const map = '/';
  static const settings = '/settings';
  static const momentDetailsPattern = '/moments/:momentId';

  static String momentDetails(String momentId) {
    return '/moments/${Uri.encodeComponent(momentId)}';
  }
}
```

Почему pattern отдельно от helper:

- `momentDetailsPattern` нужен router-у;
- `momentDetails(id)` нужен UI, чтобы не собирать строки руками.

### Шаг 7. Добавить route

В том же файле импортируй:

```dart
import '../../features/moments/presentation/screens/moment_details_screen.dart';
```

Добавь route рядом с settings:

```dart
GoRoute(
  path: AppRoutePaths.momentDetailsPattern,
  builder: (context, state) {
    final momentId = state.pathParameters['momentId']!;

    return MomentDetailsScreen(momentId: momentId);
  },
),
```

Важно: используем `pathParameters`, не старый `params`.

### Шаг 8. Создать `MomentMediaView`

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_media_view.dart
```

Код:

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';

class MomentMediaView extends StatelessWidget {
  const MomentMediaView({
    required this.moment,
    super.key,
  });

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = moment.mediaUrl;

    if (moment.mediaType == 'image' && mediaUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const _MediaPlaceholder(icon: Icons.broken_image_outlined);
            },
          ),
        ),
      );
    }

    if (moment.mediaType == 'video' && mediaUrl != null) {
      return const _MediaPlaceholder(icon: Icons.play_circle_outline);
    }

    return const _MediaPlaceholder(icon: Icons.image_not_supported_outlined);
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({
    required this.icon,
  });

  final IconData icon;

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
        child: Center(
          child: Icon(
            icon,
            size: AppSpacing.xl,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
```

Здесь нет `withOpacity`; используем Material color roles.

### Шаг 9. Создать `MomentPreviewCard`

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_preview_card.dart
```

Код:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';

class MomentPreviewCard extends StatelessWidget {
  const MomentPreviewCard({
    required this.moment,
    this.onTap,
    this.trailing,
    super.key,
  });

  final Moment moment;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final author = moment.authorDisplayName ?? moment.authorId;
    final localeName = Localizations.localeOf(context).toString();
    final createdAt = DateFormat.yMMMd(localeName)
        .add_Hm()
        .format(moment.createdAt.toLocal());

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: const Icon(Icons.place_outlined),
      title: Text(
        moment.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author),
            Text(createdAt, style: textTheme.bodySmall),
          ],
        ),
      ),
      trailing: trailing,
    );
  }
}
```

Почему `MomentPreviewCard`, а не оставлять `ListTile` везде:

- одна presentation-форма для list и bottom sheet;
- меньше дублирования;
- details chapter легче расширять.

### Шаг 10. Обновить `NearbyMomentsList`

Файл:

```text
lib/src/features/moments/presentation/widgets/nearby_moments_list.dart
```

Добавь параметр:

```dart
final ValueChanged<Moment>? onMomentTap;
```

Constructor:

```dart
const NearbyMomentsList({
  required this.moments,
  this.onMomentTap,
  super.key,
});
```

В itemBuilder используй `MomentPreviewCard`:

```dart
return MomentPreviewCard(
  moment: moment,
  onTap: onMomentTap == null ? null : () => onMomentTap!(moment),
);
```

Так list не знает про router. `MapScreen` решает, что делать при tap.

### Шаг 11. Обновить side panel в `MapScreen`

В `_MapContent` добавь callback:

```dart
final ValueChanged<Moment> onMomentSelected;
```

Он уже есть. Передай его в `_NearbyMomentsPanel`:

```dart
final sidePanel = _NearbyMomentsPanel(
  moments: moments,
  onMomentSelected: onMomentSelected,
);
```

В `_NearbyMomentsPanel`:

```dart
class _NearbyMomentsPanel extends StatelessWidget {
  const _NearbyMomentsPanel({
    required this.moments,
    required this.onMomentSelected,
  });

  final List<Moment> moments;
  final ValueChanged<Moment> onMomentSelected;
}
```

И в list:

```dart
NearbyMomentsList(
  moments: moments,
  onMomentTap: onMomentSelected,
)
```

Сначала list tap пусть открывает тот же bottom sheet preview, что marker tap. Это последовательнее: marker и list дают одинаковый preview.

### Шаг 12. Обновить bottom sheet preview

Файл:

```text
lib/src/features/map/presentation/widgets/moment_preview_sheet.dart
```

Сейчас sheet показывает только текст. Обновим его: preview card + button.

```dart
class MomentPreviewSheet extends StatelessWidget {
  const MomentPreviewSheet({
    required this.moment,
    required this.onViewDetails,
    super.key,
  });

  final Moment moment;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MomentPreviewCard(moment: moment),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(context.l10n.viewMomentDetails),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Обрати внимание: `crossAxisAlignment: CrossAxisAlignment.stretch` помогает кнопке занять нормальную ширину.

### Шаг 13. Навигация из bottom sheet

Файл:

```text
lib/src/features/map/presentation/screens/map_screen.dart
```

Обнови `_showMomentPreview`:

```dart
void _showMomentPreview(Moment moment) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return MomentPreviewSheet(
        moment: moment,
        onViewDetails: () {
          Navigator.of(sheetContext).pop();
          context.push(AppRoutePaths.momentDetails(moment.id));
        },
      );
    },
  );
}
```

Почему `sheetContext` и `context` разные:

- `sheetContext` принадлежит bottom sheet;
- через него закрываем sheet;
- `context` из `MapScreen` используем для router navigation.

Это явно показывает, что сначала закрываем bottom sheet, потом пушим details route.

### Шаг 14. Создать `MomentDetailsSkeleton`

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_details_skeleton.dart
```

Код:

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';

class MomentDetailsSkeleton extends StatelessWidget {
  const MomentDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _SkeletonBox(height: 220, color: color),
        const SizedBox(height: AppSpacing.lg),
        _SkeletonBox(height: 28, color: color),
        const SizedBox(height: AppSpacing.sm),
        _SkeletonBox(height: 18, color: color),
        const SizedBox(height: AppSpacing.sm),
        _SkeletonBox(height: 18, color: color),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.color,
  });

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
```

Это не shimmer, но хороший структурный loading state без новой зависимости.

### Шаг 15. Создать error view

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_error_view.dart
```

Код:

```dart
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';

class MomentErrorView extends StatelessWidget {
  const MomentErrorView({
    required this.onRetry,
    super.key,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.momentDetailsLoadError,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Шаг 16. Создать details content

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_details_content.dart
```

Код:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';
import 'moment_media_view.dart';

class MomentDetailsContent extends StatelessWidget {
  const MomentDetailsContent({
    required this.moment,
    super.key,
  });

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final author = moment.authorDisplayName ?? moment.authorId;
    final localeName = Localizations.localeOf(context).toString();
    final createdAt = DateFormat.yMMMMd(localeName)
        .add_Hm()
        .format(moment.createdAt.toLocal());

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        MomentMediaView(moment: moment),
        const SizedBox(height: AppSpacing.lg),
        Text(moment.text, style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(author, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(createdAt, style: textTheme.bodySmall),
        if (moment.emotion != null) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              Chip(label: Text(moment.emotion!)),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _Metric(
              icon: Icons.favorite_border,
              value: moment.likeCount,
            ),
            const SizedBox(width: AppSpacing.lg),
            _Metric(
              icon: Icons.mode_comment_outlined,
              value: moment.commentCount,
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: AppSpacing.xs),
        Text('$value'),
      ],
    );
  }
}
```

Counters пока readonly. Actions like/comment будут в главах 11-12.

### Шаг 17. Создать `MomentDetailsScreen`

Файл:

```text
lib/src/features/moments/presentation/screens/moment_details_screen.dart
```

Код:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../controllers/moments_providers.dart';
import '../widgets/moment_details_content.dart';
import '../widgets/moment_details_skeleton.dart';
import '../widgets/moment_error_view.dart';

class MomentDetailsScreen extends ConsumerWidget {
  const MomentDetailsScreen({
    required this.momentId,
    super.key,
  });

  final String momentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moment = ref.watch(momentDetailsProvider(momentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.momentDetailsTitle),
      ),
      body: moment.when(
        loading: () => const MomentDetailsSkeleton(),
        error: (_, _) => MomentErrorView(
          onRetry: () => ref.invalidate(momentDetailsProvider(momentId)),
        ),
        data: (moment) => MomentDetailsContent(moment: moment),
      ),
    );
  }
}
```

Почему `ref.invalidate`: это простой способ сказать Riverpod заново вычислить provider.

### Шаг 18. Добавить локализацию

Файлы:

```text
lib/l10n/app_en.arb
lib/l10n/app_ru.arb
lib/l10n/app_es.arb
```

EN:

```json
"viewMomentDetails": "View details",
"momentDetailsTitle": "Moment details",
"momentDetailsLoadError": "Could not load this moment.",
"retry": "Retry"
```

RU:

```json
"viewMomentDetails": "Открыть детали",
"momentDetailsTitle": "Детали момента",
"momentDetailsLoadError": "Не удалось загрузить этот момент.",
"retry": "Повторить"
```

ES:

```json
"viewMomentDetails": "Ver detalles",
"momentDetailsTitle": "Detalles del momento",
"momentDetailsLoadError": "No se pudo cargar este momento.",
"retry": "Reintentar"
```

После этого:

```bash
flutter gen-l10n
```

### Шаг 19. Обновить widget tests

Текущий test override уже подменяет:

```dart
nearbyMomentsProvider.overrideWith((ref, center) async => testMoments)
```

Добавь override для details:

```dart
momentDetailsProvider.overrideWith((ref, id) async {
  return testMoments.singleWhere((moment) => moment.id == id);
});
```

Добавь test:

```dart
testWidgets('opens moment details from list preview', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('Test coffee moment'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('View details'));
  await tester.pumpAndSettle();

  expect(find.text('Moment details'), findsOneWidget);
  expect(find.text('Test coffee moment'), findsOneWidget);
  expect(find.text('Test User'), findsOneWidget);
});
```

Если bottom sheet animation требует еще один pump:

```dart
await tester.pumpAndSettle();
```

Не тестируй native Mapbox здесь. Он уже заменен через `mapSurfaceBuilderProvider`.

## Проверка

Команды:

```bash
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

Ручная проверка:

1. Запустить приложение.
2. Убедиться, что карта двигается и не возвращается к стартовой позиции.
3. Нажать marker.
4. Увидеть bottom sheet preview нормальной ширины.
5. Нажать "View details".
6. Увидеть `Moment details`.
7. Нажать Back.
8. Вернуться на карту.
9. Нажать moment в nearby list.
10. Увидеть тот же preview/details flow.

## Частые ошибки

### Ошибка: details route открывается, но id null

Причина: route path и ключ path parameter не совпадают.

Проверь:

```dart
path: '/moments/:momentId'
state.pathParameters['momentId']
```

### Ошибка: использовал `state.params`

В актуальном `go_router` используй:

```dart
state.pathParameters
```

`params` - старый API.

### Ошибка: details открывается только после marker tap, но не по прямому route

Причина: экран зависит от `state.extra`.

Решение: details screen должен уметь загрузить данные по `momentId`.

### Ошибка: UI ходит в Supabase напрямую

Неправильно:

```dart
Supabase.instance.client.from('moments')
```

в widget-е.

Правильно:

```dart
ref.watch(momentDetailsProvider(momentId))
```

### Ошибка: nested profile не парсится

Проверь, что DTO читает:

```dart
final profile = json['profiles'];
final profileJson = profile is Map<String, dynamic> ? profile : null;
```

Не делай cast без проверки, потому что backend response может отличаться при ошибке select-а.

### Ошибка: bottom sheet остается поверх details screen

Причина: сначала push, потом pop.

Правильно:

```dart
Navigator.of(sheetContext).pop();
context.push(AppRoutePaths.momentDetails(moment.id));
```

### Ошибка: details test падает из-за реального Supabase

Причина: не override-нут `momentDetailsProvider`.

Решение: добавить fake provider result в `ProviderScope`.

## Definition of Done

- `Moment` имеет `likeCount` и `commentCount` с default `0`.
- `MomentDto` умеет парсить flat nearby RPC и nested details select.
- `MomentsRepository` имеет `fetchMomentById`.
- `SupabaseMomentsRepository.fetchMomentById` реализован.
- `momentDetailsProvider` добавлен.
- `AppRoutePaths.momentDetailsPattern` и `AppRoutePaths.momentDetails(id)` добавлены.
- Router открывает `/moments/:momentId`.
- `MomentPreviewCard` создан.
- `NearbyMomentsList` использует `MomentPreviewCard`.
- Marker tap и list tap открывают preview bottom sheet.
- Bottom sheet имеет button "View details".
- `MomentDetailsScreen` показывает loading/error/data states.
- Media presentation работает для `none`, `image`, `video`.
- Counters отображаются как readonly values.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка marker -> preview -> details -> back выполнена.

## Что я буду проверять в ревью

- Details route не зависит от `state.extra`.
- Используется `state.pathParameters`, не deprecated/старый API.
- UI не обращается к Supabase напрямую.
- DTO не смешан с widget code.
- Bottom sheet закрывается перед navigation.
- Map не уничтожается при details navigation/back.
- Tests используют provider overrides.
- Нет лишних зависимостей для video/shimmer раньше времени.
- Текстовые строки локализованы EN/RU/ES.

Когда закончишь, напиши:

```text
Глава 8 готова, проверь код.
```
