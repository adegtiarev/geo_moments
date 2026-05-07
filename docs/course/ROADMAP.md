# Course Roadmap

Курс разбит на практические главы. Каждая глава добавляет работающий инкремент приложения и закрывается сборкой/проверками.

Уроки должны писаться не как checklist из терминов, а как учебник: новая тема сначала объясняется, затем показывается минимальный пример, затем применяется в проекте. Подробный стандарт зафиксирован в [TEACHING_GUIDE.md](TEACHING_GUIDE.md).

## Phase 0: Planning

### 00. Course and Product Plan

Статус: done.

Результат:

- описан продукт;
- выбран технический стек;
- создана документация курса;
- определен порядок разработки.

## Phase 1: Flutter foundation

### 01. Project Foundation

Статус: done.

Flutter темы:

- структура Flutter-приложения;
- `MaterialApp.router`;
- базовая навигация;
- Riverpod `ProviderScope`;
- отличие `Widget`, `StatelessWidget`, `ConsumerWidget`;
- минимальная feature-first структура.

Проект:

- убрать counter template;
- создать app shell;
- добавить home/settings placeholder screens;
- настроить `go_router` и Riverpod;
- пройти `flutter analyze`.

### 02. Design System, Theme, Responsive Basics

Статус: done.

Flutter темы:

- Material 3;
- `ThemeData`, `ColorScheme`, `TextTheme`;
- light/dark/system theme mode;
- adaptive layout: телефоны, планшеты, portrait/landscape;
- `LayoutBuilder`, breakpoints, safe areas.

Проект:

- создать дизайн-основу Geo Moments;
- добавить переключатель темы;
- сделать responsive home layout;
- подготовить карту как главный экран с placeholder.

### 03. Localization

Статус: done.

Flutter темы:

- `gen-l10n`;
- ARB-файлы;
- plural/select;
- locale override;
- хранение пользовательских настроек.

Проект:

- добавить English, Russian, Spanish;
- добавить ручное переключение языка;
- локализовать навигацию, settings, пустые состояния.

## Phase 2: Data and backend foundation

### 04. Supabase Project and Environment Config

Статус: done.

Flutter/Supabase темы:

- `supabase_flutter`;
- environment variables;
- app bootstrap;
- separation of config and secrets;
- safe error handling.

Проект:

- создать Supabase project;
- добавить client init;
- добавить `.env.example`;
- сделать health-check screen/state.

### 05. Auth and Profiles

Статус: done.

Flutter/Supabase темы:

- auth state stream;
- OAuth deep links;
- platform-specific login;
- repository pattern;
- async state in Riverpod.

Проект:

- Google sign-in для Android через Supabase OAuth;
- Apple sign-in для iOS через Supabase OAuth;
- profile bootstrap после первого входа;
- auth gate в router.

### 06. Supabase Schema, RLS, and Seed Data

Статус: done.

Backend темы:

- schema migrations;
- RLS policies;
- storage buckets;
- seed data for development;
- basic SQL RPC for nearby moments.

Проект:

- добавить SQL schema в `supabase/migrations`;
- создать policies;
- загрузить тестовые moments;
- показать список моментов без карты.

## Phase 3: Map and moments

### 07. Map Screen

Статус: done.

Flutter темы:

- platform views;
- permissions;
- map controller lifecycle;
- marker rendering;
- day/night map styles.

Проект:

- подключить Mapbox;
- показать текущую область карты;
- вывести маркеры seed moments;
- открыть bottom sheet по marker tap.

### 08. Moment Details

Статус: done.

Flutter темы:

- routing with params;
- bottom sheets;
- image/video presentation;
- loading/error/empty states.

Проект:

- карточка момента;
- отдельный экран деталей;
- счетчики likes/comments;
- skeleton/placeholder states.

### 09. Create Moment: Media Capture

Статус: next.

Flutter темы:

- permissions camera/photos;
- `image_picker`;
- file lifecycle;
- optimistic UI basics;
- form validation.

Проект:

- сделать flow создания момента;
- снять фото или видео;
- добавить текст и эмоцию;
- сохранить черновик локально в state.

### 10. Upload and Save Moment

Flutter/Supabase темы:

- Supabase Storage;
- upload progress;
- public/private URLs;
- transaction-like flow on client;
- rollback strategy.

Проект:

- загрузить media в Supabase Storage;
- создать row в `moments`;
- обновить карту после создания;
- обработать ошибки upload/save.

## Phase 4: Social interactions without becoming a social network

### 11. Likes

Flutter темы:

- optimistic update;
- idempotent commands;
- provider invalidation;
- race conditions in UI.

Проект:

- лайк/анлайк момента;
- счетчик likes;
- защита от двойных taps.

### 12. Comments and Replies

Flutter/Supabase темы:

- comment tree with one nesting level;
- realtime subscriptions;
- pagination basics;
- text input ergonomics.

Проект:

- комментарии к моменту;
- ответы на комментарии;
- realtime update открытого обсуждения;
- уведомление в UI о новых комментариях.

## Phase 5: Notifications and app lifecycle

### 13. Firebase Push

Flutter/Firebase темы:

- Firebase project setup;
- FCM token;
- notification permissions;
- foreground/background/opened app handling;
- platform differences Android/iOS.

Проект:

- подключить Firebase;
- сохранить push token в Supabase;
- отправлять push на новый комментарий/ответ;
- открыть нужный moment из notification tap.

### 14. App Lifecycle, Permissions, and Reliability

Flutter темы:

- app lifecycle;
- permission denied flows;
- retry UX;
- offline/poor network states;
- logging.

Проект:

- аккуратные permission screens;
- retry для карты/media/comments;
- базовое логирование ошибок.

## Phase 6: Portfolio polish

### 15. Tablet, Landscape, and UI Polish

Flutter темы:

- adaptive scaffold;
- master/detail layouts;
- landscape layouts;
- media aspect ratios;
- accessibility basics.

Проект:

- tablet layout: карта + detail panel;
- landscape layout без наложений;
- проверка текстов EN/RU/ES;
- polish темной/светлой темы.

### 16. Local Cache

Flutter темы:

- cache boundaries;
- Drift basics;
- stale-while-revalidate;
- repository composition.

Проект:

- кешировать последние загруженные moments;
- показывать cached state при старте;
- обновлять из сети.

Эта глава может быть пропущена, если цель - быстрее выйти на release-ready MVP.

### 17. Testing and Quality Gate

Flutter темы:

- unit tests;
- widget tests with ProviderScope overrides;
- fake repositories;
- golden/screenshot sanity where useful.

Проект:

- покрыть use cases;
- покрыть auth/settings/moment UI;
- добавить README для запуска тестов.

### 18. Release Preparation

Flutter темы:

- app icons/splash;
- Android signing;
- iOS bundle id/capabilities;
- build flavors/env;
- store readiness checklist.

Проект:

- подготовить release configs;
- собрать Android release artifact;
- описать iOS release steps;
- оформить GitHub README как portfolio project.
