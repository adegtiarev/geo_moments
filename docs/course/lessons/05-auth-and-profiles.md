# 05 Auth and Profiles

Статус: next.

## Источники

Эта глава опирается на актуальные Supabase docs:

- [Flutter OAuth sign-in](https://supabase.com/docs/reference/dart/auth-signinwithoauth)
- [Auth state changes](https://supabase.com/docs/reference/dart/auth-onauthstatechange)
- [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)
- [Google social login](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Apple social login](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Sign out](https://supabase.com/docs/reference/dart/auth-signout)

## Что строим в этой главе

Добавляем первый настоящий auth flow:

- auth state stream через Supabase;
- `AuthScreen`;
- вход через Google OAuth;
- подготовка Apple OAuth для iOS;
- auth gate в `go_router`;
- sign out;
- отображение текущего пользователя в Settings;
- базовая domain model `AppUser`;
- первый шаг к профилям пользователей.

После главы приложение будет открывать карту только для authenticated user. Если сессии нет, пользователь увидит экран входа.

## Почему это важно

До этой главы приложение было UI-shell с Supabase client. Теперь появляется первое состояние, которое реально управляет доступом к приложению.

Auth - это место, где легко сделать архитектурный долг:

- дергать `Supabase.instance.client.auth` прямо из widgets;
- вручную прокидывать user через constructors;
- проверять сессию только один раз на старте;
- забыть обработать sign out;
- не учесть восстановление сессии после перезапуска приложения.

Мы сделаем auth как отдельную feature:

```text
Supabase Auth stream
  -> AuthRepository
  -> Riverpod providers
  -> Router redirect
  -> UI
```

UI будет вызывать use-case-like методы `signInWithGoogle`, `signInWithApple`, `signOut`, но не будет знать детали Supabase OAuth.

## Словарь главы

`Session` - Supabase object с access/refresh token и user.

`User` - Supabase auth user. Это не то же самое, что наш публичный profile.

`OAuth` - вход через внешнего провайдера: Google, Apple и т.д.

`redirectTo` - deeplink URL, куда провайдер вернет пользователя после логина.

`auth state stream` - поток событий авторизации: initial session, signed in, signed out, token refreshed.

`auth gate` - логика router-а, которая решает, можно ли открыть protected route.

`profile` - наша доменная сущность пользователя в Postgres. В этой главе мы готовим модель и UI, а полноценную таблицу/trigger сделаем в следующей backend-главе.

## 1. Supabase Auth flow в Flutter

Минимальный OAuth-вход в Supabase Flutter выглядит так:

```dart
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'io.supabase.geomoments://login-callback/',
);
```

Что происходит:

1. Приложение открывает web auth flow.
2. Пользователь входит через Google.
3. Google возвращает пользователя в Supabase.
4. Supabase создает/обновляет auth user.
5. Supabase редиректит обратно в приложение через `redirectTo`.
6. `supabase_flutter` восстанавливает session.
7. `onAuthStateChange` сообщает приложению `signedIn`.

Для sign out:

```dart
await supabase.auth.signOut();
```

После этого auth stream отдаст `signedOut`, router должен вернуть пользователя на `/auth`.

## 2. OAuth vs native sign-in

Supabase поддерживает два подхода.

OAuth flow:

```dart
supabase.auth.signInWithOAuth(OAuthProvider.google)
```

Native sign-in with ID token:

```dart
supabase.auth.signInWithIdToken(...)
```

Native flow полезен, когда нужен максимально нативный Google/Apple SDK experience. Но он требует дополнительных пакетов, client IDs, nonce для Apple, больше platform setup.

Для нашего курса на этой стадии выбираем OAuth flow:

- меньше кода;
- быстрее получить работающий auth gate;
- достаточно для портфолио MVP;
- позже можно заменить на native sign-in без переписывания UI, если repository interface сохранится.

Важно: для Apple OAuth Supabase docs отмечают, что full name в OAuth flow обычно не доступен так же удобно, как при native Apple sign-in. Поэтому в профиле мы должны быть готовы к пустому display name и позже добавить edit profile/onboarding.

## 3. Redirect URLs

Supabase Auth проверяет redirect URL. Если приложение передаст `redirectTo`, он должен быть разрешен в dashboard.

В Supabase:

```text
Authentication -> URL Configuration -> Redirect URLs
```

Для dev добавим:

```text
io.supabase.geomoments://login-callback/
```

Этот URL потом используем в коде:

```dart
const authRedirectUrl = 'io.supabase.geomoments://login-callback/';
```

Почему custom scheme:

- мобильному приложению нужен deeplink;
- Android/iOS должны понять, что этот callback принадлежит нашему app;
- позже можно заменить scheme на bundle/application id style.

В production нужно будет аккуратно согласовать:

- Android package name;
- iOS bundle id;
- associated domains/universal links, если выберем их;
- Supabase redirect allow list.

В этой главе используем custom scheme как учебный вариант.

## 4. Platform deep link setup

`redirectTo` сам по себе не магия. Нужно, чтобы Android/iOS открывали приложение по схеме.

Android: в `android/app/src/main/AndroidManifest.xml` добавляется intent-filter для callback activity.

Идея:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />

    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />

    <data
        android:scheme="io.supabase.geomoments"
        android:host="login-callback" />
</intent-filter>
```

iOS: в `ios/Runner/Info.plist` добавляется URL type scheme:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>io.supabase.geomoments</string>
    </array>
  </dict>
</array>
```

Если deep link не настроен, пользователь успешно войдет в браузере, но приложение не получит session.

## 5. Auth state stream

Supabase дает поток:

```dart
supabase.auth.onAuthStateChange
```

Он сообщает события:

- initial session;
- signed in;
- signed out;
- token refreshed;
- user updated;
- user deleted;
- password recovery;
- MFA challenge verified.

В Riverpod удобно сделать:

```dart
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});
```

Но UI обычно не хочет работать с Supabase `AuthState` напрямую. Для приложения удобнее иметь `AppUser?`.

```dart
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return client.auth.onAuthStateChange.map((authState) {
    final user = authState.session?.user;
    return user == null ? null : AppUser.fromSupabaseUser(user);
  });
});
```

Нужно также помнить про `currentUser/currentSession` на старте. Supabase stream отправляет `initialSession`, но в некоторых местах для sync checks полезно использовать:

```dart
supabase.auth.currentUser
supabase.auth.currentSession
```

## 6. Domain entity `AppUser`

Supabase `User` - это SDK model. Не надо тащить его во все UI слои.

Сделаем свою минимальную модель:

```dart
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
}
```

Почему это полезно:

- UI не зависит от Supabase SDK model;
- позже добавим Postgres profile fields;
- тесты проще;
- можно менять provider implementation без переписывания экранов.

## 7. Auth repository

Repository прячет Supabase SDK:

```dart
abstract interface class AuthRepository {
  Stream<AppUser?> watchCurrentUser();
  AppUser? get currentUser;
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signOut();
}
```

Implementation:

```dart
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _client.auth.onAuthStateChange.map((state) {
      return _mapUser(state.session?.user);
    });
  }

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);
}
```

Зачем interface:

- позже widget tests смогут подменять fake auth repository;
- UI и router не завязаны на Supabase напрямую;
- это тренирует clean architecture без перегиба.

## 8. Auth controller

Для кнопок входа нужен controller:

```dart
final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).signInWithGoogle();
    });
  }
}
```

Почему `AsyncNotifier<void>`:

- кнопке нужен loading/error state;
- результатом action является side effect: browser/deeplink/session;
- user state придет через auth stream.

## 9. Auth gate в router

Сейчас router всегда открывает `/`.

Нужно добавить:

```text
/auth
/
/settings
```

Правило:

- если user == null и route не `/auth`, отправить на `/auth`;
- если user != null и route `/auth`, отправить на `/`;
- иначе ничего не менять.

С `go_router` redirect обычно выглядит так:

```dart
redirect: (context, state) {
  final isSignedIn = ...
  final isAuthRoute = state.matchedLocation == AppRoutePaths.auth;

  if (!isSignedIn && !isAuthRoute) {
    return AppRoutePaths.auth;
  }

  if (isSignedIn && isAuthRoute) {
    return AppRoutePaths.map;
  }

  return null;
}
```

Тонкий момент: `StreamProvider` имеет loading state. На старте нельзя агрессивно редиректить, пока мы не поняли session. Чтобы не усложнять, добавим `/auth` как стартовый экран при no user, и будем использовать `currentUserProvider` с `AsyncValue`.

Если `currentUserProvider` в loading, можно показывать `SplashScreen` или временно не редиректить. В этой главе сделаем простой `SplashScreen`.

## 10. Что такое profile в этой главе

Пока у нас нет таблицы `profiles`. Значит, "profile" в этой главе - это auth profile из provider metadata:

- id;
- email;
- display name из metadata, если есть;
- avatar URL из metadata, если есть.

Полноценный Postgres `profiles` сделаем в главе 6 вместе со schema/RLS.

Тогда появится:

```text
auth.users -> public.profiles
```

и отдельный `ProfileRepository`.

## Практика

### Шаг 1. Настроить Supabase redirect URL

В Supabase dashboard:

```text
Authentication -> URL Configuration -> Redirect URLs
```

Добавь:

```text
io.supabase.geomoments://login-callback/
```

Site URL для dev можно временно оставить стандартным, но redirect URL должен быть добавлен явно.

### Шаг 2. Включить Google provider

В Supabase dashboard:

```text
Authentication -> Providers -> Google
```

Для настоящего входа понадобится Google Cloud OAuth setup:

- Google Cloud project;
- OAuth consent screen;
- OAuth client credentials;
- callback URL из Supabase Google provider screen.

Supabase Google docs показывают, что provider настраивается через Google Auth Platform и Supabase dashboard.

Если сейчас не хочешь тратить время на Google Cloud настройку, можешь сделать код и UI, а реальный ручной sign-in проверить позже. Но глава считается полностью выполненной только после manual sign-in.

### Шаг 3. Подготовить Apple provider

В Supabase:

```text
Authentication -> Providers -> Apple
```

Для Apple нужны Apple Developer настройки. На Windows без iOS device/simulator это обычно невозможно полноценно проверить прямо сейчас.

В этой главе:

- кодовую ветку Apple добавим;
- кнопку покажем только на iOS/macOS или отключенной на других платформах;
- полную проверку Apple оставим на этап iOS release/auth polishing.

### Шаг 4. Добавить redirect config

В `.env.example`:

```text
AUTH_REDIRECT_URL=io.supabase.geomoments://login-callback/
```

В локальный `.env` добавь такое же значение.

В `AppConfig`:

```dart
final String authRedirectUrl;
```

И в `load()`:

```dart
final authRedirectUrl = _requiredEnv('AUTH_REDIRECT_URL');
```

Можно валидировать через `Uri.tryParse`, но custom scheme не имеет https-схемы. Проверяем, что есть scheme и host.

### Шаг 5. Android deep link

В `android/app/src/main/AndroidManifest.xml` внутри main activity добавь intent-filter:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="io.supabase.geomoments"
        android:host="login-callback" />
</intent-filter>
```

Проверь, что это внутри activity, а не рядом с application.

### Шаг 6. iOS URL scheme

В `ios/Runner/Info.plist` добавь:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>io.supabase.geomoments</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>io.supabase.geomoments</string>
    </array>
  </dict>
</array>
```

Если в `Info.plist` уже есть `CFBundleURLTypes`, не создавай второй ключ. Добавь новый dict в существующий array.

### Шаг 7. Создать domain user

Файл:

```text
lib/src/features/auth/domain/entities/app_user.dart
```

Код:

```dart
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  String get bestDisplayName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final emailValue = email?.trim();
    if (emailValue != null && emailValue.isNotEmpty) {
      return emailValue;
    }

    return 'Geo Moments user';
  }
}
```

Позже `bestDisplayName` локализуем или вынесем в presentation, если потребуется.

### Шаг 8. Создать auth repository interface

Файл:

```text
lib/src/features/auth/domain/repositories/auth_repository.dart
```

Код:

```dart
import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> watchCurrentUser();
  AppUser? get currentUser;
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signOut();
}
```

### Шаг 9. Создать Supabase implementation

Файл:

```text
lib/src/features/auth/data/repositories/supabase_auth_repository.dart
```

Код:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_config.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository({
    required SupabaseClient client,
    required AppConfig config,
  })  : _client = client,
        _config = config;

  final SupabaseClient _client;
  final AppConfig _config;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _client.auth.onAuthStateChange.map((state) {
      return _mapUser(state.session?.user);
    });
  }

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _config.authRedirectUrl,
    );
  }

  @override
  Future<void> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _config.authRedirectUrl,
    );
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  AppUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};

    return AppUser(
      id: user.id,
      email: user.email,
      displayName: metadata['full_name'] as String? ??
          metadata['name'] as String? ??
          metadata['user_name'] as String?,
      avatarUrl: metadata['avatar_url'] as String? ??
          metadata['picture'] as String?,
    );
  }
}
```

Если Dart analyzer ругается на `??` с casts, перепиши аккуратнее через helper:

```dart
String? _metadataString(Map<String, dynamic> metadata, String key) {
  final value = metadata[key];
  return value is String ? value : null;
}
```

### Шаг 10. Создать auth providers

Файл:

```text
lib/src/features/auth/presentation/controllers/auth_providers.dart
```

Код:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/backend/supabase_client_provider.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    client: ref.watch(supabaseClientProvider),
    config: ref.watch(appConfigProvider),
  );
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.watchCurrentUser();
});
```

### Шаг 11. Создать auth controller

В тот же файл или рядом:

```dart
final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithApple(),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}
```

### Шаг 12. Создать AuthScreen

Файл:

```text
lib/src/features/auth/presentation/screens/auth_screen.dart
```

Минимальный UI:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../controllers/auth_providers.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAction = ref.watch(authControllerProvider);
    final isLoading = authAction.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.appTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                    icon: const Icon(Icons.login_outlined),
                    label: Text(context.l10n.signInWithGoogle),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithApple(),
                    icon: const Icon(Icons.login_outlined),
                    label: Text(context.l10n.signInWithApple),
                  ),
                  if (authAction.hasError) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.authErrorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Добавь строки в ARB:

```json
"signInWithGoogle": "Continue with Google",
"signInWithApple": "Continue with Apple",
"authErrorMessage": "Could not complete sign in. Try again."
```

И переводы RU/ES.

### Шаг 13. Добавить SplashScreen

Файл:

```text
lib/src/app/router/splash_screen.dart
```

Код:

```dart
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```

### Шаг 14. Обновить router

Добавить routes:

```dart
abstract final class AppRoutePaths {
  static const splash = '/splash';
  static const auth = '/auth';
  static const map = '/';
  static const settings = '/settings';
}
```

Router должен читать `currentUserProvider`.

Упрощенная версия:

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: AppRoutePaths.splash,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthRoute = location == AppRoutePaths.auth;
      final isSplashRoute = location == AppRoutePaths.splash;

      return currentUser.when(
        loading: () => isSplashRoute ? null : AppRoutePaths.splash,
        error: (_, _) => isAuthRoute ? null : AppRoutePaths.auth,
        data: (user) {
          final isSignedIn = user != null;

          if (!isSignedIn) {
            return isAuthRoute ? null : AppRoutePaths.auth;
          }

          if (isAuthRoute || isSplashRoute) {
            return AppRoutePaths.map;
          }

          return null;
        },
      );
    },
    routes: [
      GoRoute(
        path: AppRoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      ...
    ],
  );
});
```

Если router не реагирует на stream updates, мы в следующем ревью добавим `refreshListenable`. Для учебной главы можно сначала реализовать простой вариант, а потом проверить вручную. Если после sign-in route не меняется сам, это будет полезный повод разобрать связку `go_router + Riverpod`.

### Шаг 15. User section в Settings

Добавь widget:

```text
lib/src/features/settings/presentation/widgets/current_user_tile.dart
```

Идея:

```dart
class CurrentUserTile extends ConsumerWidget {
  const CurrentUserTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(user?.bestDisplayName ?? context.l10n.unknownUser),
      subtitle: Text(user?.email ?? user?.id ?? ''),
    );
  }
}
```

Добавь строку:

```json
"unknownUser": "Unknown user"
```

### Шаг 16. Sign out button

В Settings добавь кнопку:

```dart
OutlinedButton.icon(
  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
  icon: const Icon(Icons.logout_outlined),
  label: Text(context.l10n.signOut),
)
```

`SettingsScreen` станет `ConsumerWidget`, потому что ему нужен `ref`.

Добавь строку:

```json
"signOut": "Sign out"
```

### Шаг 17. Обновить tests

Текущие tests теперь не смогут просто открыть map, если auth gate видит no user. Нужно сделать fake auth provider override.

Минимально:

```dart
final testUser = AppUser(
  id: 'test-user-id',
  email: 'test@example.com',
  displayName: 'Test User',
);
```

И в `ProviderScope`:

```dart
overrides: [
  appConfigProvider.overrideWithValue(testAppConfig),
  currentUserProvider.overrideWith(
    (ref) => Stream.value(testUser),
  ),
]
```

Добавь отдельный тест:

```dart
testWidgets('shows auth screen when signed out', (tester) async {
  await tester.pumpWidget(
    buildTestApp(currentUser: null),
  );
  await tester.pumpAndSettle();

  expect(find.text('Continue with Google'), findsOneWidget);
});
```

Если `StreamProvider.overrideWith` API отличается в твоей версии Riverpod, можно использовать `overrideWithValue(AsyncValue.data(testUser))` для provider state. Посмотрим по analyzer.

## Проверка

Команды:

```bash
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

Ручная проверка:

1. Удалить app data или sign out.
2. Запустить приложение.
3. Увидеть Auth screen.
4. Нажать Continue with Google.
5. Пройти OAuth.
6. Вернуться в приложение.
7. Увидеть карту.
8. Открыть Settings.
9. Увидеть текущего пользователя.
10. Нажать Sign out.
11. Вернуться на Auth screen.

Apple:

- на Android кнопка Apple может быть скрыта или disabled;
- на iOS проверить позже на macOS/iPhone, когда будет готов Apple Developer setup.

## Частые ошибки

### Ошибка: после OAuth браузер не возвращает в приложение

Причины:

- redirect URL не добавлен в Supabase URL Configuration;
- Android intent-filter не настроен;
- iOS URL scheme не настроен;
- `redirectTo` в коде отличается от dashboard.

Проверить строку буквально:

```text
io.supabase.geomoments://login-callback/
```

### Ошибка: sign-in проходит, но router остается на Auth screen

Причина: router не refresh-ится при изменении auth stream.

Решение: добавить refresh bridge для GoRouter. Это разберем при ревью, если столкнемся. Важно понять саму проблему: router должен узнать, что auth state изменился.

### Ошибка: тесты показывают Auth screen вместо Map

Причина: в тесте нет override для `currentUserProvider`.

Решение: подставить fake signed-in user.

### Ошибка: Apple не возвращает имя пользователя

Для OAuth flow это ожидаемый edge case. Apple full name доступен ограниченно, часто только при native flow и первом входе. Для MVP учитываем nullable `displayName`.

### Ошибка: service role key в app

Нельзя. В мобильном приложении только publishable/anon key.

## Definition of Done

- Redirect URL добавлен в Supabase dashboard.
- Google provider включен и настроен настолько, насколько нужно для dev sign-in.
- `AUTH_REDIRECT_URL` добавлен в `.env.example` и локальный `.env`.
- Android intent-filter добавлен.
- iOS URL scheme добавлен.
- Создана `AppUser` domain entity.
- Создан `AuthRepository` interface.
- Создан `SupabaseAuthRepository`.
- Созданы auth providers/controller.
- Создан `AuthScreen`.
- Router имеет auth gate.
- Settings показывает текущего пользователя и sign out.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка Google sign-in/sign-out выполнена или явно зафиксировано, что Google Cloud credentials еще не готовы.

## Что я буду проверять в ревью

- Нет ли Supabase auth calls прямо в widgets.
- Не сломан ли router при loading/error auth state.
- Не попали ли OAuth secrets в Git.
- Не используется ли service role key.
- Корректно ли настроены redirect URLs.
- Тесты не зависят от реального Supabase.
- `AppUser` не тащит SDK model в UI.

Когда закончишь, напиши:

```text
Глава 5 готова, проверь код.
```

