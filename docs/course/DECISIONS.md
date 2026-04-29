# Architecture Decisions

Этот файл фиксирует решения, чтобы в новом чате не переобсуждать базу без причины.

## ADR-001: State management

Решение: Riverpod.

Причины:

- хорошо подходит для feature-first архитектуры;
- прозрачно тестируется без Flutter widget tree;
- не привязан к `BuildContext`;
- удобен для async-состояний Supabase/Firebase;
- актуален для портфолио Flutter-разработчика.

Базовый стиль: `flutter_riverpod`, `Notifier`/`AsyncNotifier`, `Provider`, `StreamProvider`, `FutureProvider`. Code generation добавим только если она начнет реально снижать шум.

## ADR-002: Архитектура

Решение: feature-first clean architecture без чрезмерного enterprise-слоя.

Целевой шаблон feature:

```text
lib/src/features/<feature>/
  data/
    datasources/
    dto/
    repositories/
  domain/
    entities/
    repositories/
    use_cases/
  presentation/
    controllers/
    screens/
    widgets/
```

Для маленьких features допускается более короткая структура, но зависимости идут только внутрь:

```text
presentation -> domain -> data
```

UI не знает про Supabase/Firebase напрямую.

## ADR-003: Backend

Решение: Supabase как основной backend.

Используем:

- Supabase Auth для пользовательской сессии;
- OAuth providers: Google для Android, Apple для iOS;
- Postgres для профилей, моментов, лайков, комментариев, push-токенов;
- Storage для фото/видео;
- Realtime для комментариев и обновлений карточки момента;
- Edge Functions для серверной логики, где клиенту нельзя доверять.

## ADR-004: Push notifications

Решение: Firebase Cloud Messaging для доставки push.

Supabase хранит FCM/APNs token пользователя. На новый комментарий или ответ серверная логика отправляет push через Firebase Admin API. Клиент Flutter только регистрирует токен, обрабатывает permission и открытие приложения по уведомлению.

## ADR-005: Map

Предварительное решение: Mapbox.

Причины:

- хорошая визуальная карта для портфолио;
- работает на Android/iOS;
- можно переключать стили для day/night;
- меньше привязки к Google ecosystem при уже используемых Supabase/Firebase.

Решение можно пересмотреть до главы карты, если у пользователя есть готовые Google Maps ключи или предпочтение к Google Maps.

## ADR-006: Media capture

Решение на MVP: `image_picker` для фото и видео с камеры/галереи.

Причина: быстрее довести приложение до публикационного уровня. Пакет `camera` оставляем как возможное расширение, если понадобится собственный camera UI.

## ADR-007: Local cache

Решение: сначала in-memory cache через Riverpod и Supabase queries. Локальную БД добавляем отдельной главой, если базовый продукт уже стабилен.

Кандидат для локальной БД: Drift. Причина: типобезопасность, SQL-подход близок к backend-опыту пользователя, хороший портфельный сигнал.

## ADR-008: Localization

Решение: стандартный Flutter `gen-l10n` с ARB-файлами.

Языки MVP:

- English
- Русский
- Español

Переключение языка - внутри приложения, с сохранением выбора.

## ADR-009: Theme

Решение: Material 3, light/dark/system mode с ручным переключением.

Карта должна иметь согласованные day/night стили.

