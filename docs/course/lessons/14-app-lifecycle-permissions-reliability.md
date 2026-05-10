# 14 App Lifecycle, Permissions, and Reliability

Статус: done.

## Что строим

В главе 13 Geo Moments получил push notifications: Firebase/FCM, сохранение device token-а в Supabase, Edge Function для comment/reply push и открытие нужного moment по tap на notification.

В главе 14 сделаем приложение устойчивее в обычных мобильных ситуациях:

- будем реагировать на app lifecycle: `resumed`, `inactive`, `paused`, `detached`;
- обновим permission states после возврата из system settings;
- добавим понятный denied/permanently denied UX для location и push;
- добавим retry для map/moments/details/comments;
- покажем offline/poor network states без падения UI;
- добавим легкий logging слой, который можно заменить на Crashlytics/Sentry позже;
- сохраним notification tap flow из главы 13 и не будем показывать системный баннер для foreground push как обязательное требование.

После главы пользователь сможет отказать в permissions, вернуться из настроек, потерять сеть, повторить загрузку и все равно понимать, что происходит в приложении.

## Почему это важно

До этой главы мы проверяли "счастливые" сценарии: карта открылась, Supabase ответил, FCM token сохранился, push пришел. Реальное мобильное приложение живет в более шумной среде:

```text
пользователь запретил location
  -> открыл настройки Android
  -> разрешил location
  -> вернулся в приложение
  -> карта должна понять новый статус
```

Или:

```text
details открыт
  -> сеть пропала
  -> comments не загрузились
  -> пользователь нажал retry
  -> данные загрузились без перезапуска приложения
```

В Android-опыте это похоже на `onResume`, `ActivityResult`, `ViewModel` state, permission rationale и retry actions в UI. Во Flutter роль `onResume` выполняет `AppLifecycleListener` или `WidgetsBindingObserver`, а retry чаще всего выражается через Riverpod invalidation/controller methods.

## Словарь главы

`App lifecycle` - состояния процесса/окна приложения: foreground, background, paused, resumed.

`Resumed` - приложение снова активно и может обновить permissions, token, visible data.

`Paused` - приложение ушло в background. Дорогие подписки и animation-like работу можно остановить.

`Inactive` - переходное состояние, например системный dialog или app switcher.

`Detached` - Flutter view отсоединен. В обычной логике приложения это редко используется.

`Permission rationale` - объяснение, зачем нужен permission, когда пользователь уже отказал или сомневается.

`Permanently denied` - permission заблокирован так, что обычный request dialog больше не появится; нужно открыть system settings.

`Retry UX` - явная возможность повторить failed action без перезапуска экрана.

`Offline state` - состояние, когда запрос не может выполниться из-за отсутствия сети или DNS/timeout.

`Poor network` - сеть есть, но ответы медленные или нестабильные.

`Logging boundary` - маленький интерфейс, через который код пишет ошибки, не привязываясь к конкретному сервису аналитики.

## 1. Как Flutter сообщает о lifecycle

Во Flutter есть два основных способа слушать lifecycle.

Первый - `WidgetsBindingObserver`. Это старый, но рабочий API:

```dart
class MyState extends State<MyWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh permission status or visible data.
    }
  }
}
```

Второй - `AppLifecycleListener`. Он лучше подходит для маленького сервисного wrapper-а, потому что не требует mixin на widget state:

```dart
final listener = AppLifecycleListener(
  onResume: () {
    // App returned to foreground.
  },
  onPause: () {
    // App moved to background.
  },
);

listener.dispose();
```

В этой главе выберем `AppLifecycleListener`, потому что lifecycle нужен не одному экрану, а нескольким feature-контроллерам. Мы спрячем Flutter API за маленьким сервисом, чтобы tests могли подменить lifecycle stream.

## 2. Что именно будем обновлять на resume

На `resumed` не нужно перезагружать весь app. Это создает лишний network traffic и дергает UI.

В Geo Moments на `resumed` полезно сделать четыре вещи:

1. Проверить location permission, потому что пользователь мог изменить его в system settings.
2. Проверить push permission и попробовать сохранить FCM token, если permission теперь разрешен.
3. Обновить текущие moments на карте, если экран карты открыт.
4. Обновить открытый details/comments, если этот экран открыт и последняя загрузка была ошибкой или данные давно не обновлялись.

Важно: notification tap уже обрабатывается через `getInitialMessage()` и `onMessageOpenedApp`. Не нужно делать отдельный deep link parser для FCM в этой главе.

## 3. Целевая структура после главы

```text
lib/
  src/
    core/
      lifecycle/
        app_lifecycle_service.dart
        app_lifecycle_providers.dart
      logging/
        app_logger.dart
        debug_app_logger.dart
      network/
        app_failure.dart
        retry_policy.dart
    features/
      map/
        presentation/
          widgets/
            location_permission_banner.dart
      moments/
        presentation/
          widgets/
            retry_error_view.dart
      notifications/
        presentation/
          widgets/
            notification_status_tile.dart  updated
```

Точная структура может быть немного другой, если в проекте уже есть близкий helper. Главное правило прежнее: UI не должен напрямую знать про Firebase/Supabase internals, а tests должны иметь возможность подменить platform APIs.

## Практика

### Шаг 1. Создать lifecycle service

Файл:

```text
lib/src/core/lifecycle/app_lifecycle_service.dart
```

Код:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';

abstract interface class AppLifecycleService {
  Stream<AppLifecycleState> get states;

  void dispose();
}

class FlutterAppLifecycleService implements AppLifecycleService {
  FlutterAppLifecycleService() {
    _listener = AppLifecycleListener(
      onStateChange: _statesController.add,
    );
  }

  late final AppLifecycleListener _listener;
  final _statesController = StreamController<AppLifecycleState>.broadcast();

  @override
  Stream<AppLifecycleState> get states => _statesController.stream;

  @override
  void dispose() {
    _listener.dispose();
    _statesController.close();
  }
}
```

Почему stream: Riverpod controllers и widgets смогут слушать один общий источник. В тестах мы заменим его fake stream-ом и вручную отправим `AppLifecycleState.resumed`.

### Шаг 2. Добавить providers для lifecycle

Файл:

```text
lib/src/core/lifecycle/app_lifecycle_providers.dart
```

Код:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_service.dart';

final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  final service = FlutterAppLifecycleService();
  ref.onDispose(service.dispose);
  return service;
});

final appLifecycleStateProvider = StreamProvider<AppLifecycleState>((ref) {
  return ref.watch(appLifecycleServiceProvider).states;
});

final appResumedProvider = StreamProvider<void>((ref) {
  return ref
      .watch(appLifecycleServiceProvider)
      .states
      .where((state) => state == AppLifecycleState.resumed)
      .map((_) {});
});
```

`appResumedProvider` выглядит маленьким, но он делает код экранов проще: feature не должна каждый раз знать все lifecycle states.

### Шаг 3. Обновлять location permission после возврата в приложение

В главе 7 уже был `LocationPermissionController`. Теперь добавим метод `refresh()`:

Файл:

```text
lib/src/features/map/presentation/controllers/location_permission_controller.dart
```

Куда вставлять: внутрь класса `LocationPermissionController`, рядом с методом `request()`. `build()` отвечает за начальное состояние, `request()` - за явное действие пользователя, а `refresh()` - за тихую повторную проверку после возврата из system settings.

```dart
Future<void> refresh() async {
  state = await AsyncValue.guard(() {
    return Permission.locationWhenInUse.status;
  });
}
```

Если текущий controller использует `Permission.location`, оставь тот же permission type, который уже есть в проекте. Не смешивай `location`, `locationWhenInUse` и `locationAlways` без причины: Android/iOS показывают разные dialogs, и тесты станут непредсказуемыми.

На экране карты добавь listener:

Файл:

```text
lib/src/features/map/presentation/screens/map_screen.dart
```

Куда вставлять: в `build` метода `MapScreen`, после строк, где уже вычисляются `permission` и `isLocationEnabled`. Listener зависит от provider-а permission controller, поэтому его место рядом с чтением permission state.

```dart
ref.listen(appResumedProvider, (previous, next) {
  if (next.hasValue) {
    ref.read(locationPermissionControllerProvider.notifier).refresh();
  }
});
```

Это важно, потому что `ref.listen` должен жить в lifecycle build-а Riverpod widget-а, а не в random helper function.

### Шаг 4. Сразу добавить строковые ресурсы

В этой главе UI получит новые тексты: permission banner, retry titles и человекочитаемые network errors. Как и в прошлых главах, не пишем строки прямо в widgets. Сначала добавляем ключи в ARB, затем используем их через `context.l10n`.

Файл:

```text
lib/l10n/app_en.arb
```

Куда вставлять: рядом с уже существующими ключами `locationPermissionDenied`, `nearbyMomentsLoadError`, `momentDetailsLoadError`, `commentsTitle`, `retry` и `notificationsPermissionDenied`. Так файл остается тематически сгруппированным, и позже легче найти строки нужной feature.

Добавь ключи:

```json
"locationPermissionBlocked": "Location is blocked in system settings.",
"locationPermissionRationale": "Location helps center the map on where you are.",
"openSettings": "Open settings",
"allowPermission": "Allow",
"momentsLoadRetryTitle": "Moments did not load",
"momentDetailsLoadRetryTitle": "Moment did not load",
"commentsLoadRetryTitle": "Comments did not load",
"networkOfflineMessage": "You appear to be offline.",
"networkTimeoutMessage": "The network is taking too long.",
"genericFailureMessage": "Something went wrong."
```

Файлы:

```text
lib/l10n/app_ru.arb
lib/l10n/app_es.arb
```

Куда вставлять: в те же тематические группы. Переводы могут быть простыми, но ключи должны совпадать с English ARB.

Пример RU:

```json
"locationPermissionBlocked": "Геолокация заблокирована в системных настройках.",
"locationPermissionRationale": "Геолокация помогает центрировать карту на вас.",
"openSettings": "Открыть настройки",
"allowPermission": "Разрешить",
"momentsLoadRetryTitle": "Моменты не загрузились",
"momentDetailsLoadRetryTitle": "Момент не загрузился",
"commentsLoadRetryTitle": "Комментарии не загрузились",
"networkOfflineMessage": "Похоже, вы не в сети.",
"networkTimeoutMessage": "Сеть отвечает слишком долго.",
"genericFailureMessage": "Что-то пошло не так."
```

Пример ES:

```json
"locationPermissionBlocked": "La ubicación está bloqueada en los ajustes del sistema.",
"locationPermissionRationale": "La ubicación ayuda a centrar el mapa donde estás.",
"openSettings": "Abrir ajustes",
"allowPermission": "Permitir",
"momentsLoadRetryTitle": "No se cargaron los momentos",
"momentDetailsLoadRetryTitle": "No se cargó el momento",
"commentsLoadRetryTitle": "No se cargaron los comentarios",
"networkOfflineMessage": "Parece que no tienes conexión.",
"networkTimeoutMessage": "La red está tardando demasiado.",
"genericFailureMessage": "Algo salió mal."
```

После изменения ARB сразу выполни:

```bash
flutter gen-l10n
```

Зачем делать это до widgets: следующий код будет использовать `context.l10n.locationPermissionBlocked` и другие getters. Если не сгенерировать локализации, `flutter analyze` справедливо покажет ошибку.

### Шаг 5. Разделить denied и permanently denied

`permission_handler` различает несколько статусов. Для location нам важны:

```dart
PermissionStatus.granted
PermissionStatus.denied
PermissionStatus.permanentlyDenied
PermissionStatus.restricted
PermissionStatus.limited
```

Минимальный mapping:

```dart
bool get canUseLocation => status.isGranted || status.isLimited;
bool get shouldOpenSettings => status.isPermanentlyDenied || status.isRestricted;
```

Для UI создадим отдельный banner, а не будем перегружать map toolbar. Все тексты берем из `context.l10n`, потому что строки уже добавлены в ARB на предыдущем шаге.

Файл:

```text
lib/src/features/map/presentation/widgets/location_permission_banner.dart
```

Код для нового файла:

```dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/localization/app_localizations_context.dart';

class LocationPermissionBanner extends StatelessWidget {
  const LocationPermissionBanner({
    required this.status,
    required this.onRequest,
    required this.onOpenSettings,
    super.key,
  });

  final PermissionStatus status;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (status.isGranted || status.isLimited) {
      return const SizedBox.shrink();
    }

    final shouldOpenSettings =
        status.isPermanentlyDenied || status.isRestricted;

    return MaterialBanner(
      content: Text(
        shouldOpenSettings
            ? context.l10n.locationPermissionBlocked
            : context.l10n.locationPermissionRationale,
      ),
      actions: [
        TextButton(
          onPressed: shouldOpenSettings ? onOpenSettings : onRequest,
          child: Text(
            shouldOpenSettings
                ? context.l10n.openSettings
                : context.l10n.allowPermission,
          ),
        ),
      ],
    );
  }
}
```

Куда подключать banner: в `lib/src/features/map/presentation/screens/map_screen.dart`, внутри `_MapScreenState.build`, после вычисления `permission` и `isLocationEnabled`. Удобно передать `permission.value` в `_MapContent` или обернуть body в `Column`, где banner стоит над картой. Цель banner-а - показать причину и действие, не заменяя саму карту и не ломая текущий preview/list layout.

### Шаг 6. Кнопка location должна продолжать центрировать карту

В прошлых главах уже была важная ошибка: location button только запрашивал permission, но не центрировал карту. Не возвращай эту ошибку.

Правильное поведение:

```text
tap location button
  -> если permission есть: отправить focus command карте
  -> если permission можно запросить: request permission
  -> если после request permission granted: отправить focus command карте
  -> если permanentlyDenied: показать banner/action open settings
```

То есть метод button handler должен сохранить текущую механику `locationFocusRequestId` или ее аналог. Permission UX добавляется вокруг нее, а не заменяет ее.

Куда вставлять изменения: в текущий метод `_focusUserLocation()` файла `lib/src/features/map/presentation/screens/map_screen.dart`. Именно там уже живет логика tap по кнопке с tooltip `context.l10n.enableLocation`, поэтому здесь надо добавить проверку `permanentlyDenied`/`openAppSettings()`, а не создавать отдельную кнопку, которая обойдет существующий focus command.

### Шаг 7. Обновить push permission после resume

Пользователь может нажать кнопку с текстом `context.l10n.notificationsAsk`, получить denied, потом открыть Android settings и разрешить notifications вручную. После возврата Settings screen должен показать актуальный статус.

В `PushNotificationsController` добавь метод.

Файл:

```text
lib/src/features/notifications/presentation/controllers/push_notifications_controller.dart
```

Куда вставлять: внутрь класса `PushNotificationsController`, рядом с уже существующими публичными методами `requestAndRegister()` и `registerIfAllowed()`. Это публичное действие controller-а, потому что его будет вызывать Settings UI на lifecycle resume.

```dart
Future<void> refreshPermissionStatus() async {
  final client = ref.read(pushMessagingClientProvider);
  final status = await client.getPermissionStatus();

  if (_canUseToken(status) && ref.read(currentUserProvider).value != null) {
    await _registerCurrentToken(client);
    _listenForTokenRefresh(client);
  }

  state = AsyncData(status);
}
```

Если в controller уже есть близкий метод `registerIfAllowed()`, можно использовать его вместо нового имени. Главное, чтобы resume не вызывал `requestPermission()`: системный dialog должен появляться только после действия пользователя.

В `NotificationStatusTile` добавь lifecycle listener.

Файл:

```text
lib/src/features/notifications/presentation/widgets/notification_status_tile.dart
```

Куда вставлять: в начало метода `build`, сразу после `final state = ref.watch(pushNotificationsControllerProvider);`. Так tile будет обновлять status, когда пользователь вернулся из system settings, но не будет сам показывать permission dialog.

```dart
ref.listen(appResumedProvider, (previous, next) {
  if (next.hasValue) {
    unawaited(
      ref
          .read(pushNotificationsControllerProvider.notifier)
          .refreshPermissionStatus(),
    );
  }
});
```

Если используешь `unawaited`, добавь:

```dart
import 'dart:async';
```

### Шаг 8. Добавить open settings action

Для location и push можно использовать `openAppSettings()` из `permission_handler`.

```dart
Future<void> openSystemSettings() async {
  await openAppSettings();
}
```

Куда вставлять: если действие нужно только карте, добавь приватный метод `_openSystemSettings()` в `_MapScreenState` рядом с `_focusUserLocation()`. Если действие нужно и карте, и notification tile, создай маленький wrapper/provider в `lib/src/core/permissions/permission_settings_service.dart`, чтобы оба UI элемента не зависели от деталей platform API.

Не пытайся открыть приватные Android settings intents вручную. `permission_handler` уже делает безопасный cross-platform переход.

Важно: после возврата из settings мы не знаем результат напрямую. Поэтому нужен lifecycle resume refresh из предыдущих шагов.

### Шаг 9. Ввести общий failure type

Сейчас разные экраны могут показывать raw exception text. Для portfolio app лучше иметь маленький failure mapping. Важно: core/network слой не должен хранить UI-тексты. Он возвращает тип ошибки, а текст выбирается в widget через `context.l10n`.

Файл:

```text
lib/src/core/network/app_failure.dart
```

Код:

```dart
enum AppFailureKind {
  offline,
  timeout,
  unauthorized,
  notFound,
  server,
  unknown,
}

class AppFailure {
  const AppFailure({
    required this.kind,
  });

  final AppFailureKind kind;
}
```

В этот же файл ниже класса добавь минимальный mapper:

```dart
AppFailure mapExceptionToFailure(Object error) {
  final text = error.toString().toLowerCase();

  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable')) {
    return const AppFailure(
      kind: AppFailureKind.offline,
    );
  }

  if (text.contains('timeout')) {
    return const AppFailure(
      kind: AppFailureKind.timeout,
    );
  }

  return const AppFailure(
    kind: AppFailureKind.unknown,
  );
}
```

Куда превращать failure в текст: в отдельном UI-oriented helper-е, потому что здесь уже нужен `BuildContext` и `context.l10n`.

Файл:

```text
lib/src/core/network/app_failure_message.dart
```

Код:

```dart
import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations_context.dart';
import 'app_failure.dart';

String messageForFailure(BuildContext context, AppFailure failure) {
  return switch (failure.kind) {
    AppFailureKind.offline => context.l10n.networkOfflineMessage,
    AppFailureKind.timeout => context.l10n.networkTimeoutMessage,
    _ => context.l10n.genericFailureMessage,
  };
}
```

Почему отдельный файл: `app_failure.dart` остается чистым mapper-ом без зависимости от localization, а UI получает централизованное место для выбора текста.

Это не идеальный global error model. Но для курса это хороший шаг: UI перестает показывать backend internals, а tests могут проверять стабильные localized messages.

### Шаг 10. Сделать reusable retry error view

Файл:

```text
lib/src/features/moments/presentation/widgets/retry_error_view.dart
```

Код:

```dart
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';

class RetryErrorView extends StatelessWidget {
  const RetryErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
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

Куда вставлять: это новый reusable widget, поэтому он не должен знать про конкретный provider. Он получает уже локализованные `title` и `message` от экрана, а кнопку `Retry` берет из `context.l10n.retry`.

### Шаг 11. Retry для карты

На карте moments приходят из `nearbyMomentsProvider(center)`. Если provider падает, UI должен показать retry.

Файл:

```text
lib/src/features/map/presentation/screens/map_screen.dart
```

Куда вставлять:

1. Добавь imports для `mapExceptionToFailure`, `messageForFailure` и `RetryErrorView` в верхнюю часть файла.
2. Найди `body: moments.when(` в `_MapScreenState.build`.
3. Замени только ветку `error: (error, _) { ... }`.
4. Сохрани существующую логику `_hasLoadedMoments`: если старые moments уже есть, можно оставить карту видимой; retry view нужен для первого полного failure, когда показывать нечего.

Пример replacement для нижней части error-ветки:

```dart
error: (error, stackTrace) {
  if (_hasLoadedMoments) {
    return _MapContent(
      moments: _visibleMoments,
      isLocationEnabled: isLocationEnabled,
      locationFocusRequestId: _locationFocusRequestId,
      mapBuilder: mapBuilder,
      onMomentSelected: _showMomentPreview,
      onCameraCenterChanged: _updateCenter,
    );
  }

  final failure = mapExceptionToFailure(error);
  return RetryErrorView(
    title: context.l10n.momentsLoadRetryTitle,
    message: messageForFailure(context, failure),
    onRetry: () {
      ref.invalidate(nearbyMomentsProvider(_center));
    },
  );
},
```

Почему именно сюда: `MapScreen` уже владеет `_center`, `_visibleMoments` и `_hasLoadedMoments`. Только здесь мы знаем, какой именно provider instance надо invalidated: `nearbyMomentsProvider(_center)`.

### Шаг 12. Retry для details

Details использует `momentDetailsProvider(momentId)`. При ошибке важно не падать и не показывать UUID автора.

Файл:

```text
lib/src/features/moments/presentation/screens/moment_details_screen.dart
```

Куда вставлять:

1. Добавь imports для `mapExceptionToFailure`, `messageForFailure` и `RetryErrorView`.
2. В `body: moment.when(` замени только ветку `error`.
3. Старый `MomentErrorView` можно удалить или оставить неиспользуемым до отдельной cleanup-задачи. Если импорт больше не нужен, убери import.

Replacement:

```dart
error: (error, stackTrace) {
  final failure = mapExceptionToFailure(error);
  return RetryErrorView(
    title: context.l10n.momentDetailsLoadRetryTitle,
    message: messageForFailure(context, failure),
    onRetry: () {
      ref.invalidate(momentDetailsProvider(momentId));
    },
  );
},
```

Почему именно сюда: `MomentDetailsScreen` получает `momentId` из router и смотрит конкретный `momentDetailsProvider(momentId)`. Retry должен повторить этот же запрос, а не возвращать пользователя на карту и не создавать новый route.

Сохраняем правило главы 11: если profile join/RPC optional data не пришли, repository должен пробовать fallback, а UI не должен показывать raw UUID вместо имени автора.

### Шаг 13. Retry для comments

Comments controller уже умеет rollback при ошибке создания. Теперь добавим retry для initial load.

Файл:

```text
lib/src/features/moments/presentation/controllers/moment_comments_controller.dart
```

Куда вставлять: внутрь класса `MomentCommentsController`, рядом с публичным методом `refresh()`. Метод `retry()` здесь не обязателен, но делает намерение понятным для UI и tests.

```dart
void retry() {
  ref.invalidateSelf();
}
```

Если controller - `FamilyAsyncNotifier`, `ref.invalidateSelf()` перезапустит текущий build с тем же `momentId`. Это лучше, чем вручную чистить все поля.

Файл UI, где нужно показать retry:

```text
lib/src/features/moments/presentation/widgets/moment_details_content.dart
```

В текущей структуре отдельного `moment_comments_section.dart` нет: секция comments находится внутри `MomentDetailsContent`. Найди в `build` строку:

```dart
ref.watch(momentCommentsControllerProvider(moment.id))
```

Куда вставлять: ниже по этому же файлу найди `comments.when(...)` после заголовка `Text(context.l10n.commentsTitle, ...)` и замени только ветку `error`. Data/loading ветки не трогаем, чтобы не сломать input и reply mode из главы 12.

Пример:

```dart
error: (error, stackTrace) {
  final failure = mapExceptionToFailure(error);
  return RetryErrorView(
    title: context.l10n.commentsLoadRetryTitle,
    message: messageForFailure(context, failure),
    onRetry: () {
      ref
          .read(momentCommentsControllerProvider(moment.id).notifier)
          .retry();
    },
  );
},
```

Не ломай realtime из главы 12. Retry должен перезагрузить текущие comments, а realtime subscription должен остаться включенным только для открытого details.

### Шаг 14. Добавить timeout там, где пользователь ждет UI

Не все backend requests должны иметь одинаковый timeout. Для интерактивного UI начни с простого helper-а:

Файл:

```text
lib/src/core/network/retry_policy.dart
```

Код:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RetryPolicy {
  const RetryPolicy({
    this.timeout = const Duration(seconds: 12),
  });

  final Duration timeout;

  Future<T> run<T>(Future<T> Function() action) {
    return action().timeout(timeout);
  }
}
```

Provider:

Куда вставлять: в конец того же файла `lib/src/core/network/retry_policy.dart`, после класса `RetryPolicy`. Provider лежит рядом с helper-ом, потому что это маленькая app-wide настройка, а не feature-specific provider.

```dart
final retryPolicyProvider = Provider<RetryPolicy>((ref) {
  return const RetryPolicy();
});
```

Использование в repository или controller.

Куда вставлять: в controller/repository method, который обслуживает видимый экран и может зависнуть для пользователя. Например, если добавляешь timeout для загрузки nearby moments, оборачивай вызов repository в provider/controller, который строит `nearbyMomentsProvider`, а не внутри widget build.

```dart
final retryPolicy = ref.read(retryPolicyProvider);
final moments = await retryPolicy.run(() {
  return repository.fetchNearby(center);
});
```

Для этой главы не делаем автоматический exponential backoff. В мобильном UI ручной retry часто понятнее: пользователь сам решает, когда повторить запрос.

### Шаг 15. Добавить logging boundary

Файл:

```text
lib/src/core/logging/app_logger.dart
```

Код:

```dart
abstract interface class AppLogger {
  void info(String message, {Map<String, Object?> context = const {}});

  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  });

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  });
}
```

Файл:

```text
lib/src/core/logging/debug_app_logger.dart
```

Код:

```dart
import 'package:flutter/foundation.dart';

import 'app_logger.dart';

class DebugAppLogger implements AppLogger {
  const DebugAppLogger();

  @override
  void info(String message, {Map<String, Object?> context = const {}}) {
    debugPrint('[info] $message ${_formatContext(context)}');
  }

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    debugPrint('[warning] $message ${_formatContext(context)}');
    if (error != null) {
      debugPrint('  error: $error');
    }
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    debugPrint('[error] $message ${_formatContext(context)}');
    if (error != null) {
      debugPrint('  error: $error');
    }
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _formatContext(Map<String, Object?> context) {
    if (context.isEmpty) {
      return '';
    }

    return context.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
  }
}
```

Provider:

Куда вставлять: создай отдельный файл `lib/src/core/logging/app_logger_provider.dart` и положи provider туда. Так интерфейс (`app_logger.dart`) не зависит от Riverpod, а конкретная app wiring-точка живет отдельно.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';
import 'debug_app_logger.dart';

final appLoggerProvider = Provider<AppLogger>((ref) {
  return const DebugAppLogger();
});
```

Почему не подключаем Crashlytics прямо сейчас: глава 13 уже добавила Firebase, но Crashlytics потребует отдельной platform setup и release symbols. В этой главе строим boundary. Реальный remote logger можно добавить позже без переписывания feature-кода.

### Шаг 16. Логировать важные ошибки без утечки секретов

Логировать полезно:

```text
moments fetch failed
comments realtime subscription failed
push token registration skipped
push token registration failed
media upload failed
```

Не логировать:

```text
Supabase anon key
Firebase service account JSON
FCM token целиком
COMMENT_PUSH_WEBHOOK_SECRET
private media local path без необходимости
```

Для FCM token, если очень нужно, показывай только prefix:

```dart
String shortToken(String token) {
  final length = token.length < 12 ? token.length : 12;
  return '${token.substring(0, length)}...';
}
```

Это правило уже применялось в главе 13. Сохраняем его.

### Шаг 17. Тестировать lifecycle без настоящего app background

В widget/unit tests не нужно реально сворачивать приложение. Достаточно fake lifecycle service.

Куда вставлять: в test-файл, который проверяет lifecycle behavior. Если проверяешь карту, это может быть `test/widget_test.dart` или отдельный `test/app_lifecycle_test.dart`. Fake class обычно кладем в конец test-файла после `main()`, как остальные fake repositories/controllers в проекте.

```dart
class FakeAppLifecycleService implements AppLifecycleService {
  final _controller = StreamController<AppLifecycleState>.broadcast();

  @override
  Stream<AppLifecycleState> get states => _controller.stream;

  void resume() {
    _controller.add(AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
```

Provider override:

Куда вставлять: в `ProviderScope(overrides: [...])` или `ProviderContainer(overrides: [...])` конкретного теста. Override должен быть рядом с остальными overrides, иначе fake stream не будет использоваться приложением.

```dart
final lifecycle = FakeAppLifecycleService();

final container = ProviderContainer(
  overrides: [
    appLifecycleServiceProvider.overrideWithValue(lifecycle),
  ],
);
```

Проверить можно так:

Куда вставлять: внутрь test body после `pumpWidget(...)`/создания `ProviderContainer`, когда widget или controller уже подписался на `appResumedProvider`.

```dart
lifecycle.resume();
await Future<void>.delayed(Duration.zero);

expect(fakePermissionClient.refreshCount, 1);
```

Главная мысль: fake class должен реально использоваться через provider override. Это та же ошибка, которую мы уже исправляли в тестах media picker, likes, comments и push.

### Шаг 18. Тестировать retry без настоящего Supabase

Для retry нужен fake repository, который сначала падает, потом возвращает data:

Куда вставлять: в конец test-файла рядом с другими fake repositories. Для map retry это будет fake implementation того repository/provider, который стоит под `nearbyMomentsProvider`.

```dart
class FlakyMomentsRepository implements MomentsRepository {
  var attempts = 0;

  @override
  Future<List<Moment>> fetchNearby({
    required double latitude,
    required double longitude,
  }) async {
    attempts += 1;
    if (attempts == 1) {
      throw const SocketException('offline');
    }

    return [testMoment];
  }
}
```

В widget test проверяй текст через generated localization, чтобы не дублировать строку из ARB прямо в тесте. Для этого в test-файл добавь imports `package:flutter/widgets.dart` и `package:geo_moments/src/generated/l10n/app_localizations.dart`, если их там еще нет.

Куда вставлять: в сам `testWidgets(...)` после первого `pumpAndSettle()`, когда error state уже отрисован, и перед tap по retry button.

```dart
final l10n = await AppLocalizations.delegate.load(const Locale('en'));

expect(find.text(l10n.networkOfflineMessage), findsOneWidget);

await tester.tap(find.text(l10n.retry));
await tester.pumpAndSettle();

expect(find.text(testMoment.text), findsOneWidget);
```

Если error view находится ниже scroll, используй `tester.ensureVisible(...)`. Details уже scrollable, и тесты прошлых глав должны учитывать это.

### Шаг 19. Ручная проверка denied permissions

Android:

1. Установи приложение.
2. Открой карту.
3. Нажми location.
4. Запрети permission.
5. Проверь, что UI не ломается и предлагает понятное действие.
6. В system settings включи location permission.
7. Вернись в приложение.
8. Проверь, что status обновился.
9. Нажми location еще раз.
10. Карта должна центрироваться на location puck.

Push:

1. Открой Settings.
2. Нажми кнопку `context.l10n.notificationsAsk` (`Enable notifications` в английской локали).
3. Запрети notifications.
4. Проверь denied text.
5. В Android settings включи notifications.
6. Вернись в приложение.
7. Проверь, что Settings обновил status без нового dialog.
8. Проверь, что token снова сохраняется в `push_tokens`.

Foreground push может не показать системный баннер. Для этой главы это нормально. Мы проверяем token registration и tap/background сценарий из главы 13.

## Проверка

Команды:

```bash
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

Если добавишь Supabase migration в этой главе, используй новый timestamp filename. Старые migration-файлы не переисполняются после того, как уже применены.

В этой главе migration обычно не нужна. Мы улучшаем client reliability и UI behavior.

## Частые ошибки

### Ошибка: permission dialog появляется сам при открытии Settings

Причина: на resume или build вызвали `requestPermission()`.

Исправление: на resume вызывай только status check, например `getPermissionStatus()` или `Permission.location.status`. Dialog должен появляться только после явного tap пользователя.

### Ошибка: после возврата из settings UI не обновился

Причина: нет lifecycle listener или listener не подключен к controller.

Исправление: слушай `AppLifecycleState.resumed` и вызывай refresh status.

### Ошибка: location button снова перестал центрировать карту

Причина: handler заменили permission request-ом.

Исправление: после granted status отправь существующий focus command карте. Проверка из widget test должна ожидать рост `locationFocusRequestId`.

### Ошибка: retry создает новый provider вместо повторения текущего

Причина: retry action создает новый state вручную и расходится с Riverpod graph.

Исправление: используй `ref.invalidate(provider(args))` или `ref.invalidateSelf()` в controller.

### Ошибка: UI показывает raw exception или UUID автора

Причина: ошибка Supabase проброшена прямо в Text.

Исправление: маппить exception в `AppFailure`, а author fallback оставлять пустым/человеческим, не raw UUID.

### Ошибка: новые UI строки написаны прямо в widgets

Причина: строку добавили в `Text('...')`, `MaterialBanner`, button label или test expectation, минуя ARB.

Исправление: сначала добавь ключи в `app_en.arb`, `app_ru.arb`, `app_es.arb`, запусти `flutter gen-l10n`, затем используй `context.l10n.someKey`. В тестах лучше брать текст через `AppLocalizations.delegate.load(...)`, чтобы не дублировать English строку.

### Ошибка: тест fake lifecycle создан, но не используется

Причина: забыли provider override.

Исправление:

```dart
appLifecycleServiceProvider.overrideWithValue(fakeLifecycle)
```

### Ошибка: logs содержат FCM token или secrets целиком

Причина: debugPrint был добавлен вокруг raw payload.

Исправление: логируй только prefix token-а и никогда не логируй service account JSON, webhook secret или Supabase service role key.

## Definition of Done

- Есть lifecycle service/provider, который можно подменить в tests.
- На `resumed` обновляется location permission status.
- На `resumed` обновляется push permission status без нового permission dialog.
- Location denied/permanently denied показываются понятным UI.
- Push denied/permanently denied показываются понятным UI.
- `openAppSettings()` доступен там, где обычный permission dialog уже невозможен.
- Location button продолжает центрировать карту после granted permission.
- Map moments error state показывает retry.
- Moment details error state показывает retry.
- Comments initial load error показывает retry.
- UI не показывает raw backend exception пользователю.
- Все новые видимые строки добавлены в EN/RU/ES ARB до использования в widgets.
- Logging boundary добавлен и не пишет secrets.
- Tests используют fake lifecycle/permission/repository classes через provider overrides.
- Scrollable details/settings tests учитывают, что нужный текст может быть ниже первого viewport.
- Notification tap из главы 13 продолжает открывать `/moments/:momentId`.
- `flutter gen-l10n` проходит, если добавлялись ARB строки.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка denied permissions и retry выполнена.

## Что прислать на ревью

После реализации напиши:

```text
Глава 14 готова, проверь код.
```

Я буду проверять:

- lifecycle listener не вызывает permission dialogs сам по себе;
- после возврата из system settings статусы обновляются;
- location button не потерял центрирование карты;
- retry повторяет текущие providers/controllers, а не создает параллельный state;
- offline/timeout messages понятные и локализованы через ARB;
- fake classes реально используются в tests;
- logs не содержат secrets, полный FCM token или service account JSON;
- Firebase service account по-прежнему не попал в репозиторий;
- `/moments/new` остается выше `/moments/:momentId`;
- details не падает из-за optional RPC/profile join;
- автор не отображается UUID;
- foreground push не считается обязательным системным баннером.
