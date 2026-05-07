# Geo Moments Flutter Course

Этот каталог - рабочая память курса. Если в новом чате написать "продолжаем", начинать нужно отсюда:

1. Прочитать [STATE.md](STATE.md) - текущее состояние курса и следующий шаг.
2. Прочитать [ROADMAP.md](ROADMAP.md) - общую карту глав.
3. Прочитать [TEACHING_GUIDE.md](TEACHING_GUIDE.md) - стандарт подробности уроков.
4. Для текущей главы открыть файл из [lessons](lessons).
5. Сверить код проекта с [ARCHITECTURE.md](ARCHITECTURE.md) и [DECISIONS.md](DECISIONS.md).

Цель курса: практично восстановить и углубить Flutter до уверенного уровня через разработку приложения Geo Moments от пустого шаблона до состояния, пригодного для портфолио и подготовки релизных сборок Android/iOS.

## Формат работы

Каждая глава состоит из:

- Теория: подробное объяснение новых понятий, зачем они нужны, как ими пользоваться и где они будут в проекте.
- Примеры кода: сначала минимальные изолированные примеры, потом целевой код для проекта.
- Практика: конкретный инкремент в проекте.
- Проверка: `flutter analyze`, тесты по необходимости, запуск приложения.
- Ревью: ты пишешь код, я проверяю архитектуру, читаемость, Flutter-подходы, риски и пробелы.
- Фиксация прогресса: обновляем [STATE.md](STATE.md).

К следующей главе переходим только после твоего подтверждения.

## Принцип курса

Мы не строим "еще одну соцсеть". Geo Moments - это карта местных моментов: пользователь оставляет фото или видео, короткое описание события/эмоции и обсуждает конкретную точку на карте. Приложение демонстрирует мобильные компетенции: карта, медиа, auth, Supabase, Firebase push, локализация, темы, адаптивность, Android/iOS, подготовка к релизу.

## Текущий проект

Текущая стадия: завершена глава 8, следующая глава - [09 Create Moment: Media Capture](lessons/09-create-moment-media-capture.md).

- Flutter: 3.41.0 stable
- Dart: 3.11.0
- State management: Riverpod
- Navigation: `go_router`
- Backend: Supabase Auth, Postgres, RLS, Storage
- Current data: seed moments из Supabase через repository/provider layer
- Current map: Mapbox-карта с markers, bottom sheet preview и location permission
- Current details flow: marker/list preview открывает `/moments/:momentId`
- Следующий feature: create flow с выбором/съемкой фото и видео, пока без upload
- Push: Firebase Cloud Messaging запланирован в поздней phase
- Platforms: Android и iOS
