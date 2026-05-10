# 18 Release Preparation

Статус: draft.

## Что строим

В главе 17 мы сделали quality gate: вынесли test helpers, усилили regression tests, добавили README с командами проверки и зафиксировали, что проект проходит `analyze`/`test`.

В главе 18 подготовим Geo Moments как release-ready portfolio MVP:

- добавим launcher icon и splash screen;
- настроим Android release signing без попадания секретов в Git;
- соберем Android App Bundle (`.aab`) и release APK для ручной проверки;
- зафиксируем iOS release checklist без попытки собрать IPA на Windows;
- уточним env/build strategy для production;
- доведем README до portfolio-уровня;
- проверим, что release-подготовка не ломает route order, offline cache, push routing, compact/wide layout и tests.

Это последняя глава курса. После нее проект не обязан быть опубликован в stores, но должен быть подготовлен так, чтобы публикация была понятным операционным шагом, а не новым архитектурным проектом.

## Почему это важно

До этого момента мы строили features. Release preparation проверяет другой слой качества:

```text
работает в debug
  !=
готово к сборке и демонстрации
```

Debug-сборка может использовать debug signing, placeholder icon, локальный `.env`, неполный README и ручные знания, которые живут только в голове разработчика. Release-ready проект должен быть воспроизводимым:

```text
новый разработчик
  -> читает README
  -> создает .env
  -> запускает quality gate
  -> собирает release artifact
  -> понимает, какие секреты не коммитить
```

В Android-опыте это похоже на переход от "запускается из Android Studio" к "есть signed bundle, versionCode, Play Console checklist и понятные release notes". Во Flutter добавляются свои детали: `pubspec.yaml` version, generated icons/splash, platform-specific signing и разные команды `flutter build`.

## Словарь главы

`Release build` - оптимизированная сборка без debug overhead. Во Flutter это `flutter build ...`.

`App Bundle` (`.aab`) - preferred формат для Google Play. Play Store сам генерирует APK под устройства пользователей.

`APK` - installable Android package. Удобен для ручной проверки или распространения вне Play Store.

`Keystore` - файл с приватным ключом для подписи Android приложения. Его нельзя коммитить.

`Upload key` - ключ, которым разработчик подписывает bundle перед загрузкой в Google Play.

`App signing key` - ключ, которым Google Play подписывает APK для пользователей, если включен Play App Signing.

`Bundle ID` / `Application ID` - уникальный идентификатор приложения в store и на устройстве.

`Build number` - монотонно растущий номер сборки. В Android это `versionCode`, в iOS - `CFBundleVersion`.

`Build name` - пользовательская версия приложения, например `1.0.0`.

`Flavor` - вариант сборки: staging, production и т.п. В Android это product flavor; в iOS - scheme/configuration.

`Obfuscation` - усложнение reverse engineering Dart-кода через `--obfuscate` и `--split-debug-info`.

## 1. Что уже есть и что меняем

Фактическое состояние проекта перед главой 18:

```text
pubspec.yaml
  version: 1.0.0+1
  есть .env asset
  нет flutter_launcher_icons / flutter_native_splash

android/app/build.gradle.kts
  namespace = "arg.adegtiarev.geo_moments"
  applicationId = "arg.adegtiarev.geo_moments"
  release signingConfig = debug

android/app/src/main/AndroidManifest.xml
  android:label = "geo_moments"
  INTERNET/location/camera/notification permissions есть
  Supabase OAuth deep link есть

ios/Runner/Info.plist
  CFBundleDisplayName = "Geo Moments"
  URL scheme io.supabase.geomoments есть
  permission descriptions есть

.gitignore
  .env игнорируется
  Firebase admin JSON игнорируется
  android/key.properties пока нужно добавить явно
```

Главная практическая цель: убрать debug signing из release path, добавить воспроизводимые icon/splash commands и описать iOS/production readiness так, чтобы секреты не попали в Git.

## 2. Release не должен ломать features

Release preparation часто кажется "не про код", но она легко ломает app behavior:

- сменили `applicationId` и забыли обновить Firebase Android app;
- поменяли URL scheme и сломали Supabase OAuth redirect;
- убрали `.env` из assets и app перестал bootstrapping;
- изменили `minSdk` без проверки Mapbox/Firebase;
- собрали release без Mapbox token;
- включили obfuscation и потеряли symbol files.

Поэтому мы сохраняем quality gate из главы 17 и добавляем ручную release smoke проверку.

Regression checklist из прошлых глав остается обязательным:

- `/moments/new` стоит перед `/moments/:momentId`;
- compact phone tap открывает bottom sheet preview;
- tablet/wide tap открывает side panel;
- location button центрирует карту;
- notification tap открывает full details route;
- offline startup не зависает на profile sync;
- nearby moments/details открываются из cache;
- comments/likes offline errors не ломают details screen;
- raw UUID автора не показывается.

## 3. Целевая структура после главы

```text
assets/
  branding/
    app_icon.png                         new
    splash_icon.png                      optional

android/
  key.properties.example                 new
  app/
    build.gradle.kts                     updated
    src/main/AndroidManifest.xml         updated label

docs/
  release/
    android-release-checklist.md         new
    ios-release-checklist.md             new

pubspec.yaml                             updated dev tools/config
README.md                                updated portfolio/readme sections
.gitignore                               updated signing secrets
```

Если ты не хочешь добавлять generated icon/splash files в этой главе, можно оставить только config и checklist. Но для portfolio MVP лучше, чтобы app хотя бы не выглядел как default Flutter template в launcher.

## Практика

### Шаг 1. Добавить release tooling dependencies

Команды:

```bash
dart pub add dev:flutter_launcher_icons dev:flutter_native_splash
```

Почему это dev dependencies: эти packages нужны только для генерации platform assets. Runtime приложение их не импортирует.

После команды в `pubspec.yaml` появятся dev-зависимости:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^...
  flutter_native_splash: ^...
```

Не фиксируй версию руками в уроке. `dart pub add` подберет совместимую версию под текущий SDK.

### Шаг 2. Добавить брендовые исходники

Создай папку:

```text
assets/branding/
```

Нужны два PNG:

```text
assets/branding/app_icon.png
assets/branding/splash_icon.png
```

Требования:

- `app_icon.png`: квадратный PNG, минимум 1024x1024;
- не использовать прозрачность для iOS app icon;
- не класть мелкий текст на icon;
- icon должен читаться на маленьком размере;
- `splash_icon.png` может быть проще, но тоже должен быть PNG без мелких деталей.

Если пока нет финального дизайна, сделай простой временный icon: map pin + emotion dot + спокойный фон. Но не оставляй default Flutter icon.

Не добавляй эти PNG в `flutter.assets`, если они используются только генераторами icon/splash. Генератор прочитает source images из path в config.

### Шаг 3. Настроить flutter_launcher_icons

Файл:

```text
pubspec.yaml
```

Куда вставлять: в конец файла на top-level, не внутрь секции `flutter:`.

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/branding/app_icon.png
  min_sdk_android: 21
  remove_alpha_ios: true
```

Почему `remove_alpha_ios: true`: iOS app icons не должны иметь прозрачный alpha channel.

Почему `min_sdk_android: 21`: проект использует modern Flutter/plugins. Даже если `flutter.minSdkVersion` выше, icon generator config с 21 не конфликтует с release-подготовкой.

После config выполни:

```bash
dart run flutter_launcher_icons
```

Ожидаемые изменения:

```text
android/app/src/main/res/mipmap-*/ic_launcher.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/*
```

Эти generated image files можно коммитить. Это не секреты.

### Шаг 4. Настроить flutter_native_splash

Файл:

```text
pubspec.yaml
```

Куда вставлять: рядом с `flutter_launcher_icons`, тоже top-level.

```yaml
flutter_native_splash:
  color: "#F7FAF7"
  color_dark: "#101813"
  image: assets/branding/splash_icon.png
  android_12:
    color: "#F7FAF7"
    color_dark: "#101813"
    image: assets/branding/splash_icon.png
```

Почему splash нужен: native launch screen показывается до Flutter первого frame. Если оставить default белый screen или template asset, release выглядит незавершенным.

После config:

```bash
dart run flutter_native_splash:create
```

Ожидаемые изменения:

```text
android/app/src/main/res/drawable*/launch_background.xml
android/app/src/main/res/values*/styles.xml
ios/Runner/Base.lproj/LaunchScreen.storyboard
```

Если после генерации splash выглядит не так, как нужно, правь source PNG/config и запускай generator заново. Не редактируй generated platform files вручную без причины.

### Шаг 5. Привести Android label к release имени

Файл:

```text
android/app/src/main/AndroidManifest.xml
```

Сейчас:

```xml
android:label="geo_moments"
```

Замени на:

```xml
android:label="Geo Moments"
```

Почему это важно: `android:label` виден в launcher, system settings, permission dialogs и recent apps. Snake case в release выглядит как template artifact.

Не меняй здесь deep link:

```xml
<data
    android:scheme="io.supabase.geomoments"
    android:host="login-callback" />
```

Этот scheme связан с Supabase OAuth redirect из прошлых глав.

### Шаг 6. Защитить signing secrets в Git

Файл:

```text
.gitignore
```

Добавь:

```gitignore
android/key.properties
*.jks
*.keystore
```

Почему не коммитим `key.properties`: там будут passwords и путь к keystore. Keystore тоже приватный файл.

Создай безопасный пример:

```text
android/key.properties.example
```

Код:

```properties
storePassword=change-me
keyPassword=change-me
keyAlias=upload
storeFile=C:\\Users\\your-user\\upload-keystore.jks
```

Для Windows path в properties используй двойные backslashes (`\\`). Реальный `android/key.properties` пользователь создает локально сам и не коммитит.

### Шаг 7. Создать upload keystore

Команда Windows PowerShell:

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\upload-keystore.jks `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload
```

Если `keytool` не находится:

```bash
flutter doctor -v
```

Найди строку `Java binary at:`. `keytool` лежит рядом с `java`.

После создания файла создай локальный:

```text
android/key.properties
```

Пример:

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=C:\\Users\\jedi-\\upload-keystore.jks
```

Не присылай эти passwords в чат и не коммить файл.

### Шаг 8. Настроить Android release signing в Gradle

Файл:

```text
android/app/build.gradle.kts
```

В начало файла, до `plugins`, добавь:

```kotlin
import java.io.FileInputStream
import java.util.Properties
```

После `plugins { ... }`, перед `android { ... }`, добавь:

```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Внутри `android { ... }`, перед `buildTypes`, добавь:

```kotlin
signingConfigs {
    create("release") {
        if (keystorePropertiesFile.exists()) {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
}
```

Затем замени release build type:

```kotlin
buildTypes {
    release {
        signingConfig = if (keystorePropertiesFile.exists()) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }
    }
}
```

Почему fallback на debug оставляем: CI/учебная среда без `android/key.properties` все еще сможет выполнять basic release smoke build. Но в настоящем release checklist будет отдельный пункт: перед публикацией файл `android/key.properties` обязан существовать.

Почему не кладем passwords в Gradle: build script должен читать секреты из local file или CI secrets.

### Шаг 9. Проверить version в pubspec

Файл:

```text
pubspec.yaml
```

Сейчас:

```yaml
version: 1.0.0+1
```

Для первой portfolio release это нормально.

Правило дальше:

```text
1.0.0+1
  build name   = 1.0.0
  build number = 1
```

Для следующей загрузки в store build number должен вырасти:

```yaml
version: 1.0.1+2
```

Можно не менять version в этой главе, если это первая release candidate. Важно понимать, что Android берет `versionName`/`versionCode` из `pubspec.yaml`, а iOS берет `CFBundleShortVersionString`/`CFBundleVersion` через Flutter build settings.

### Шаг 10. Собрать Android release artifacts

Перед сборкой:

```bash
dart run build_runner build
flutter gen-l10n
dart format lib test docs/course
flutter analyze
flutter test
```

App Bundle для Play Store:

```bash
flutter build appbundle --release
```

Ожидаемый artifact:

```text
build/app/outputs/bundle/release/app-release.aab
```

APK для ручной проверки:

```bash
flutter build apk --release --split-per-abi
```

Ожидаемые artifacts:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

Если release build падает из-за missing `.env`, проверь, что локальный `.env` существует. Он используется как Flutter asset:

```yaml
flutter:
  assets:
    - .env
```

Важно: `.env` нужен на машине сборки, но не должен быть в Git.

### Шаг 11. Установить release APK на устройство

Если подключен Android device:

```bash
adb devices
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Если устройство x86_64 emulator:

```bash
adb install -r build/app/outputs/flutter-apk/app-x86_64-release.apk
```

Ручной release smoke test:

1. App запускается без debug banner.
2. Icon и app label выглядят как Geo Moments.
3. Supabase OAuth redirect работает.
4. Карта загружается, Mapbox token валиден.
5. Location button центрирует карту.
6. Compact phone tap открывает bottom sheet preview.
7. Tablet/wide tap открывает side panel.
8. Details route scroll-ится до likes/comments.
9. Create moment upload/save работает.
10. Push notification tap открывает нужный moment.
11. Offline restart показывает cached nearby moments/details.

Если что-то работает в debug, но не работает в release, сначала проверь `.env`, platform permissions, Firebase config и ProGuard/R8-related logs.

### Шаг 12. iOS release checklist

На Windows нельзя полноценно собрать iOS IPA. В этой главе мы фиксируем checklist, который выполняется на macOS.

Создай файл:

```text
docs/release/ios-release-checklist.md
```

Код:

````md
# iOS Release Checklist

## Apple Developer

- Apple Developer account is active.
- Bundle ID is registered.
- Push Notifications capability is enabled.
- Associated domains/deep links are reviewed if added later.

## Firebase and Supabase

- iOS app exists in Firebase project.
- `GoogleService-Info.plist` belongs to the production Firebase app.
- Supabase OAuth redirect includes `io.supabase.geomoments://login-callback/`.
- Supabase project secrets do not live in the Flutter repository.

## Xcode

- Open `ios/Runner.xcworkspace`.
- Verify Runner signing team.
- Verify Bundle Identifier.
- Verify Display Name: Geo Moments.
- Verify camera/photo/microphone/location permission descriptions.
- Verify Push Notifications capability.

## Build

```bash
flutter clean
flutter pub get
flutter gen-l10n
dart run build_runner build
flutter analyze
flutter test
flutter build ipa --release
```

Expected output:

```text
build/ios/archive/Runner.xcarchive
build/ios/ipa/*.ipa
```

## Smoke Test

- Install through TestFlight.
- Sign in with OAuth.
- Open map.
- Open details from notification tap.
- Create a moment with media.
- Verify comments/replies push flow.
````

Почему это checklist, а не автоматическая команда: iOS signing зависит от Apple account, certificates, provisioning profiles и Xcode capabilities. Эти вещи нельзя корректно настроить из Windows-only учебной среды.

### Шаг 13. Android release checklist

Создай файл:

```text
docs/release/android-release-checklist.md
```

Код:

````md
# Android Release Checklist

## Secrets

- `.env` exists locally and is not committed.
- `android/key.properties` exists locally and is not committed.
- Upload keystore exists outside the repository.
- Firebase service account JSON is not committed.
- Supabase service role secrets are not committed.

## Identity

- `applicationId` is final: `arg.adegtiarev.geo_moments`.
- Android app in Firebase uses the same package name.
- Google OAuth Android client uses the correct package/signing fingerprint.
- Supabase OAuth redirect is still `io.supabase.geomoments://login-callback/`.

## Quality Gate

```bash
dart run build_runner build
flutter gen-l10n
dart format lib test docs/course
flutter analyze
flutter test
```

## Build

```bash
flutter build appbundle --release
flutter build apk --release --split-per-abi
```

## Artifacts

- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## Smoke Test

- Install release APK on a physical Android device.
- Sign in/out.
- Open map and details.
- Check compact preview and tablet side panel if available.
- Create a moment with media.
- Like/unlike.
- Comment/reply.
- Verify push notification tap.
- Restart offline and verify cached moments/details.
````

### Шаг 14. Production env strategy

Сейчас проект использует `.env` как asset:

```yaml
flutter:
  assets:
    - .env
```

Это нормально для учебного проекта, но для production есть компромисс:

- Supabase anon key и Mapbox public token не являются server secrets, но их нельзя считать приватными;
- service role keys, Firebase service account JSON и webhook secrets никогда не должны попадать в app bundle;
- разные environments лучше собирать из разных `.env` файлов или через flavors.

Для текущей главы выберем простой путь:

```text
.env.example          committed template
.env                  local active env, ignored
.env.production       optional local production env, ignored
```

Добавь в `.gitignore`:

```gitignore
.env.*
!.env.example
```

Почему `!.env.example`: template должен остаться в Git.

Перед production build копируй нужный env:

```powershell
Copy-Item .env.production .env
flutter build appbundle --release
```

Не делай это в CI через commit. В CI `.env` должен создаваться из protected secrets.

### Шаг 15. Flavors: что делаем сейчас

Flutter flavors полезны, когда staging и production должны жить рядом на одном устройстве:

```text
Geo Moments Dev
  applicationId: arg.adegtiarev.geo_moments.dev
  Supabase dev project
  Firebase dev app

Geo Moments
  applicationId: arg.adegtiarev.geo_moments
  Supabase prod project
  Firebase prod app
```

Но flavors требуют отдельной Android productFlavors настройки, iOS schemes, Firebase apps, Google OAuth clients и Supabase redirect URLs. Для финальной главы это можно считать next step, а не обязательной частью MVP.

В этой главе:

- не добавляем flavors в код;
- документируем production env copy step;
- оставляем `applicationId` как production id;
- не ломаем Supabase OAuth scheme.

Если позже добавишь flavors, обязательно сделай отдельную главу/PR, потому что это затрагивает Firebase, OAuth и store identity.

### Шаг 16. Обновить README как portfolio project

Файл:

```text
README.md
```

README уже содержит course links и quality gate. Добавь sections:

```md
## Features

- Map-first moment discovery with Mapbox.
- Photo/video moment creation with Supabase Storage.
- Likes, comments, replies, and realtime discussion refresh.
- Firebase push notifications for comments and replies.
- Offline read cache for nearby moments and details with Drift.
- Compact phone preview sheet and tablet/wide side detail panel.
- English, Russian, and Spanish localization.

## Architecture

- Riverpod for state and dependency injection.
- Feature-first Flutter structure.
- Repository boundaries for Supabase/Firebase integrations.
- Drift read-side cache for offline startup and stale-while-revalidate.
- Widget/provider tests with fake repositories and in-memory database.

## Release

Android release checklist: [docs/release/android-release-checklist.md](docs/release/android-release-checklist.md)

iOS release checklist: [docs/release/ios-release-checklist.md](docs/release/ios-release-checklist.md)
```

Не превращай README в полный курс. README для portfolio должен быстро объяснять, что умеет проект, как он устроен и как его проверить.

### Шаг 17. Финальная проверка secrets

Команда:

```bash
git status --short
```

Проверь, что там нет:

```text
.env
.env.production
android/key.properties
*.jks
*.keystore
Firebase service account JSON
```

Дополнительно:

```bash
rg "private_key|FIREBASE_SERVICE_ACCOUNT|supabase_service_role|service_role" .
```

Ожидаемые безопасные совпадения:

- Edge Function читает secret names;
- course docs объясняют, что service role нельзя коммитить;
- checklist упоминает запрет.

Опасные совпадения:

- настоящий JSON service account;
- строка `"private_key": "-----BEGIN PRIVATE KEY-----...`;
- Supabase service role JWT;
- реальные passwords keystore.

## Проверка

Команды:

```bash
dart run build_runner build
flutter gen-l10n
dart format lib test docs/course
flutter analyze
flutter test
flutter build appbundle --release
flutter build apk --release --split-per-abi
git status --short
```

Если `flutter build appbundle --release` падает из-за отсутствия signing secrets, проверь:

- есть ли `android/key.properties`;
- правильный ли Windows path в `storeFile`;
- существует ли `.env`;
- не перепутан ли Firebase package name.

Если build выполняется без `android/key.properties`, это учебный fallback на debug signing. Такой artifact нельзя публиковать в store.

## Частые ошибки

### Ошибка: `android/key.properties` попал в Git

Причина: забыли добавить файл в `.gitignore`.

Исправление: убрать из Git index, оставить локально и добавить `.gitignore` правило.

### Ошибка: keystore лежит внутри repo

Причина: удобно положить рядом с Gradle files.

Исправление: хранить keystore вне репозитория, например в home directory или secret storage.

### Ошибка: release signing все еще debug

Причина: оставили `signingConfig = signingConfigs.getByName("debug")`.

Исправление: release build type должен использовать `signingConfigs.getByName("release")`, когда `key.properties` существует.

### Ошибка: сменили applicationId и сломали Firebase/Auth

Причина: package name является частью Firebase Android app и OAuth fingerprints.

Исправление: если меняешь `applicationId`, обнови Firebase app, Google OAuth client, SHA fingerprints и проверь Supabase OAuth.

### Ошибка: `.env` не попал в release assets

Причина: файл отсутствует локально на машине сборки.

Исправление: создать `.env` перед build. Не коммитить его.

### Ошибка: app icon с прозрачностью не проходит iOS

Причина: iOS app icon не должен иметь alpha channel.

Исправление: использовать `remove_alpha_ios: true` и source PNG без прозрачности.

### Ошибка: после splash generator вручную правят generated XML/storyboard

Причина: хочется быстро поправить цвет.

Исправление: менять config/source image и запускать generator снова. Generated files должны быть воспроизводимы.

### Ошибка: build artifacts коммитятся

Причина: `build/` случайно добавили вручную.

Исправление: build artifacts остаются ignored. В Git идут только source/config/generated platform assets, которые нужны проекту.

### Ошибка: obfuscation включили и потеряли symbol files

Причина: собрали с `--obfuscate --split-debug-info`, но не сохранили output.

Исправление: если включаешь obfuscation, архивируй split-debug-info directory для каждого release build.

### Ошибка: release smoke test проверяет только старт приложения

Причина: release считается готовым после successful build.

Исправление: пройти manual smoke по auth/map/details/create/push/offline cache. Release build может ломаться только в platform flows.

## Definition of Done

- `flutter_launcher_icons` и `flutter_native_splash` добавлены как dev dependencies.
- `assets/branding/app_icon.png` добавлен и не является default Flutter icon.
- `assets/branding/splash_icon.png` добавлен или осознанно используется тот же source image.
- `pubspec.yaml` содержит reproducible config для icon/splash generation.
- Android app label изменен на `Geo Moments`.
- `.gitignore` игнорирует `android/key.properties`, `*.jks`, `*.keystore`, `.env.*`, но сохраняет `.env.example`.
- `android/key.properties.example` добавлен без реальных secrets.
- `android/app/build.gradle.kts` умеет читать `key.properties` и использовать release signing config.
- Release build без local signing secrets не публикуется в store.
- Android release checklist добавлен в `docs/release/android-release-checklist.md`.
- iOS release checklist добавлен в `docs/release/ios-release-checklist.md`.
- README описывает features, architecture, development checks и release checklist links.
- Route order `/moments/new` перед `/moments/:momentId` сохранен.
- Compact phone bottom sheet preview сохранен.
- Tablet/wide side panel сохранен.
- Location button продолжает центрировать карту.
- Notification tap flow продолжает открывать full details route.
- Offline cache для nearby moments/details сохранен.
- Service account JSON, service role keys, `.env`, keystore и passwords не попали в Git.
- `dart run build_runner build` проходит.
- `flutter gen-l10n` проходит.
- `dart format lib test docs/course` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- `flutter build appbundle --release` проходит локально при наличии `.env` и signing setup.
- `flutter build apk --release --split-per-abi` проходит локально при наличии `.env` и signing setup.

## Что прислать на ревью

После реализации напиши:

```text
Глава 18 готова, проверь код.
```

Я буду проверять:

- что release signing не хранит secrets в Git;
- что Android release не использует debug signing при наличии `key.properties`;
- что icon/splash config воспроизводим;
- что README стал portfolio-ready, но не раздулся в копию курса;
- что release checklist реалистичен для Android и iOS;
- что `.env`, Firebase service account JSON, service role и keystore не попали в Git;
- что route order, compact preview, side panel, notification routing, location focus и offline cache не сломаны;
- что quality gate и release build commands проходят.

## Источники

Глава сверена с актуальными официальными Flutter deployment docs:

- [Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Build and release an iOS app](https://docs.flutter.dev/deployment/ios)
- [Set up Flutter flavors for Android](https://docs.flutter.dev/deployment/flavors)
- [Set up Flutter flavors for iOS and macOS](https://docs.flutter.dev/deployment/flavors-ios)
