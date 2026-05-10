# 15 Tablet, Landscape, and UI Polish

Статус: draft.

## Что строим

В главе 14 Geo Moments стал устойчивее: приложение обновляет permission state после возврата из system settings, показывает retry UI для сетевых ошибок, не теряет notification tap flow и пишет ошибки через отдельный logging boundary.

В главе 15 доведем интерфейс до уровня portfolio MVP:

- сделаем осознанный adaptive layout для телефона, планшета и landscape;
- на широких экранах будем показывать карту и detail panel рядом;
- уберем неудачные наложения и слишком низкую карту в landscape;
- приведем media к стабильным aspect ratio;
- проверим тексты EN/RU/ES в узких контейнерах;
- добавим базовые accessibility labels и сохраненные tooltips;
- расширим widget tests под разные размеры экрана.

После главы приложение должно ощущаться как один и тот же продукт на телефоне, планшете и горизонтальном экране, а не как phone UI, растянутый на большую ширину.

## Почему это важно

До этой главы у Geo Moments уже есть реальные features: карта, создание moments, details, likes, comments, push и retry. Но мобильное приложение часто теряет качество не из-за backend, а из-за маленьких UI-проблем:

```text
телефон в landscape
  -> app bar занимает высоту
  -> карта становится слишком низкой
  -> bottom list давит карту
  -> marker tap открывает bottom sheet поверх всего
```

Или:

```text
tablet
  -> справа много пустого места
  -> пользователь нажимает marker
  -> вместо side panel открывается phone-style bottom sheet
```

В Android-опыте это похоже на `sw600dp`, `WindowSizeClass`, master/detail экран и разные layouts для portrait/landscape. Во Flutter мы сделаем то же через `LayoutBuilder`, `Size`, `MediaQuery`, Riverpod state и обычные widgets.

Главная идея главы: responsive layout - это не "сделать все шире". Это выбор другой композиции, когда устройство дает больше места.

## Словарь главы

`Adaptive layout` - layout, который меняет структуру UI под размер окна, input mode и ориентацию.

`Responsive layout` - layout, который гибко меняет размеры элементов внутри текущей структуры.

`Window class` - условная категория окна: compact, medium, expanded. Она помогает не писать `if (width > 731)` в каждом widget-е.

`Master/detail` - композиция, где слева или рядом находится список/карта, а справа подробности выбранного элемента.

`Compact layout` - телефонный layout: один главный поток, переходы через route или bottom sheet.

`Landscape` - горизонтальная ориентация. В Flutter ее лучше определять не только через orientation, а через фактический `Size`, потому что split-screen и desktop windows бывают нестандартными.

`Aspect ratio` - соотношение ширины к высоте. Для media оно защищает UI от скачков высоты и кривого crop-а.

`Semantics` - accessibility metadata, которую читают screen readers и используют accessibility tools.

## 1. Что уже есть и что меняем

Сейчас `MapScreen` уже не полностью phone-only. В `_MapContent` есть `LayoutBuilder`, и при ширине tablet показывается:

```text
map | nearby moments list
```

Это хороший foundation, но для главы 15 нужно сделать следующий шаг:

```text
compact phone portrait:
  map
  nearby moments list
  marker/list tap -> bottom sheet preview -> details route

tablet / landscape:
  map | side panel
  marker/list tap -> side detail panel
  full details route остается доступным кнопкой View details
```

Почему не удаляем details route: push notification из главы 13 открывает `/moments/:momentId`, comments живут на details screen, и deep links должны продолжать работать. Side panel - это дополнительный tablet UX, а не замена routing.

Почему side panel сначала может показывать nearby list: на планшете пользователь должен видеть, что можно выбрать. После выбора moment panel переключается на details/preview выбранного moment.

## 2. Window class вместо случайных breakpoints

В главе 2 уже был `AppBreakpoints`. Повторим идею кратко:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final width = constraints.maxWidth;
    if (width >= 600) {
      return const TabletLayout();
    }

    return const PhoneLayout();
  },
);
```

Такой код работает, но быстро расползается. В главе 15 лучше дать этому имя:

```dart
enum AppWindowClass {
  compact,
  medium,
  expanded,
}
```

После этого UI читает не "магическое число", а намерение:

```dart
final windowClass = AppBreakpoints.windowClassFor(size);
final useSidePanel = AppBreakpoints.useSidePanel(size);
```

Это особенно важно для landscape. Телефон в landscape может иметь ширину больше `600`, но высота маленькая. Для него вертикальный layout `map + list` часто хуже, чем горизонтальный split.

## 3. Почему detail panel не должен быть bottom sheet

Bottom sheet хорош на телефоне:

- он появляется поверх карты;
- занимает часть высоты;
- легко закрывается жестом;
- не требует постоянной второй колонки.

На планшете это уже выглядит как phone pattern на большом экране. Пользователь ожидает, что выбранный объект останется рядом с картой.

Сравнение:

```text
phone:
  tap marker -> preview sheet -> View details

tablet:
  tap marker -> side panel updates -> View details if нужен полный экран
```

Это и есть master/detail. "Master" здесь - карта и nearby list, "detail" - выбранный moment.

## 4. Целевая структура после главы

Новых backend файлов в этой главе нет. Старые migration-файлы не трогаем и не переисполняем.

```text
lib/
  l10n/
    app_en.arb
    app_ru.arb
    app_es.arb
  src/
    core/
      ui/
        app_breakpoints.dart          updated
    features/
      map/
        presentation/
          screens/
            map_screen.dart           updated
      moments/
        presentation/
          widgets/
            moment_details_pane.dart  new
            moment_media_view.dart    updated

test/
  widget_test.dart                    updated
```

Если при реализации окажется удобнее назвать panel иначе, можно выбрать другое имя. Важно, чтобы code ownership остался понятным:

- map feature решает, где находится panel;
- moments feature рисует content выбранного moment;
- routing остается в `app_router.dart`;
- Supabase/Firebase код не попадает в widgets напрямую.

## Практика

### Шаг 1. Расширить breakpoints

Файл:

```text
lib/src/core/ui/app_breakpoints.dart
```

Куда вставлять: замени текущий маленький `AppBreakpoints` на версию с window class. Этот файл уже является общей точкой для responsive решений, поэтому не нужно создавать новый helper в `MapScreen`.

Код:

```dart
import 'dart:ui';

enum AppWindowClass {
  compact,
  medium,
  expanded,
}

abstract final class AppBreakpoints {
  static const tablet = 600.0;
  static const desktop = 1024.0;
  static const landscapeSplitMinWidth = 700.0;

  static bool isTabletWidth(double width) => width >= tablet;

  static AppWindowClass windowClassFor(Size size) {
    if (size.width >= desktop) {
      return AppWindowClass.expanded;
    }

    if (size.width >= tablet) {
      return AppWindowClass.medium;
    }

    return AppWindowClass.compact;
  }

  static bool useSidePanel(Size size) {
    final isWideEnough = size.width >= tablet;
    final isLandscapePhone =
        size.width >= landscapeSplitMinWidth && size.width > size.height;

    return isWideEnough || isLandscapePhone;
  }

  static double sidePanelWidth(Size size) {
    if (size.width >= desktop) {
      return 440;
    }

    return 360;
  }
}
```

Почему импортируем `dart:ui`, а не `package:flutter/material.dart`: `Size` живет ниже Material layer. Breakpoints не должны зависеть от Material widgets.

Почему не используем только `Orientation.landscape`: orientation говорит про отношение width/height, но не говорит, достаточно ли места для split. Маленькое окно на desktop может быть landscape, но слишком узким.

### Шаг 2. Добавить строки для panel и accessibility

Файлы:

```text
lib/l10n/app_en.arb
lib/l10n/app_ru.arb
lib/l10n/app_es.arb
```

Куда вставлять: рядом с `nearbyMomentsTitle`, `viewMomentDetails`, `momentDetailsTitle` и `createMomentMediaEmpty`. Это строки map/moment UI, поэтому их лучше держать в той же группе.

EN:

```json
"selectedMomentTitle": "Selected moment",
"selectedMomentEmpty": "Select a moment on the map.",
"closeMomentPanel": "Close moment panel",
"mapSemanticLabel": "Map of nearby moments",
"momentMediaImageLabel": "Moment media",
"momentMediaVideoLabel": "Moment video preview",
"momentMediaMissingLabel": "Moment without media"
```

RU:

```json
"selectedMomentTitle": "Выбранный момент",
"selectedMomentEmpty": "Выберите момент на карте.",
"closeMomentPanel": "Закрыть панель момента",
"mapSemanticLabel": "Карта моментов рядом",
"momentMediaImageLabel": "Медиа момента",
"momentMediaVideoLabel": "Превью видео момента",
"momentMediaMissingLabel": "Момент без медиа"
```

ES:

```json
"selectedMomentTitle": "Momento seleccionado",
"selectedMomentEmpty": "Selecciona un momento en el mapa.",
"closeMomentPanel": "Cerrar panel del momento",
"mapSemanticLabel": "Mapa de momentos cercanos",
"momentMediaImageLabel": "Contenido del momento",
"momentMediaVideoLabel": "Vista previa del video del momento",
"momentMediaMissingLabel": "Momento sin contenido"
```

После ARB:

```bash
flutter gen-l10n
```

Не добавляй эти строки прямо в widgets. В этой главе специально проверяем EN/RU/ES, поэтому все видимые и accessibility тексты идут через `context.l10n`.

### Шаг 3. Создать detail pane для wide layout

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_details_pane.dart
```

Куда вставлять: новый widget рядом с `moment_details_content.dart`, потому что он переиспользует moment details provider/content, но не является отдельным route screen.

Код:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/network/app_failure_message.dart';
import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../controllers/moments_providers.dart';
import 'moment_details_content.dart';
import 'moment_details_skeleton.dart';
import 'retry_error_view.dart';

class MomentDetailsPane extends ConsumerWidget {
  const MomentDetailsPane({
    required this.momentId,
    required this.onClose,
    super.key,
  });

  final String? momentId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          children: [
            _PaneHeader(onClose: onClose, canClose: momentId != null),
            const Divider(height: 1),
            Expanded(
              child: momentId == null
                  ? const _EmptyMomentSelection()
                  : _LoadedMomentPane(momentId: momentId!),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.onClose,
    required this.canClose,
  });

  final VoidCallback onClose;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.selectedMomentTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: context.l10n.closeMomentPanel,
            onPressed: canClose ? onClose : null,
            icon: const Icon(Icons.close_outlined),
          ),
        ],
      ),
    );
  }
}

class _LoadedMomentPane extends ConsumerWidget {
  const _LoadedMomentPane({required this.momentId});

  final String momentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moment = ref.watch(momentDetailsProvider(momentId));

    return moment.when(
      loading: () => const MomentDetailsSkeleton(),
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
      data: (moment) => MomentDetailsContent(moment: moment),
    );
  }
}

class _EmptyMomentSelection extends StatelessWidget {
  const _EmptyMomentSelection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          context.l10n.selectedMomentEmpty,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
```

Почему pane использует `momentDetailsProvider`, а не только `Moment` из списка: list item может быть неполным или устаревшим. Details provider уже умеет fallback при optional `profiles(...)` join и RPC. Не ломай это поведение.

Почему `MomentDetailsContent` остается `ListView`: comments и media могут быть длиннее panel. Wide layout не отменяет scrollable content.

### Шаг 4. Добавить selected moment state в MapScreen

Файл:

```text
lib/src/features/map/presentation/screens/map_screen.dart
```

Куда вставлять: в `_MapScreenState`, рядом с `_visibleMoments`, `_hasLoadedMoments` и `_locationFocusRequestId`.

Добавь поле:

```dart
Moment? _selectedMoment;
```

Ниже существующих helper methods добавь:

```dart
void _selectMomentForPanel(Moment moment) {
  setState(() {
    _selectedMoment = moment;
  });
}

void _clearSelectedMoment() {
  setState(() {
    _selectedMoment = null;
  });
}
```

Почему state живет в `MapScreen`, а не внутри `_MapContent`: выбранный moment должен переживать rebuild layout-а при смене orientation, refresh moments и permission banner. `_MapContent` - только layout widget.

### Шаг 5. Передать selected moment в `_MapContent`

В `MapScreen.build` сейчас `_MapContent` создается в трех ветках `moments.when`: loading с уже загруженными данными, error с уже загруженными данными и data.

Куда вставлять: во все три места, где создается `_MapContent`, добавь одинаковые параметры:

```dart
selectedMoment: _selectedMoment,
onMomentSelectedForPanel: _selectMomentForPanel,
onCompactMomentSelected: _showMomentPreview,
onCloseSelectedMoment: _clearSelectedMoment,
```

После этого обнови constructor `_MapContent`:

```dart
class _MapContent extends StatelessWidget {
  const _MapContent({
    required this.moments,
    required this.selectedMoment,
    required this.isLocationEnabled,
    required this.locationFocusRequestId,
    required this.mapBuilder,
    required this.onMomentSelectedForPanel,
    required this.onCompactMomentSelected,
    required this.onCloseSelectedMoment,
    required this.onCameraCenterChanged,
  });

  final List<Moment> moments;
  final Moment? selectedMoment;
  final bool isLocationEnabled;
  final int locationFocusRequestId;
  final MapSurfaceBuilder mapBuilder;
  final ValueChanged<Moment> onMomentSelectedForPanel;
  final ValueChanged<Moment> onCompactMomentSelected;
  final VoidCallback onCloseSelectedMoment;
  final ValueChanged<MapCameraCenter> onCameraCenterChanged;
```

Не удаляй `_showMomentPreview`. Compact phone flow должен продолжать открывать bottom sheet preview, а `View details` внутри sheet должен открывать route.

### Шаг 6. Переписать `_MapContent.build` под side panel

В `map_screen.dart` добавь import:

```dart
import '../../../moments/presentation/widgets/moment_details_pane.dart';
```

Куда вставлять: замени тело `_MapContent.build`. Сохрани создание `map` через `mapBuilder`, потому что tests подменяют native Mapbox через provider override.

Код:

```dart
@override
Widget build(BuildContext context) {
  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final useSidePanel = AppBreakpoints.useSidePanel(size);
          final sidePanelWidth = AppBreakpoints.sidePanelWidth(size);

          final momentTapHandler = useSidePanel
              ? onMomentSelectedForPanel
              : onCompactMomentSelected;

          final map = Semantics(
            label: context.l10n.mapSemanticLabel,
            child: mapBuilder(
              moments: moments,
              isLocationEnabled: isLocationEnabled,
              locationFocusRequestId: locationFocusRequestId,
              onMomentSelected: momentTapHandler,
              onCameraCenterChanged: onCameraCenterChanged,
            ),
          );

          if (useSidePanel) {
            return Row(
              children: [
                Expanded(child: map),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: sidePanelWidth,
                  child: _MapSidePanel(
                    moments: moments,
                    selectedMoment: selectedMoment,
                    onMomentSelected: onMomentSelectedForPanel,
                    onCloseSelectedMoment: onCloseSelectedMoment,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: map),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 220,
                child: _NearbyMomentsPanel(
                  moments: moments,
                  onMomentSelected: onCompactMomentSelected,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
```

Здесь есть важное отличие:

```dart
final momentTapHandler = useSidePanel
    ? onMomentSelectedForPanel
    : onCompactMomentSelected;
```

Marker tap теперь зависит от layout. На телефоне он ведет себя как раньше. На tablet/landscape он обновляет side panel.

### Шаг 7. Добавить `_MapSidePanel`

Куда вставлять: в конец `map_screen.dart`, рядом с `_NearbyMomentsPanel`.

Код:

```dart
class _MapSidePanel extends StatelessWidget {
  const _MapSidePanel({
    required this.moments,
    required this.selectedMoment,
    required this.onMomentSelected,
    required this.onCloseSelectedMoment,
  });

  final List<Moment> moments;
  final Moment? selectedMoment;
  final ValueChanged<Moment> onMomentSelected;
  final VoidCallback onCloseSelectedMoment;

  @override
  Widget build(BuildContext context) {
    final selected = selectedMoment;
    if (selected != null) {
      return MomentDetailsPane(
        momentId: selected.id,
        onClose: onCloseSelectedMoment,
      );
    }

    return _NearbyMomentsPanel(
      moments: moments,
      onMomentSelected: onMomentSelected,
    );
  }
}
```

Почему panel показывает list, когда ничего не выбрано: пустой tablet screen с одним только map не подсказывает следующий шаг. Nearby list уже есть в приложении, поэтому используем его как master list.

Почему не показываем raw UUID в panel: `MomentDetailsPane` использует существующий `MomentDetailsContent`, а тот уже показывает автора только если есть `authorDisplayName`.

### Шаг 8. Стабилизировать media aspect ratio

Файл:

```text
lib/src/features/moments/presentation/widgets/moment_media_view.dart
```

Сейчас `MomentMediaView` уже использует `AspectRatio(4 / 3)`. В главе 15 добавим max height, чтобы media не съедал весь side panel на tablet и не создавал слишком высокий first viewport в tests.

Куда вставлять: проще заменить файл целиком. Это маленький widget, и так меньше риска получить двойной `AspectRatio` или разные placeholder размеры.

Код:

```dart
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';

class MomentMediaView extends StatelessWidget {
  const MomentMediaView({
    required this.moment,
    this.aspectRatio = 4 / 3,
    this.maxHeight = 360,
    super.key,
  });

  final Moment moment;
  final double aspectRatio;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = moment.mediaUrl;

    if (moment.mediaType == 'image' && mediaUrl != null) {
      return Semantics(
        image: true,
        label: context.l10n.momentMediaImageLabel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: _MediaFrame(
            aspectRatio: aspectRatio,
            maxHeight: maxHeight,
            child: Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const _MediaPlaceholder(
                  icon: Icons.broken_image_outlined,
                );
              },
            ),
          ),
        ),
      );
    }

    if (moment.mediaType == 'video' && mediaUrl != null) {
      return Semantics(
        image: true,
        label: context.l10n.momentMediaVideoLabel,
        child: _MediaFrame(
          aspectRatio: aspectRatio,
          maxHeight: maxHeight,
          child: const _MediaPlaceholder(
            icon: Icons.play_circle_outline,
          ),
        ),
      );
    }

    return Semantics(
      image: true,
      label: context.l10n.momentMediaMissingLabel,
      child: _MediaFrame(
        aspectRatio: aspectRatio,
        maxHeight: maxHeight,
        child: const _MediaPlaceholder(
          icon: Icons.image_not_supported_outlined,
        ),
      ),
    );
  }
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame({
    required this.aspectRatio,
    required this.maxHeight,
    required this.child,
  });

  final double aspectRatio;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: child,
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
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
    );
  }
}
```

Почему `ConstrainedBox` вместе с `AspectRatio`: aspect ratio задает форму, а max height защищает layout в узком panel и widget tests. Это не дает media вытеснить title/comments за пределы первого экрана слишком агрессивно.

### Шаг 9. Проверить длинные тексты EN/RU/ES

Локализация уже есть с главы 3, но tablet/landscape добавляют новые риски: короткая английская строка помещается, а русская или испанская может переноситься в две строки.

Проверь вручную:

1. Открой Settings.
2. Переключи English, Russian, Spanish.
3. Открой карту.
4. На широком viewport проверь side panel.
5. На узком viewport проверь app bar actions, permission banner и retry UI.

В коде избегай фиксированной высоты для текстовых строк, кроме icon-only toolbar buttons. Для buttons и panel header лучше позволить тексту переноситься или использовать icon button с tooltip.

Плохой пример:

```dart
SizedBox(
  height: 40,
  child: Text(context.l10n.selectedMomentEmpty),
)
```

Лучше:

```dart
Padding(
  padding: const EdgeInsets.all(AppSpacing.lg),
  child: Text(
    context.l10n.selectedMomentEmpty,
    textAlign: TextAlign.center,
  ),
)
```

### Шаг 10. Обновить widget tests под размеры экрана

Файл:

```text
test/widget_test.dart
```

Добавь helper рядом с другими test helpers:

```dart
Future<void> setTestSurfaceSize(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
```

Не используй старые `window.physicalSizeTestValue` APIs. В новых Flutter tests работаем через `tester.view`.

Добавь test для wide layout:

```dart
testWidgets('shows side detail panel on tablet width', (tester) async {
  await setTestSurfaceSize(tester, const Size(1180, 820));

  await pumpGeoMomentsApp(tester);

  expect(find.text('Nearby moments'), findsOneWidget);

  await tester.tap(find.text(testMoment.text));
  await tester.pumpAndSettle();

  expect(find.text('Selected moment'), findsOneWidget);
  expect(find.text('Moment details'), findsNothing);
});
```

Этот пример показывает идею. В реальном тесте не дублируй английские строки, если рядом уже используется generated localization. Можно загрузить:

```dart
final l10n = await AppLocalizations.delegate.load(const Locale('en'));
```

И проверять `l10n.selectedMomentTitle`.

Добавь test для compact layout:

```dart
testWidgets('keeps compact preview sheet on phone width', (tester) async {
  await setTestSurfaceSize(tester, const Size(390, 844));

  await pumpGeoMomentsApp(tester);
  await tester.tap(find.text(testMoment.text));
  await tester.pumpAndSettle();

  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  expect(find.text(l10n.viewMomentDetails), findsOneWidget);
});
```

Если нужный текст ниже scroll, используй уже знакомый прием:

```dart
await tester.ensureVisible(find.text(l10n.commentsTitle));
await tester.pumpAndSettle();
```

Scrollable details/settings tests остаются scroll-aware. Не возвращай ошибку прошлых глав, где test искал field, который находился ниже первого viewport.

### Шаг 11. Accessibility sanity

Минимум для этой главы:

- icon buttons имеют `tooltip`;
- карта имеет `Semantics(label: context.l10n.mapSemanticLabel)`;
- media имеет image/video/missing labels;
- close panel button имеет tooltip;
- touch targets остаются стандартными `IconButton`, `TextButton`, `FilledButton`, а не кастомными `GestureDetector` без semantics.

Для quick check можно добавить маленький widget test:

```dart
testWidgets('map exposes semantic label', (tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));

  await pumpGeoMomentsApp(tester);

  expect(
    find.bySemanticsLabel(l10n.mapSemanticLabel),
    findsOneWidget,
  );
});
```

Не стремись покрыть всю accessibility автоматическими tests в этой главе. Здесь цель - убрать очевидные пробелы, не построить полный audit pipeline.

## Проверка

Команды:

```bash
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

Ручная проверка телефона:

1. Открыть карту в portrait.
2. Tap по marker или item в nearby list.
3. Должен открыться bottom sheet preview.
4. Нажать `View details`.
5. Должен открыться route `/moments/:momentId`.
6. Details должен scroll-иться до comments.
7. Location button должен по-прежнему центрировать карту, если permission granted.

Ручная проверка tablet/landscape:

1. Запустить app на tablet или emulator с широким viewport.
2. Открыть карту.
3. Убедиться, что карта и side panel стоят рядом.
4. Выбрать moment на карте или в nearby list.
5. Side panel должен показать выбранный moment.
6. Close button должен вернуть panel к nearby list или empty state.
7. Bottom sheet не должен открываться в wide layout.
8. Notification tap из главы 13 должен по-прежнему открывать full details route.

Проверка локализации:

1. Переключить EN/RU/ES.
2. Проверить side panel title, empty state, close tooltip по возможности через hover/long press.
3. Проверить permission banner и retry UI, если легко воспроизвести.
4. Убедиться, что длинные строки не обрезаются в panel header и settings.

## Частые ошибки

### Ошибка: `/moments/new` снова открывает details

Причина: во время правок router случайно переставили routes.

Исправление: route `/moments/new` должен оставаться выше `/moments/:momentId`.

### Ошибка: tablet tap открывает bottom sheet

Причина: marker/list tap всегда вызывает `_showMomentPreview`.

Исправление: в `_MapContent` выбрать handler по layout:

```dart
final momentTapHandler = useSidePanel
    ? onMomentSelectedForPanel
    : onCompactMomentSelected;
```

### Ошибка: phone tap больше не открывает preview sheet

Причина: compact layout начал использовать side panel handler.

Исправление: compact layout должен вызывать `_showMomentPreview`, потому что phone flow из прошлых глав остается прежним.

### Ошибка: landscape карта стала слишком низкой

Причина: layout остался вертикальным `map + list` на широком, но низком экране.

Исправление: `AppBreakpoints.useSidePanel(size)` должен учитывать landscape width, а не только `width >= tablet`.

### Ошибка: details panel overflow-ится

Причина: `MomentDetailsContent` завернули в `Column` без `Expanded` или заменили его `ListView` на не-scrollable content.

Исправление: внутри panel content должен быть под `Expanded`, а сам details content остается scrollable.

### Ошибка: widget test не находит comments/details text

Причина: details scrollable, media занимает верхнюю часть viewport.

Исправление: использовать `tester.ensureVisible(...)` или drag по `ListView`, как в главах 8, 12 и 14.

### Ошибка: fake map/list tests перестали работать

Причина: `_MapContent` больше не использует `mapSurfaceBuilderProvider` или не передает `locationFocusRequestId`.

Исправление: map должен по-прежнему создаваться через `mapBuilder(...)`. Это нужно, чтобы native Mapbox не запускался в widget tests.

### Ошибка: автор снова отображается UUID

Причина: в side panel создали новый preview widget и вывели `authorId`.

Исправление: показывать `authorDisplayName`, если он не пустой. Если display name отсутствует, лучше ничего не показывать, чем raw UUID.

### Ошибка: media ломает высоту panel

Причина: `Image.network` вставлен без `AspectRatio` и `ConstrainedBox`.

Исправление: media должен иметь стабильный aspect ratio и max height.

### Ошибка: новые строки hardcoded в widgets

Причина: быстро добавили `Text('Selected moment')`.

Исправление: добавить ключи в EN/RU/ES ARB, выполнить `flutter gen-l10n`, использовать `context.l10n`.

### Ошибка: старые migrations изменили и ждут, что Supabase применит их заново

Причина: забыли правило migration history.

Исправление: в главе 15 migration обычно не нужна. Если вдруг понадобится database change, создать новый timestamp migration. Уже примененные файлы не переисполняются.

## Definition of Done

- `AppBreakpoints` умеет определять window class и side panel layout.
- Compact phone portrait сохраняет bottom sheet preview flow.
- Tablet/wide landscape показывает карту и side panel рядом.
- Marker/list tap в wide layout обновляет side panel, а не открывает bottom sheet.
- Full details route `/moments/:momentId` продолжает работать.
- Notification tap flow из главы 13 не сломан.
- `/moments/new` остается выше `/moments/:momentId`.
- Location button продолжает центрировать карту.
- Details/comments остаются scrollable.
- Media имеет стабильный aspect ratio и max height.
- Новые видимые/accessibility строки добавлены в EN/RU/ES ARB.
- Нет raw UUID автора в UI.
- Widget tests покрывают compact и tablet/wide layout.
- Tests используют fake map/provider overrides, а не настоящий Mapbox.
- `flutter gen-l10n` проходит.
- `dart format lib test` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка portrait, landscape/tablet и EN/RU/ES выполнена.

## Что прислать на ревью

После реализации напиши:

```text
Глава 15 готова, проверь код.
```

Я буду проверять:

- что wide layout действительно использует side panel;
- что compact flow не потерял bottom sheet и details route;
- что landscape не давит карту вертикальным list;
- что новые strings локализованы в EN/RU/ES;
- что media не ломает высоту details/panel;
- что accessibility labels/tooltips есть на новых интерактивных местах;
- что tests выставляют viewport через `tester.view`, а не deprecated APIs;
- что scrollable details/settings tests остались устойчивыми;
- что fake classes/provider overrides реально используются;
- что route order `/moments/new` не сломан;
- что location button по-прежнему центрирует карту;
- что details не падает из-за optional RPC/profile join;
- что автор не отображается UUID;
- что старые migration-файлы не менялись ради повторного применения.
