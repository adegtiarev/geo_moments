# 13 Firebase Push

Статус: next.

## Что строим

В главе 12 Geo Moments получил обсуждения: root comments, replies, realtime refresh открытого details screen и настоящий `comment_count`.

В главе 13 добавим push notifications:

- подключим Firebase к Flutter через FlutterFire CLI;
- добавим Firebase Cloud Messaging;
- запросим permission на уведомления;
- получим FCM registration token;
- сохраним token в Supabase;
- отправим push при новом комментарии или ответе;
- откроем нужный moment details по tap на notification.

После главы пользователь сможет закрыть приложение, получить уведомление о новом comment/reply и попасть в `/moments/:momentId` после нажатия на push.

## Почему это важно

Realtime работает только пока приложение активно и экран открыт. Push нужен для другого сценария:

```text
пользователь создал moment
  -> ушел из приложения
  -> другой пользователь написал comment
  -> автор получил push
  -> tap открыл details этого moment
```

В Android-опыте это похоже на:

```text
FirebaseMessagingService
  -> receives FCM token
  -> sends token to backend
  -> receives notification tap intent
  -> opens Activity with deep link / screen args
```

Во Flutter часть этой работы делает `firebase_messaging`, а routing остается за `go_router`.

## Словарь главы

`FCM` - Firebase Cloud Messaging, сервис доставки push notifications.

`Registration token` - строка, которая идентифицирует конкретную установку приложения для FCM. Это не auth token пользователя.

`APNs` - Apple Push Notification service. На iOS FCM доставляет push через APNs, поэтому нужен Apple push setup.

`Notification permission` - разрешение пользователя показывать уведомления.

`Foreground message` - push, полученный пока приложение открыто.

`Background message` - push, полученный пока приложение свернуто.

`Terminated state` - приложение полностью закрыто, а tap по notification запускает его заново.

`Data payload` - custom поля push-сообщения, например `moment_id`.

`Notification payload` - видимые поля push-сообщения, например title/body.

`Service account` - серверный ключ Firebase. Он не должен попадать в Flutter app или Git.

## 1. Что именно будет делать клиент

Клиент не отправляет push другим пользователям напрямую. Клиент делает только безопасные действия:

1. Инициализирует Firebase.
2. Запрашивает permission.
3. Получает FCM token.
4. Сохраняет token в Supabase под текущим user id.
5. Слушает обновления token-а.
6. Обрабатывает tap по notification.

Схема:

```text
GeoMomentsApp
  -> PushNotificationsController
  -> PushMessagingClient
  -> FirebaseMessaging

PushNotificationsController
  -> PushTokensRepository
  -> Supabase table push_tokens
```

Почему не сохраняем token в `profiles`: у одного пользователя может быть несколько устройств. У каждого устройства свой registration token.

## 2. Что будет делать backend

Backend решает, кому отправить push:

```text
insert into moment_comments
  -> database webhook вызывает Supabase Edge Function
  -> function находит recipient user
  -> function читает push_tokens recipient-а
  -> function отправляет FCM HTTP v1 request
```

Для root comment recipient - автор moment-а.

Для reply recipient - автор parent comment-а.

Если автор comment-а и recipient совпадают, push не отправляем. Пользователь не должен получать notification о своем же действии.

## 3. Почему используем FCM HTTP v1, а не legacy server key

Старый подход с legacy server key не подходит для нового кода. В этой главе используем FCM HTTP v1:

```text
service account JSON
  -> signed JWT
  -> OAuth access token
  -> POST https://fcm.googleapis.com/v1/projects/<project-id>/messages:send
```

Это выглядит длиннее, но у подхода нормальная security model: короткоживущий access token и service account на backend.

## Целевая структура после главы

```text
supabase/
  migrations/
    202605100001_create_push_tokens.sql
  functions/
    send-comment-push/
      index.ts

lib/
  firebase_options.dart
  src/
    app/
      bootstrap/
        bootstrap.dart
      app.dart
    features/
      notifications/
        data/
          repositories/
            supabase_push_tokens_repository.dart
          services/
            firebase_push_messaging_client.dart
            push_messaging_client.dart
        domain/
          entities/
            push_token_registration.dart
            push_permission_status.dart
          repositories/
            push_tokens_repository.dart
        presentation/
          controllers/
            push_notifications_controller.dart
          widgets/
            notification_status_tile.dart
```

## Практика

### Шаг 1. Подключить Firebase проект

В Firebase Console создай проект или используй существующий.

Для Android приложение должно совпадать с package name из проекта. Проверь:

```text
android/app/build.gradle.kts
```

Для iOS нужен bundle id из:

```text
ios/Runner.xcodeproj/project.pbxproj
```

Установи CLI:

```bash
dart pub global activate flutterfire_cli
```

Если Firebase CLI еще не установлен:

```bash
npm install -g firebase-tools
firebase login
```

Затем из корня проекта:

```bash
flutterfire configure
```

Выбери Android и iOS. Команда создаст:

```text
lib/firebase_options.dart
```

`firebase_options.dart` можно коммитить: это public app config, не service secret.

### Шаг 2. Добавить Flutter dependencies

Команда:

```bash
flutter pub add firebase_core firebase_messaging
```

После этого проверь `pubspec.yaml`. Там должны появиться:

```yaml
dependencies:
  firebase_core: ...
  firebase_messaging: ...
```

Не добавляй Firebase Admin SDK в Flutter app. Admin credentials живут только на backend.

### Шаг 3. Инициализировать Firebase в bootstrap

Файл:

```text
lib/src/app/bootstrap/bootstrap.dart
```

Добавь imports:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../firebase_options.dart';
```

Над `bootstrap()` добавь top-level handler:

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
```

Внутри `bootstrap()` после `WidgetsFlutterBinding.ensureInitialized()`:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
```

Итоговая последовательность:

```dart
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final config = await AppConfig.load();

  MapboxOptions.setAccessToken(config.mapboxAccessToken);

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const GeoMomentsApp(),
    ),
  );
}
```

Почему handler top-level: background isolate не может вызвать instance method widget-а.

Почему `@pragma('vm:entry-point')`: release tree shaking не должен удалить handler, который вызывается нативным кодом.

### Шаг 4. Добавить platform setup

Android после `flutterfire configure` обычно получает нужный Gradle setup автоматически. Проверь, что есть:

```text
android/app/google-services.json
```

Для Android 13+ permission `POST_NOTIFICATIONS` обычно добавляет Firebase Messaging plugin через manifest merge. Если notification permission не появляется в настройках приложения, добавь в:

```text
android/app/src/main/AndroidManifest.xml
```

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

iOS требует ручной настройки в Xcode:

1. Открыть `ios/Runner.xcworkspace`.
2. Runner -> Signing & Capabilities.
3. Добавить `Push Notifications`.
4. Добавить `Background Modes`.
5. Включить `Remote notifications`.
6. В Firebase Console загрузить APNs key.

На iOS push не проверяется полноценно на simulator. Нужен physical device.

### Шаг 5. Создать migration для push tokens

Файл:

```text
supabase/migrations/202605100001_create_push_tokens.sql
```

Код:

```sql
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (token)
);

create index if not exists push_tokens_user_id_idx
on public.push_tokens(user_id);

create trigger push_tokens_set_updated_at
before update on public.push_tokens
for each row execute function public.set_updated_at();

alter table public.push_tokens enable row level security;

drop policy if exists "push_tokens_select_own" on public.push_tokens;
create policy "push_tokens_select_own"
on public.push_tokens
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "push_tokens_insert_own" on public.push_tokens;
create policy "push_tokens_insert_own"
on public.push_tokens
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "push_tokens_update_own" on public.push_tokens;
create policy "push_tokens_update_own"
on public.push_tokens
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "push_tokens_delete_own" on public.push_tokens;
create policy "push_tokens_delete_own"
on public.push_tokens
for delete
to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.upsert_push_token(
  token_value text,
  token_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  insert into public.push_tokens (
    user_id,
    token,
    platform,
    last_seen_at
  )
  values (
    current_user_id,
    token_value,
    token_platform,
    now()
  )
  on conflict (token)
  do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    last_seen_at = now();
end;
$$;
```

Почему `unique(token)`: один FCM token не должен храниться дублями.

Почему `upsert_push_token` берет user из `auth.uid()`: Flutter не передает `user_id`, поэтому нельзя сохранить token от имени другого пользователя.

Почему `security definer`: FCM token может остаться тем же после logout/login на одном устройстве. Если token уже принадлежал старому user-а, обычный `security invoker` упрется в RLS update policy и не сможет перенести token на текущий аккаунт. Function все равно безопасна, потому что сама берет `current_user_id` из `auth.uid()` и не принимает `user_id` от клиента.

Применить:

```bash
npx supabase db push
```

### Шаг 6. Создать domain entities

Файл:

```text
lib/src/features/notifications/domain/entities/push_permission_status.dart
```

Код:

```dart
enum PushPermissionStatus {
  authorized,
  denied,
  notDetermined,
  provisional,
}
```

Файл:

```text
lib/src/features/notifications/domain/entities/push_token_registration.dart
```

Код:

```dart
class PushTokenRegistration {
  const PushTokenRegistration({
    required this.token,
    required this.platform,
  });

  final String token;
  final String platform;
}
```

Почему `platform` строка: Supabase check constraint принимает `'android'` или `'ios'`. Можно сделать enum, но строка здесь проще и ближе к database.

### Шаг 7. Создать repository interface

Файл:

```text
lib/src/features/notifications/domain/repositories/push_tokens_repository.dart
```

Код:

```dart
import '../entities/push_token_registration.dart';

abstract interface class PushTokensRepository {
  Future<void> upsertToken(PushTokenRegistration registration);
}
```

UI не должен знать, что token сохраняется через Supabase RPC.

### Шаг 8. Создать messaging client interface

Файл:

```text
lib/src/features/notifications/data/services/push_messaging_client.dart
```

Код:

```dart
import '../../domain/entities/push_permission_status.dart';

abstract interface class PushMessagingClient {
  Future<PushPermissionStatus> getPermissionStatus();

  Future<PushPermissionStatus> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;
}
```

Зачем interface: tests не должны обращаться к Firebase plugin. Как и с media picker, platform API прячем за маленьким wrapper-ом.

### Шаг 9. Реализовать Firebase messaging client

Файл:

```text
lib/src/features/notifications/data/services/firebase_push_messaging_client.dart
```

Код:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/entities/push_permission_status.dart';
import 'push_messaging_client.dart';

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  PushPermissionStatus _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) {
    return switch (status) {
      AuthorizationStatus.authorized => PushPermissionStatus.authorized,
      AuthorizationStatus.denied => PushPermissionStatus.denied,
      AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
      AuthorizationStatus.provisional => PushPermissionStatus.provisional,
    };
  }
}
```

Почему `getNotificationSettings()` отдельно: Settings screen может показать статус без повторного запроса permission.

### Шаг 10. Реализовать Supabase repository

Файл:

```text
lib/src/features/notifications/data/repositories/supabase_push_tokens_repository.dart
```

Код:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/push_token_registration.dart';
import '../../domain/repositories/push_tokens_repository.dart';

class SupabasePushTokensRepository implements PushTokensRepository {
  const SupabasePushTokensRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsertToken(PushTokenRegistration registration) async {
    await _client.rpc<void>(
      'upsert_push_token',
      params: {
        'token_value': registration.token,
        'token_platform': registration.platform,
      },
    );
  }
}
```

Не используем `.execute()`: в текущем Supabase Flutter коде проекта уже используется прямой `rpc(...)`.

### Шаг 11. Создать providers и controller

Файл:

```text
lib/src/features/notifications/presentation/controllers/push_notifications_controller.dart
```

Код:

```dart
import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/repositories/supabase_push_tokens_repository.dart';
import '../../data/services/firebase_push_messaging_client.dart';
import '../../data/services/push_messaging_client.dart';
import '../../domain/entities/push_permission_status.dart';
import '../../domain/entities/push_token_registration.dart';
import '../../domain/repositories/push_tokens_repository.dart';

final pushMessagingClientProvider = Provider<PushMessagingClient>((ref) {
  return FirebasePushMessagingClient(FirebaseMessaging.instance);
});

final pushTokensRepositoryProvider = Provider<PushTokensRepository>((ref) {
  return SupabasePushTokensRepository(ref.watch(supabaseClientProvider));
});

final pushNotificationsControllerProvider =
    AsyncNotifierProvider<PushNotificationsController, PushPermissionStatus>(
      PushNotificationsController.new,
    );

class PushNotificationsController
    extends AsyncNotifier<PushPermissionStatus> {
  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  Future<PushPermissionStatus> build() async {
    ref.onDispose(() {
      unawaited(_tokenRefreshSubscription?.cancel());
    });

    return ref.read(pushMessagingClientProvider).getPermissionStatus();
  }

  Future<void> requestAndRegister() async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(pushMessagingClientProvider);
      final status = await client.requestPermission();

      if (_canUseToken(status)) {
        await _registerCurrentToken(client);
        _listenForTokenRefresh(client);
      }

      return status;
    });
  }

  Future<void> registerIfAllowed() async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) {
      return;
    }

    final client = ref.read(pushMessagingClientProvider);
    final status = await client.getPermissionStatus();

    if (_canUseToken(status)) {
      await _registerCurrentToken(client);
      _listenForTokenRefresh(client);
    }

    state = AsyncData(status);
  }

  bool _canUseToken(PushPermissionStatus status) {
    return status == PushPermissionStatus.authorized ||
        status == PushPermissionStatus.provisional;
  }

  Future<void> _registerCurrentToken(PushMessagingClient client) async {
    final token = await client.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await ref.read(pushTokensRepositoryProvider).upsertToken(
          PushTokenRegistration(
            token: token,
            platform: _platform,
          ),
        );
  }

  void _listenForTokenRefresh(PushMessagingClient client) {
    _tokenRefreshSubscription ??= client.onTokenRefresh.listen((token) {
      unawaited(
        ref.read(pushTokensRepositoryProvider).upsertToken(
              PushTokenRegistration(
                token: token,
                platform: _platform,
              ),
            ),
      );
    });
  }

  String get _platform {
    if (Platform.isIOS) {
      return 'ios';
    }

    return 'android';
  }
}
```

Почему `registerIfAllowed` отдельно от `requestAndRegister`: при запуске приложения не нужно внезапно показывать permission dialog. Dialog показываем по действию пользователя в Settings. Если permission уже был выдан, token можно обновить тихо.

### Шаг 12. Добавить UI в Settings

Добавь строки локализации:

```json
"notificationsTitle": "Notifications",
"notificationsEnabled": "Notifications enabled",
"notificationsDisabled": "Notifications disabled",
"notificationsAsk": "Enable notifications",
"notificationsPermissionDenied": "Notifications are blocked in system settings."
```

RU:

```json
"notificationsTitle": "Уведомления",
"notificationsEnabled": "Уведомления включены",
"notificationsDisabled": "Уведомления выключены",
"notificationsAsk": "Включить уведомления",
"notificationsPermissionDenied": "Уведомления заблокированы в настройках системы."
```

ES:

```json
"notificationsTitle": "Notificaciones",
"notificationsEnabled": "Notificaciones activadas",
"notificationsDisabled": "Notificaciones desactivadas",
"notificationsAsk": "Activar notificaciones",
"notificationsPermissionDenied": "Las notificaciones están bloqueadas en los ajustes del sistema."
```

После ARB:

```bash
flutter gen-l10n
```

Файл:

```text
lib/src/features/notifications/presentation/widgets/notification_status_tile.dart
```

Код:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../domain/entities/push_permission_status.dart';
import '../controllers/push_notifications_controller.dart';

class NotificationStatusTile extends ConsumerWidget {
  const NotificationStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pushNotificationsControllerProvider);

    return state.when(
      loading: () => const ListTile(
        leading: CircularProgressIndicator(),
        title: Text(''),
      ),
      error: (_, _) => ListTile(
        leading: const Icon(Icons.notifications_off_outlined),
        title: Text(context.l10n.notificationsTitle),
        subtitle: Text(context.l10n.notificationsDisabled),
        trailing: IconButton(
          tooltip: context.l10n.retry,
          onPressed: () {
            ref
                .read(pushNotificationsControllerProvider.notifier)
                .requestAndRegister();
          },
          icon: const Icon(Icons.refresh_outlined),
        ),
      ),
      data: (status) {
        final enabled = status == PushPermissionStatus.authorized ||
            status == PushPermissionStatus.provisional;
        final denied = status == PushPermissionStatus.denied;

        return ListTile(
          leading: Icon(
            enabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
          ),
          title: Text(context.l10n.notificationsTitle),
          subtitle: Text(
            denied
                ? context.l10n.notificationsPermissionDenied
                : enabled
                    ? context.l10n.notificationsEnabled
                    : context.l10n.notificationsDisabled,
          ),
          trailing: enabled || denied
              ? null
              : TextButton(
                  onPressed: () {
                    ref
                        .read(pushNotificationsControllerProvider.notifier)
                        .requestAndRegister();
                  },
                  child: Text(context.l10n.notificationsAsk),
                ),
        );
      },
    );
  }
}
```

Файл:

```text
lib/src/features/settings/presentation/screens/settings_screen.dart
```

Добавь import:

```dart
import '../../../notifications/presentation/widgets/notification_status_tile.dart';
```

Settings сейчас использует `Column`. После добавления новых tiles лучше заменить content на `ListView`, чтобы экран не ломался на маленьких устройствах:

```dart
body: SafeArea(
  child: ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      Text(context.l10n.themeSettingTitle),
      const SizedBox(height: AppSpacing.sm),
      const ThemeModeSelector(),
      const SizedBox(height: AppSpacing.lg),
      Text(context.l10n.languageSettingTitle),
      const SizedBox(height: AppSpacing.sm),
      const LocaleSelector(),
      const SizedBox(height: AppSpacing.lg),
      const NotificationStatusTile(),
      const SizedBox(height: AppSpacing.lg),
      const BackendStatusTile(),
      const SizedBox(height: AppSpacing.lg),
      CurrentUserTile(),
      OutlinedButton.icon(
        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
        icon: const Icon(Icons.logout_outlined),
        label: Text(context.l10n.signOut),
      ),
    ],
  ),
),
```

Почему это важно: в прошлых главах widget tests уже падали из-за scrollable content. Settings тоже должен быть устойчивым к росту content-а.

### Шаг 13. Автоматически регистрировать token после входа

Файл:

```text
lib/src/app/app.dart
```

`GeoMomentsApp` сейчас `ConsumerWidget`. Преврати его в `ConsumerStatefulWidget`, чтобы подписаться на auth state и notification taps.

Imports:

```dart
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../features/auth/presentation/controllers/auth_providers.dart';
import '../features/notifications/presentation/controllers/push_notifications_controller.dart';
```

Skeleton:

```dart
class GeoMomentsApp extends ConsumerStatefulWidget {
  const GeoMomentsApp({super.key});

  @override
  ConsumerState<GeoMomentsApp> createState() => _GeoMomentsAppState();
}

class _GeoMomentsAppState extends ConsumerState<GeoMomentsApp> {
  StreamSubscription<RemoteMessage>? _openedSubscription;

  @override
  void initState() {
    super.initState();

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );

    unawaited(_openInitialMessage());
  }

  @override
  void dispose() {
    unawaited(_openedSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          unawaited(
            ref
                .read(pushNotificationsControllerProvider.notifier)
                .registerIfAllowed(),
          );
        }
      });
    });

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final localePreference = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localePreference.locale,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }

  Future<void> _openInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      _openMessage(message);
    }
  }

  void _openMessage(RemoteMessage message) {
    final momentId = message.data['moment_id'];
    if (momentId is! String || momentId.isEmpty) {
      return;
    }

    ref.read(appRouterProvider).push(AppRoutePaths.momentDetails(momentId));
  }
}
```

Почему обрабатываем и `getInitialMessage`, и `onMessageOpenedApp`: первое покрывает terminated state, второе - background state.

Ограничение MVP: если пользователь signed out, router отправит его на auth. Сохранение pending notification intent после login можно улучшить в главе 14.

### Шаг 14. Создать Edge Function

Файл:

```text
supabase/functions/send-comment-push/index.ts
```

Код:

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

type CommentRecord = {
  id: string;
  moment_id: string;
  author_id: string;
  parent_id: string | null;
  body: string;
};

type WebhookPayload = {
  type: "INSERT";
  table: "moment_comments";
  schema: "public";
  record: CommentRecord;
};

type FirebaseServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const webhookSecret = Deno.env.get("COMMENT_PUSH_WEBHOOK_SECRET")!;
const firebaseServiceAccountJson = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_JSON",
)!;

const supabase = createClient(supabaseUrl, serviceRoleKey);
const firebaseServiceAccount = JSON.parse(
  firebaseServiceAccountJson,
) as FirebaseServiceAccount;

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== webhookSecret) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = await req.json() as WebhookPayload;
  const comment = payload.record;

  const recipientUserId = await findRecipientUserId(comment);
  if (recipientUserId === null || recipientUserId === comment.author_id) {
    return Response.json({ sent: 0 });
  }

  const { data: tokens, error } = await supabase
    .from("push_tokens")
    .select("token")
    .eq("user_id", recipientUserId);

  if (error) {
    throw error;
  }

  if (!tokens || tokens.length === 0) {
    return Response.json({ sent: 0 });
  }

  const accessToken = await getFirebaseAccessToken();
  const title = comment.parent_id === null
    ? "New comment"
    : "New reply";
  const body = trimNotificationBody(comment.body);

  const results = await Promise.allSettled(
    tokens.map(({ token }) =>
      sendFcmMessage({
        accessToken,
        token,
        title,
        body,
        data: {
          type: comment.parent_id === null ? "moment_comment" : "moment_reply",
          moment_id: comment.moment_id,
          comment_id: comment.id,
        },
      })
    ),
  );

  return Response.json({
    sent: results.filter((result) => result.status === "fulfilled").length,
    failed: results.filter((result) => result.status === "rejected").length,
  });
});

async function findRecipientUserId(
  comment: CommentRecord,
): Promise<string | null> {
  if (comment.parent_id !== null) {
    const { data: parent, error } = await supabase
      .from("moment_comments")
      .select("author_id")
      .eq("id", comment.parent_id)
      .single();

    if (error) {
      throw error;
    }

    return parent.author_id as string;
  }

  const { data: moment, error } = await supabase
    .from("moments")
    .select("author_id")
    .eq("id", comment.moment_id)
    .single();

  if (error) {
    throw error;
  }

  return moment.author_id as string;
}

function trimNotificationBody(body: string): string {
  const trimmed = body.trim();
  if (trimmed.length <= 120) {
    return trimmed;
  }

  return `${trimmed.substring(0, 117)}...`;
}

async function getFirebaseAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const key = await importPrivateKey(firebaseServiceAccount.private_key);
  const assertion = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: firebaseServiceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: getNumericDate(60 * 60),
    },
    key,
  );

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(await response.text());
  }

  const json = await response.json() as { access_token: string };
  return json.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\\n", "")
    .replaceAll("\n", "")
    .trim();
  const binary = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    binary,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
}

async function sendFcmMessage({
  accessToken,
  token,
  title,
  body,
  data,
}: {
  accessToken: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseServiceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title,
            body,
          },
          data,
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(await response.text());
  }
}
```

Почему function использует `service_role`: она должна читать tokens другого пользователя. Этот ключ живет только в Supabase secrets, не в клиенте.

Почему есть `x-webhook-secret`: function будет deployed без JWT verification для database webhook-а, поэтому нужен отдельный shared secret.

### Шаг 15. Добавить Supabase secrets и deploy function

Сгенерируй secret:

```bash
openssl rand -hex 32
```

Если `openssl` на Windows не установлен, используй PowerShell:

```powershell
$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
```

Сохрани secrets:

```bash
npx supabase secrets set COMMENT_PUSH_WEBHOOK_SECRET=your-random-secret
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

На Windows PowerShell удобнее положить service account JSON в файл вне репозитория и передать:

```powershell
$json = Get-Content C:\tmp\firebase-service-account.json -Raw
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$json"
```

Не клади service account JSON в проект.

Deploy:

```bash
npx supabase functions deploy send-comment-push --no-verify-jwt
```

`--no-verify-jwt` допустим здесь только потому, что function сама проверяет `x-webhook-secret`.

### Шаг 16. Создать Database Webhook

В Supabase Dashboard:

```text
Database -> Webhooks -> Create webhook
```

Настройки:

```text
Table: public.moment_comments
Events: Insert
Type: HTTP Request
Method: POST
URL: https://<project-ref>.supabase.co/functions/v1/send-comment-push
Headers:
  x-webhook-secret: <COMMENT_PUSH_WEBHOOK_SECRET>
```

Это не migration, потому что database webhook часто удобнее настраивать в Dashboard. В production можно автоматизировать через Supabase management tooling, но для курса достаточно Dashboard setup.

### Шаг 17. Тестировать controller без Firebase

Файл:

```text
test/push_notifications_controller_test.dart
```

Проверить:

- fake messaging client реально используется через provider override;
- permission request сохраняет token;
- denied permission не сохраняет token;
- token refresh вызывает repository.

Скелет:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:geo_moments/src/features/auth/presentation/controllers/auth_providers.dart';
import 'package:geo_moments/src/features/notifications/data/services/push_messaging_client.dart';
import 'package:geo_moments/src/features/notifications/domain/entities/push_permission_status.dart';
import 'package:geo_moments/src/features/notifications/domain/entities/push_token_registration.dart';
import 'package:geo_moments/src/features/notifications/domain/repositories/push_tokens_repository.dart';
import 'package:geo_moments/src/features/notifications/presentation/controllers/push_notifications_controller.dart';

void main() {
  test('requestAndRegister stores token when permission is authorized', () async {
    final messaging = FakePushMessagingClient(
      permissionStatus: PushPermissionStatus.authorized,
      token: 'fcm-token',
    );
    final repository = FakePushTokensRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(id: 'user-id', email: 'test@example.com'),
          ),
        ),
        pushMessagingClientProvider.overrideWithValue(messaging),
        pushTokensRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(pushNotificationsControllerProvider.notifier)
        .requestAndRegister();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.token, 'fcm-token');
  });
}

class FakePushMessagingClient implements PushMessagingClient {
  FakePushMessagingClient({
    required this.permissionStatus,
    required this.token,
  });

  final PushPermissionStatus permissionStatus;
  final String? token;
  final _tokenRefreshController = StreamController<String>();

  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    return permissionStatus;
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    return permissionStatus;
  }

  @override
  Future<String?> getToken() async {
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;
}

class FakePushTokensRepository implements PushTokensRepository {
  final saved = <PushTokenRegistration>[];

  @override
  Future<void> upsertToken(PushTokenRegistration registration) async {
    saved.add(registration);
  }
}
```

Не тестируй Firebase plugin напрямую в unit tests. Плагин проверяется ручным устройством или integration-тестом.

## Проверка

Команды:

```bash
flutterfire configure
flutter pub add firebase_core firebase_messaging
npx supabase db push
npx supabase functions deploy send-comment-push --no-verify-jwt
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

Ручная проверка Android:

1. Установить приложение на устройство или emulator с Google Play services.
2. Войти в аккаунт.
3. Открыть Settings.
4. Нажать `Enable notifications`.
5. Проверить в Supabase `push_tokens`, что появилась строка текущего пользователя.
6. Открыть тот же moment под другим пользователем или через второй клиент.
7. Добавить comment к moment-у первого пользователя.
8. Свернуть приложение первого пользователя.
9. Убедиться, что пришел push.
10. Нажать push.
11. Убедиться, что открылся details нужного moment.

Ручная проверка iOS:

1. Проверять на physical device.
2. Убедиться, что APNs key загружен в Firebase Console.
3. Убедиться, что Xcode capabilities включены.
4. Повторить сценарий Android.

Supabase проверка:

1. `push_tokens` содержит token только для текущего user-а.
2. RLS не дает читать чужие tokens через anon/authenticated client.
3. Edge Function logs показывают webhook вызов.
4. FCM response success при валидном token.

## Частые ошибки

### Ошибка: token не сохраняется

Проверь:

- пользователь signed in;
- permission `authorized` или `provisional`;
- `Firebase.initializeApp` вызван до `FirebaseMessaging.instance`;
- migration `push_tokens` применена;
- `upsert_push_token` существует в Supabase.

### Ошибка: Android 13 не показывает notifications

Причина: permission не выдан.

Проверь `requestPermission()` и `POST_NOTIFICATIONS` в manifest merge.

### Ошибка: iOS не получает push

Проверь:

- physical device, не simulator;
- APNs key загружен в Firebase Console;
- Push Notifications capability включен;
- Background Modes -> Remote notifications включен;
- bundle id совпадает с Firebase app.

### Ошибка: Edge Function получает 401

Причина: webhook secret не совпадает.

Проверь header:

```text
x-webhook-secret: <COMMENT_PUSH_WEBHOOK_SECRET>
```

### Ошибка: FCM возвращает auth error

Проверь:

- `FIREBASE_SERVICE_ACCOUNT_JSON` сохранен без обрезания переносов строк;
- service account относится к тому же Firebase project;
- используется FCM HTTP v1 endpoint;
- Cloud Messaging API включен в Google Cloud project.

### Ошибка: tap по push открывает приложение, но не details

Проверь data payload:

```json
{
  "moment_id": "..."
}
```

И обработчики:

```dart
FirebaseMessaging.instance.getInitialMessage()
FirebaseMessaging.onMessageOpenedApp.listen(...)
```

### Ошибка: Settings test начал overflow-иться

Settings должен быть `ListView`, а не растущий `Column` без scroll.

### Ошибка: fake messaging client создан, но тест ходит в Firebase

Проверь provider override:

```dart
pushMessagingClientProvider.overrideWithValue(fakeMessaging)
```

Fake class должен реально использоваться в тесте, как в главах 10-12.

## Definition of Done

- Firebase project подключен через FlutterFire CLI.
- `firebase_core` и `firebase_messaging` добавлены.
- `Firebase.initializeApp` вызывается в bootstrap.
- Background message handler top-level и помечен `@pragma('vm:entry-point')`.
- Android/iOS platform setup выполнен.
- `push_tokens` table создана.
- RLS разрешает пользователю читать/писать только свои tokens.
- RPC `upsert_push_token` берет user из `auth.uid()`.
- Firebase Messaging спрятан за `PushMessagingClient`.
- Supabase token save спрятан за `PushTokensRepository`.
- `PushNotificationsController` запрашивает permission, сохраняет token и слушает token refresh.
- Settings показывает notification status и action.
- Settings scrollable.
- Edge Function `send-comment-push` отправляет FCM HTTP v1 message.
- Service account JSON хранится только в Supabase secrets.
- Database webhook на `moment_comments insert` вызывает Edge Function.
- Notification payload содержит `moment_id`.
- Tap по notification открывает details route.
- Tests используют fake messaging client и fake repository через provider overrides.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка push на устройстве выполнена.

## Что прислать на ревью

После реализации напиши:

```text
Глава 13 готова, проверь код.
```

Я буду проверять:

- что Firebase service account не попал в репозиторий;
- что Flutter app не знает service role key;
- что permission dialog не появляется неожиданно при старте;
- что token сохраняется только для authenticated user;
- что token refresh не течет после dispose;
- что push на свой собственный comment не отправляется;
- что root comment и reply выбирают правильного recipient-а;
- что notification tap открывает `/moments/:momentId`;
- что Settings не overflow-ится на маленьком экране;
- что fake classes реально используются в tests;
- что comments/replies главы 12 не сломаны;
- что `/moments/new` остается выше `/moments/:momentId`.
