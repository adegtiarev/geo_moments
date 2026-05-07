# 07 Map Screen

Статус: done.

## Источники

Эта глава опирается на актуальные docs и package pages:

- [Mapbox Maps SDK for Flutter](https://docs.mapbox.com/flutter/maps/guides/)
- [Mapbox Flutter installation](https://docs.mapbox.com/flutter/maps/guides/install/)
- [Mapbox Flutter camera and animation](https://docs.mapbox.com/flutter/maps/guides/camera-and-animation/camera/)
- [Mapbox Flutter annotations](https://docs.mapbox.com/flutter/maps/guides/markers-and-annotations/annotations/)
- [Mapbox Flutter location](https://docs.mapbox.com/flutter/maps/guides/user-location/)
- [mapbox_maps_flutter on pub.dev](https://pub.dev/packages/mapbox_maps_flutter)
- [permission_handler on pub.dev](https://pub.dev/packages/permission_handler)

На момент подготовки главы актуальная линия `mapbox_maps_flutter` - 2.23.x. В примерах ниже не используется устаревший `AnnotationOnClickListener`; для tap handling используются `tapEvents`. В Flutter-примерах также не используется deprecated `Color.value` и `withOpacity`.

## Что строим в этой главе

В главе 6 приложение уже читает seed moments из Supabase и показывает их списком. Теперь заменяем карту-placeholder на настоящую карту:

- подключаем Mapbox SDK;
- добавляем `MAPBOX_ACCESS_TOKEN` в конфигурацию;
- настраиваем Android/iOS permissions;
- создаем виджет карты на базе `MapWidget`;
- показываем seed moments как map annotations;
- обновляем список моментов при изменении центра карты;
- открываем bottom sheet по tap на marker;
- переключаем стиль карты под light/dark theme;
- сохраняем widget tests через test seam, чтобы тесты не зависели от native map view.

После главы главный экран должен быть уже похож на Geo Moments: карта занимает основной экран, рядом или снизу виден список моментов, а marker tap открывает карточку.

## Почему это важно

Карта - главный экран продукта. Но карта во Flutter - это не просто еще один widget.

Mapbox отображает карту через native SDK:

```text
Flutter widget tree
  -> platform view boundary
  -> Android/iOS native Mapbox view
  -> GPU rendering, gestures, camera, annotations
```

Из-за этого появляются темы, которых не было в обычном UI:

- lifecycle native controller;
- асинхронное создание annotation managers;
- permissions для location puck;
- ограничения widget tests;
- разница между координатами `latitude/longitude` в app domain и `longitude/latitude` в GeoJSON/Mapbox `Position`;
- camera events могут приходить часто, значит нельзя дергать backend на каждый pixel pan.

Мы построим карту так, чтобы UI оставался тестируемым, а Supabase data flow не протекал напрямую в map widget.

## Словарь главы

`Platform view` - нативный Android/iOS view, встроенный в Flutter UI.

`MapWidget` - Flutter widget из `mapbox_maps_flutter`, который создает native Mapbox map.

`MapboxMap` - controller карты. Через него создаются annotation managers, меняется style, читается camera state.

`CameraOptions` - начальная камера: center, zoom, bearing, pitch.

`CameraState` - текущее состояние камеры после pan/zoom.

`Annotation` - объект поверх карты. В этой главе используем circle annotations как markers для moments.

`Location puck` - стандартный индикатор текущего положения пользователя на карте.

`Access token` - публичный Mapbox token для mobile SDK. Это не service secret, но его нужно ограничивать настройками Mapbox token restrictions.

## 1. Почему Mapbox и что меняется в архитектуре

В `DECISIONS.md` уже зафиксировано предварительное решение: Mapbox.

Причины:

- хорошо выглядит для portfolio app;
- работает на Android и iOS;
- поддерживает стили карты;
- не требует привязывать карту к Google ecosystem.

До этой главы `MapScreen` был обычным Flutter layout:

```text
MapScreen
  -> MapPlaceholderPanel
  -> NearbyMomentsList
```

После главы будет:

```text
MapScreen
  -> MapboxMapPanel
  -> NearbyMomentsList
  -> MomentPreviewBottomSheet
```

При этом data flow остается прежним:

```text
Supabase RPC
  -> MomentsRepository
  -> nearbyMomentsProvider(center)
  -> MapScreen
  -> MapboxMapPanel annotations
```

Карта не должна сама ходить в Supabase. Она получает готовый `List<Moment>` и сообщает наружу события:

```dart
ValueChanged<MapCameraCenter> onCameraCenterChanged
ValueChanged<Moment> onMomentSelected
```

## 2. Platform views в Flutter

Обычный Flutter widget рисуется Flutter engine-ом. Platform view - это native view, встроенный в Flutter screen.

Минимальный пример:

```dart
MapWidget(
  key: const ValueKey('geoMomentsMap'),
  viewport: CameraViewportState(
    center: Point(coordinates: Position(-58.3816, -34.6037)),
    zoom: 12,
  ),
)
```

Что здесь важно:

- `Position` принимает сначала longitude, потом latitude;
- native map создается не мгновенно;
- controller доступен только после `onMapCreated`;
- в widget tests native view обычно не нужен и должен заменяться fake widget.

Частая ошибка:

```dart
// Неверно: latitude и longitude перепутаны местами.
Point(coordinates: Position(-34.6037, -58.3816))
```

Правильно:

```dart
// Buenos Aires: lng, lat.
Point(coordinates: Position(-58.3816, -34.6037))
```

## 3. Permissions и location

Карта может показывать данные без location permission. Разрешение нужно только для текущей позиции пользователя.

В этой главе:

- карта стартует на Buenos Aires, как и seed data;
- пользователь может разрешить location;
- после разрешения включаем location puck;
- автоматическое перемещение к GPS-позиции можно добавить позже, когда введем отдельный location service.

Почему не делаем все сразу:

- Mapbox location puck показывает позицию, но domain-level "current location" лучше получать отдельным сервисом;
- нам уже нужно закрыть markers, camera center, bottom sheet и tests;
- глава должна остаться управляемой.

## 4. Camera center как параметр provider-а

В главе 6 provider был hardcoded:

```dart
final nearbyMomentsProvider = FutureProvider<List<Moment>>((ref) {
  return repository.fetchNearbyMoments(
    latitude: -34.6037,
    longitude: -58.3816,
  );
});
```

Для карты центр должен приходить из camera:

```dart
final nearbyMomentsProvider =
    FutureProvider.family<List<Moment>, MapCameraCenter>((ref, center) {
  final repository = ref.watch(momentsRepositoryProvider);

  return repository.fetchNearbyMoments(
    latitude: center.latitude,
    longitude: center.longitude,
  );
});
```

`MapCameraCenter` должен иметь стабильные `==` и `hashCode`, чтобы Riverpod family не создавал бесконечно новые cache entries для одинаковых значений.

```dart
class MapCameraCenter {
  const MapCameraCenter({
    required this.latitude,
    required this.longitude,
  });

  static const buenosAires = MapCameraCenter(
    latitude: -34.6037,
    longitude: -58.3816,
  );

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    return other is MapCameraCenter &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
```

Для camera events мы еще добавим debounce. Backend не должен получать запрос на каждый drag event.

## 5. Annotation markers

В Mapbox есть несколько способов показывать точки:

- point annotations с image;
- circle annotations;
- symbol layers через style sources.

Для этой главы выбираем circle annotations:

- не нужен PNG asset для marker icon;
- легко покрасить под тему;
- хорошо подходит для seed moments;
- можно обрабатывать tap через `tapEvents`.

Минимальный пример:

```dart
final manager = await mapboxMap.annotations.createCircleAnnotationManager();

await manager.create(
  CircleAnnotationOptions(
    geometry: Point(coordinates: Position(-58.3816, -34.6037)),
    circleRadius: 9,
    circleColor: Theme.of(context).colorScheme.primary.toARGB32(),
    circleStrokeColor: Theme.of(context).colorScheme.surface.toARGB32(),
    circleStrokeWidth: 2,
    customData: const {'moment_id': 'moment-1'},
  ),
);
```

Обрати внимание на `toARGB32()`. В новых версиях Flutter не стоит использовать `Color.value`.

Tap handling:

```dart
manager.tapEvents(
  onTap: (annotation) {
    final momentId = annotation.customData?['moment_id'];
    // Найти Moment по id и открыть bottom sheet.
  },
);
```

Не используй старый listener-подход с `AnnotationOnClickListener`.

## Целевая структура после главы

```text
lib/
  src/
    app/
      bootstrap/
        bootstrap.dart
      config/
        app_config.dart
    features/
      map/
        domain/
          entities/
            map_camera_center.dart
        presentation/
          controllers/
            location_permission_controller.dart
          screens/
            map_screen.dart
          widgets/
            mapbox_map_panel.dart
            moment_preview_sheet.dart
            map_surface_builder.dart
      moments/
        presentation/
          controllers/
            moments_providers.dart
          widgets/
            nearby_moments_list.dart
```

`MapPlaceholderPanel` можно оставить временно только для previews или удалить, если он больше нигде не используется.

## Практика

### Шаг 1. Добавить зависимости

В `pubspec.yaml`:

```yaml
dependencies:
  mapbox_maps_flutter: ^2.23.0
  permission_handler: ^12.0.1
```

Затем:

```bash
flutter pub get
```

Если package versions уже ушли вперед, бери текущие stable версии из `pub.dev`, но после этого проверь changelog на deprecated API.

### Шаг 2. Добавить Mapbox token в env

В `.env.example`:

```text
MAPBOX_ACCESS_TOKEN=your-mapbox-public-token
```

В локальный `.env` добавь настоящий public token.

Важно:

- не коммить `.env`;
- не используй secret token в мобильном приложении;
- в Mapbox dashboard ограничь token под dev/prod приложения, когда дойдешь до release.

### Шаг 3. Обновить `AppConfig`

Файл:

```text
lib/src/app/config/app_config.dart
```

Добавь поле:

```dart
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.authRedirectUrl,
    required this.mapboxAccessToken,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String authRedirectUrl;
  final String mapboxAccessToken;
}
```

В `load()`:

```dart
final mapboxAccessToken = _requiredEnv('MAPBOX_ACCESS_TOKEN');

return AppConfig(
  supabaseUrl: supabaseUrl,
  supabaseAnonKey: supabaseAnonKey,
  authRedirectUrl: authRedirectUrl,
  mapboxAccessToken: mapboxAccessToken,
);
```

Token не валидируем как URL. Это обычная строка.

Не забудь обновить тестовый `AppConfig` в `test/widget_test.dart`.

### Шаг 4. Инициализировать Mapbox

Файл:

```text
lib/src/app/bootstrap/bootstrap.dart
```

Добавь import:

```dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
```

После загрузки config и до `runApp`:

```dart
MapboxOptions.setAccessToken(config.mapboxAccessToken);
```

Итоговая идея:

```dart
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
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

### Шаг 5. Android permissions

Файл:

```text
android/app/src/main/AndroidManifest.xml
```

Перед `<application>` добавь:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Для карты без location эти permissions не нужны, но для location puck нужны.

### Шаг 6. iOS permission description

Файл:

```text
ios/Runner/Info.plist
```

Внутри `<dict>` добавь:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Geo Moments uses your location to show nearby moments on the map.</string>
```

Если позже будешь настраивать iOS build на macOS, проверь `permission_handler` iOS macro setup по актуальной документации пакета. На Windows в этой главе достаточно Info.plist изменения и Android manual check.

### Шаг 7. Создать `MapCameraCenter`

Файл:

```text
lib/src/features/map/domain/entities/map_camera_center.dart
```

Код:

```dart
class MapCameraCenter {
  const MapCameraCenter({
    required this.latitude,
    required this.longitude,
  });

  static const buenosAires = MapCameraCenter(
    latitude: -34.6037,
    longitude: -58.3816,
  );

  final double latitude;
  final double longitude;

  bool isCloseTo(MapCameraCenter other) {
    const threshold = 0.0005;

    return (latitude - other.latitude).abs() < threshold &&
        (longitude - other.longitude).abs() < threshold;
  }

  @override
  bool operator ==(Object other) {
    return other is MapCameraCenter &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
```

`isCloseTo` нужен, чтобы не перезагружать moments при микродвижениях camera.

### Шаг 8. Сделать moments provider зависимым от центра

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

Обнови:

```dart
import '../../../map/domain/entities/map_camera_center.dart';
```

Provider:

```dart
final nearbyMomentsProvider =
    FutureProvider.family<List<Moment>, MapCameraCenter>((ref, center) {
  final repository = ref.watch(momentsRepositoryProvider);

  return repository.fetchNearbyMoments(
    latitude: center.latitude,
    longitude: center.longitude,
  );
});
```

После этого все места, где был `ref.watch(nearbyMomentsProvider)`, должны передавать center.

### Шаг 9. Создать permission controller

Файл:

```text
lib/src/features/map/presentation/controllers/location_permission_controller.dart
```

Код:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final locationPermissionControllerProvider =
    AsyncNotifierProvider<LocationPermissionController, PermissionStatus>(
  LocationPermissionController.new,
);

class LocationPermissionController extends AsyncNotifier<PermissionStatus> {
  @override
  Future<PermissionStatus> build() {
    return Permission.locationWhenInUse.status;
  }

  Future<PermissionStatus> request() async {
    state = const AsyncLoading();

    final nextStatus = await Permission.locationWhenInUse.request();
    state = AsyncData(nextStatus);

    return nextStatus;
  }
}
```

UI будет читать этот provider, а map panel будет включать location puck только если permission granted.

### Шаг 10. Создать test seam для карты

Native map не должен ломать widget tests. Сделаем provider, через который можно подменить карту в тестах.

Файл:

```text
lib/src/features/map/presentation/widgets/map_surface_builder.dart
```

Код:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../moments/domain/entities/moment.dart';
import '../../domain/entities/map_camera_center.dart';
import 'mapbox_map_panel.dart';

typedef MapSurfaceBuilder = Widget Function({
  required List<Moment> moments,
  required bool isLocationEnabled,
  required ValueChanged<Moment> onMomentSelected,
  required ValueChanged<MapCameraCenter> onCameraCenterChanged,
});

final mapSurfaceBuilderProvider = Provider<MapSurfaceBuilder>((ref) {
  return ({
    required moments,
    required isLocationEnabled,
    required onMomentSelected,
    required onCameraCenterChanged,
  }) {
    return MapboxMapPanel(
      moments: moments,
      isLocationEnabled: isLocationEnabled,
      onMomentSelected: onMomentSelected,
      onCameraCenterChanged: onCameraCenterChanged,
    );
  };
});
```

В production будет Mapbox, в widget tests - обычный `Container` с текстом.

### Шаг 11. Создать Mapbox panel

Файл:

```text
lib/src/features/map/presentation/widgets/mapbox_map_panel.dart
```

Базовый код:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../moments/domain/entities/moment.dart';
import '../../domain/entities/map_camera_center.dart';

class MapboxMapPanel extends StatefulWidget {
  const MapboxMapPanel({
    required this.moments,
    required this.isLocationEnabled,
    required this.onMomentSelected,
    required this.onCameraCenterChanged,
    super.key,
  });

  final List<Moment> moments;
  final bool isLocationEnabled;
  final ValueChanged<Moment> onMomentSelected;
  final ValueChanged<MapCameraCenter> onCameraCenterChanged;

  @override
  State<MapboxMapPanel> createState() => _MapboxMapPanelState();
}

class _MapboxMapPanelState extends State<MapboxMapPanel> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  Timer? _cameraDebounce;
  late ViewportState _viewport;
  String? _lastStyleUri;

  @override
  void initState() {
    super.initState();

    _viewport = CameraViewportState(
      center: Point(
        coordinates: Position(
          MapCameraCenter.buenosAires.longitude,
          MapCameraCenter.buenosAires.latitude,
        ),
      ),
      zoom: 12,
    );
  }

  @override
  void didUpdateWidget(covariant MapboxMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.moments != widget.moments) {
      unawaited(_renderMomentMarkers());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextStyleUri = _styleUriFor(context);
    if (_lastStyleUri != null && _lastStyleUri != nextStyleUri) {
      unawaited(_mapboxMap?.style.setStyleURI(nextStyleUri));
    }
    _lastStyleUri = nextStyleUri;
  }

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: MapWidget(
        key: const ValueKey('geoMomentsMap'),
        styleUri: _styleUriFor(context),
        viewport: _viewport,
        onMapCreated: _onMapCreated,
        onCameraChangeListener: _onCameraChanged,
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _circleAnnotationManager =
        await mapboxMap.annotations.createCircleAnnotationManager();

    _circleAnnotationManager?.tapEvents(
      onTap: (annotation) {
        final momentId = annotation.customData?['moment_id'];
        final selectedMoment = widget.moments.where((moment) {
          return moment.id == momentId;
        }).firstOrNull;

        if (selectedMoment != null) {
          widget.onMomentSelected(selectedMoment);
        }
      },
    );

    await _renderMomentMarkers();
  }

  void _onCameraChanged(CameraChangedEventData _) {
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 500), () async {
      final cameraState = await _mapboxMap?.getCameraState();
      final center = cameraState?.center;

      if (center == null || !mounted) {
        return;
      }

      _switchToIdleViewport();

      widget.onCameraCenterChanged(
        MapCameraCenter(
          latitude: center.coordinates.lat.toDouble(),
          longitude: center.coordinates.lng.toDouble(),
        ),
      );
    });
  }

  void _switchToIdleViewport() {
    if (_viewport is IdleViewportState) {
      return;
    }

    setState(() {
      _viewport = const IdleViewportState();
    });
  }

  Future<void> _renderMomentMarkers() async {
    final manager = _circleAnnotationManager;
    if (manager == null || !mounted) {
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final markerColor = colorScheme.primary.toARGB32();
    final strokeColor = colorScheme.surface.toARGB32();

    await manager.deleteAll();

    final options = widget.moments.map((moment) {
      return CircleAnnotationOptions(
        geometry: Point(
          coordinates: Position(moment.longitude, moment.latitude),
        ),
        circleRadius: 9,
        circleColor: markerColor,
        circleStrokeColor: strokeColor,
        circleStrokeWidth: 2,
        customData: {'moment_id': moment.id},
      );
    }).toList();

    await manager.createMulti(options);
  }

  String _styleUriFor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? MapboxStyles.DARK
        : MapboxStyles.STANDARD;
  }
}
```

Если analyzer в твоей версии SDK покажет, что `lat/lng` accessors отличаются, открой generated API docs для `Position` и поправь только этот участок. Смысл должен остаться тем же: Mapbox хранит center как `Position(lng, lat)`, а наш app domain хранит `latitude/longitude`.

Важный lifecycle-момент: стартовый `CameraViewportState` нельзя заново создавать в каждом `build`, иначе при refresh данных карта будет возвращаться в начальную точку. Поэтому `_viewport` хранится в state, а после первого движения пользователя переключается в `IdleViewportState`.

### Шаг 12. Включить location puck внутри `MapboxMapPanel`

Этот шаг делает только одну вещь: включает или выключает стандартную точку текущего положения пользователя на карте.

Важно: location puck - это не загрузка nearby moments и не перемещение карты к пользователю. Это только визуальный индикатор текущей позиции, если пользователь дал permission.

В шагах 10-11 мы уже подготовили параметр:

```dart
final bool isLocationEnabled;
```

Пока этот bool просто приходит в `MapboxMapPanel`. Теперь нужно применить его к native Mapbox map.

Внутри `_MapboxMapPanelState` добавь helper:

```dart
Future<void> _syncLocationPuck() async {
  final mapboxMap = _mapboxMap;
  if (mapboxMap == null) {
    return;
  }

  await mapboxMap.location.updateSettings(
    LocationComponentSettings(
      enabled: widget.isLocationEnabled,
      pulsingEnabled: widget.isLocationEnabled,
    ),
  );
}
```

Почему отдельный helper:

- его нужно вызвать после создания карты;
- его нужно вызвать еще раз, если permission изменится;
- так настройки location puck не дублируются в двух местах.

Теперь обнови `_onMapCreated`. Сразу после `_mapboxMap = mapboxMap;` вызови helper:

```dart
Future<void> _onMapCreated(MapboxMap mapboxMap) async {
  _mapboxMap = mapboxMap;

  await _syncLocationPuck();

  _circleAnnotationManager =
      await mapboxMap.annotations.createCircleAnnotationManager();

  // tapEvents и _renderMomentMarkers остаются как в шаге 11.
}
```

Теперь обнови `didUpdateWidget`. Этот метод вызывается, когда parent widget пересобрал `MapboxMapPanel` с новыми параметрами. Если `isLocationEnabled` изменился, синхронизируем native location puck. Если изменился список моментов, перерисовываем markers:

```dart
@override
void didUpdateWidget(covariant MapboxMapPanel oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (oldWidget.isLocationEnabled != widget.isLocationEnabled) {
    unawaited(_syncLocationPuck());
  }

  if (oldWidget.moments != widget.moments) {
    unawaited(_renderMomentMarkers());
  }
}
```

На этом шаге мы еще не решаем, откуда берется `isLocationEnabled`. Здесь мы только научили `MapboxMapPanel` реагировать на этот bool. Связку с `locationPermissionControllerProvider` сделаем в шаге 15, когда будем собирать весь `MapScreen`.

### Шаг 13. Bottom sheet для marker tap

Файл:

```text
lib/src/features/map/presentation/widgets/moment_preview_sheet.dart
```

Код:

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../moments/domain/entities/moment.dart';

class MomentPreviewSheet extends StatelessWidget {
  const MomentPreviewSheet({
    required this.moment,
    super.key,
  });

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(moment.text, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(moment.authorDisplayName ?? moment.authorId),
            if (moment.emotion != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(moment.emotion!),
            ],
          ],
        ),
      ),
    );
  }
}
```

В `MapScreen`:

```dart
void _showMomentPreview(Moment moment) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return MomentPreviewSheet(moment: moment);
    },
  );
}
```

В следующей главе этот preview станет полноценной карточкой/детальным экраном.

### Шаг 14. Обновить `NearbyMomentsList`

В главе 6 список сам читал provider:

```dart
final moments = ref.watch(nearbyMomentsProvider);
```

После перехода на карту это неудобно: и карта, и список должны показывать один и тот же набор moments. Поэтому provider будет читать `MapScreen`, а `NearbyMomentsList` станет обычным `StatelessWidget`, который получает готовый список.

```dart
class NearbyMomentsList extends StatelessWidget {
  const NearbyMomentsList({
    required this.moments,
    super.key,
  });

  final List<Moment> moments;
}
```

Так проще держать карту и список синхронными: один `AsyncValue` в `MapScreen`, один `List<Moment>` для карты и side panel.

### Шаг 15. Обновить `MapScreen`

Теперь собираем все части в главном экране.

До этой главы `MapScreen` был `StatelessWidget`: экран не хранил свое состояние и не читал Riverpod providers напрямую.

Теперь экрану нужны две вещи:

- читать providers: `nearbyMomentsProvider`, `mapSurfaceBuilderProvider`, `locationPermissionControllerProvider`;
- хранить локальное состояние `_center`, потому что центр карты меняется при pan/zoom.

Для такой ситуации Riverpod дает `ConsumerStatefulWidget`.

Минимальная разница:

```dart
class ExampleScreen extends ConsumerStatefulWidget {
  const ExampleScreen({super.key});

  @override
  ConsumerState<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends ConsumerState<ExampleScreen> {
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(someProvider);
    return Text('$value');
  }
}
```

Что здесь происходит:

- `ConsumerStatefulWidget` - это версия `StatefulWidget` с Riverpod support;
- `_ExampleScreenState` - объект состояния, который живет дольше одного `build`;
- в `ConsumerState` есть `ref`, поэтому можно делать `ref.watch(...)`;
- локальные поля вроде `_center` хранятся в state class;
- `setState(...)` сообщает Flutter, что локальное состояние изменилось и экран надо пересобрать.

В нашем случае:

```text
Mapbox camera changed
  -> MapboxMapPanel вызывает onCameraCenterChanged
  -> _MapScreenState._updateCenter вызывает setState
  -> build читает nearbyMomentsProvider(_center)
  -> карта и список получают новые moments
```

Ниже полный учебный skeleton `MapScreen`. Его можно перенести в `lib/src/features/map/presentation/screens/map_screen.dart` и затем совместить с существующими imports/layout helpers.

```dart
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapCameraCenter _center = MapCameraCenter.buenosAires;
  List<Moment> _visibleMoments = const [];
  bool _hasLoadedMoments = false;

  @override
  Widget build(BuildContext context) {
    // 1. Moments зависят от текущего центра карты.
    final moments = ref.watch(nearbyMomentsProvider(_center));

    // 2. Через builder мы сможем подменить native Mapbox в widget tests.
    final mapBuilder = ref.watch(mapSurfaceBuilderProvider);

    // 3. Permission provider говорит, можно ли включить location puck.
    final permission = ref.watch(locationPermissionControllerProvider);
    final isLocationEnabled = permission.when(
      data: (status) => status.isGranted,
      error: (_, _) => false,
      loading: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mapTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.enableLocation,
            onPressed: () {
              // Запрашиваем permission по явному действию пользователя.
              ref.read(locationPermissionControllerProvider.notifier).request();
            },
            icon: const Icon(Icons.my_location_outlined),
          ),
          IconButton(
            tooltip: context.l10n.settingsTooltip,
            onPressed: () => context.push(AppRoutePaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: moments.when(
        loading: () {
          if (!_hasLoadedMoments) {
            return const Center(child: CircularProgressIndicator());
          }

          return _MapContent(
            moments: _visibleMoments,
            isLocationEnabled: isLocationEnabled,
            mapBuilder: mapBuilder,
            onMomentSelected: _showMomentPreview,
            onCameraCenterChanged: _updateCenter,
          );
        },
        error: (error, _) {
          if (_hasLoadedMoments) {
            return _MapContent(
              moments: _visibleMoments,
              isLocationEnabled: isLocationEnabled,
              mapBuilder: mapBuilder,
              onMomentSelected: _showMomentPreview,
              onCameraCenterChanged: _updateCenter,
            );
          }

          return Center(child: Text(context.l10n.nearbyMomentsLoadError));
        },
        data: (items) {
          _visibleMoments = items;
          _hasLoadedMoments = true;

          return _MapContent(
            moments: items,
            // Этот bool пройдет дальше в MapboxMapPanel.
            isLocationEnabled: isLocationEnabled,
            mapBuilder: mapBuilder,
            onMomentSelected: _showMomentPreview,
            onCameraCenterChanged: _updateCenter,
          );
        },
      ),
    );
  }

  void _updateCenter(MapCameraCenter nextCenter) {
    // Не дергаем backend из-за микродвижений камеры.
    if (_center.isCloseTo(nextCenter)) {
      return;
    }

    setState(() {
      _center = nextCenter;
    });
  }

  void _showMomentPreview(Moment moment) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => MomentPreviewSheet(moment: moment),
    );
  }
}
```

Куда именно добавляется кнопка permission:

```dart
actions: [
  IconButton(
    tooltip: context.l10n.enableLocation,
    onPressed: () {
      ref.read(locationPermissionControllerProvider.notifier).request();
    },
    icon: const Icon(Icons.my_location_outlined),
  ),
  IconButton(
    tooltip: context.l10n.settingsTooltip,
    onPressed: () => context.push(AppRoutePaths.settings),
    icon: const Icon(Icons.settings_outlined),
  ),
],
```

То есть это обычная кнопка в правой части `AppBar`. При нажатии она вызывает `request()` у controller-а из шага 9. Если пользователь разрешил location, provider отдаст `PermissionStatus.granted`, `isLocationEnabled` станет `true`, `_MapContent` передаст это значение в `MapboxMapPanel`, а шаг 12 включит location puck через `mapboxMap.location.updateSettings(...)`.

Для production UX можно позже сохранять старую карту на экране при loading нового center. В этой главе достаточно рабочего варианта.

### Шаг 16. Сохранить responsive layout

Phone:

```text
map
list below
```

Tablet:

```text
map | side panel
```

В `_MapContent` используй тот же подход, который уже был в главе 2. Здесь как раз видно, где вызывается `mapBuilder(...)`:

```dart
class _MapContent extends StatelessWidget {
  const _MapContent({
    required this.moments,
    required this.isLocationEnabled,
    required this.mapBuilder,
    required this.onMomentSelected,
    required this.onCameraCenterChanged,
  });

  final List<Moment> moments;
  final bool isLocationEnabled;
  final MapSurfaceBuilder mapBuilder;
  final ValueChanged<Moment> onMomentSelected;
  final ValueChanged<MapCameraCenter> onCameraCenterChanged;

  @override
  Widget build(BuildContext context) {
    final map = mapBuilder(
      moments: moments,
      isLocationEnabled: isLocationEnabled,
      onMomentSelected: onMomentSelected,
      onCameraCenterChanged: onCameraCenterChanged,
    );

    final sidePanel = _NearbyMomentsPanel(
      moments: moments,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = AppBreakpoints.isTabletWidth(
              constraints.maxWidth,
            );

            if (isTablet) {
              return Row(
                children: [
                  Expanded(child: map),
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(width: 360, child: sidePanel),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: map),
                const SizedBox(height: AppSpacing.md),
                SizedBox(height: 220, child: sidePanel),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

`_NearbyMomentsPanel` теперь тоже принимает готовый список:

```dart
class _NearbyMomentsPanel extends StatelessWidget {
  const _NearbyMomentsPanel({
    required this.moments,
  });

  final List<Moment> moments;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.nearbyMomentsTitle, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: NearbyMomentsList(moments: moments),
            ),
          ],
        ),
      ),
    );
  }
}
```

В итоге цепочка такая:

```text
_MapScreenState.build
  -> вычисляет isLocationEnabled
  -> передает isLocationEnabled в _MapContent
  -> _MapContent вызывает mapBuilder(...)
  -> mapSurfaceBuilderProvider создает MapboxMapPanel
  -> MapboxMapPanel включает/выключает location puck
```

Если оставить в виде короткого примера, responsive layout выглядит так:

```dart
if (isTablet) {
  return Row(
    children: [
      Expanded(child: map),
      const SizedBox(width: AppSpacing.lg),
      SizedBox(width: 360, child: sidePanel),
    ],
  );
}

return Column(
  children: [
    Expanded(child: map),
    const SizedBox(height: AppSpacing.md),
    SizedBox(height: 220, child: sidePanel),
  ],
);
```

Не вкладывай карту в декоративную card. Карта - основной рабочий surface.

### Шаг 17. Локализация новых строк

Добавь keys в ARB:

```json
"nearbyMomentsLoadError": "Could not load moments.",
"enableLocation": "Enable location",
"locationPermissionDenied": "Location permission is denied."
```

И переводы RU/ES.

В UI не показывай технический exception пользователю. Подробный error можно логировать позже, когда добавим logging.

### Шаг 18. Обновить widget tests

Так как `nearbyMomentsProvider` стал family:

```dart
nearbyMomentsProvider.overrideWith((ref, center) async => testMoments)
```

Подмени native map:

```dart
mapSurfaceBuilderProvider.overrideWithValue(
  ({
    required moments,
    required isLocationEnabled,
    required onMomentSelected,
    required onCameraCenterChanged,
  }) {
    return const Center(child: Text('Test map surface'));
  },
),
```

Проверка:

```dart
expect(find.text('Test map surface'), findsOneWidget);
expect(find.text('Test coffee moment'), findsOneWidget);
```

Так widget test проверяет Flutter layout и data flow, но не запускает native Mapbox view.

## Проверка

Команды:

```bash
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

Ручная проверка Android:

1. Убедиться, что `.env` содержит `MAPBOX_ACCESS_TOKEN`.
2. Запустить приложение.
3. Войти через Supabase auth, если сессии нет.
4. Увидеть настоящую карту вместо placeholder.
5. Увидеть seed moments как markers.
6. Потянуть карту и проверить, что список не ломается.
7. Нажать marker и увидеть bottom sheet.
8. Переключить light/dark theme в Settings и вернуться на карту.
9. Нажать enable location, если добавлена кнопка, и увидеть system permission dialog.
10. Denied/granted state не должен ломать карту.

iOS:

- проверить Info.plist изменения;
- полноценную ручную проверку выполнить позже на macOS/iPhone, когда будет доступна iOS сборка.

## Частые ошибки

### Ошибка: карта пустая или показывает Mapbox token error

Причины:

- `MAPBOX_ACCESS_TOKEN` не добавлен в `.env`;
- `MapboxOptions.setAccessToken` не вызывается до создания `MapWidget`;
- token создан не с теми scopes/restrictions.

### Ошибка: markers появляются в океане

Причина: перепутаны latitude и longitude.

В domain:

```dart
moment.latitude
moment.longitude
```

В Mapbox `Position`:

```dart
Position(moment.longitude, moment.latitude)
```

### Ошибка: backend дергается слишком часто при движении карты

Причина: provider center обновляется на каждый camera event.

Решение: debounce и `isCloseTo`.

### Ошибка: widget tests падают из-за native view

Причина: тест пытается создать реальный `MapWidget`.

Решение: `mapSurfaceBuilderProvider.overrideWithValue(...)`.

### Ошибка: tap по marker не открывает sheet

Проверь:

- `customData` содержит `moment_id`;
- `tapEvents` зарегистрирован после создания manager;
- `widget.moments` содержит момент с таким id;
- не используется старый deprecated listener API.

### Ошибка: permission dialog не появляется

Проверь:

- Android permissions добавлены перед `<application>`;
- iOS `NSLocationWhenInUseUsageDescription` добавлен;
- app reinstall выполнен после изменения manifest/plist;
- permission уже был denied ранее и система больше не показывает dialog.

## Definition of Done

- `mapbox_maps_flutter` и `permission_handler` добавлены.
- `MAPBOX_ACCESS_TOKEN` добавлен в `.env.example` и локальный `.env`.
- `AppConfig` читает Mapbox token.
- `bootstrap` вызывает `MapboxOptions.setAccessToken`.
- Android/iOS location permission config добавлен.
- `MapCameraCenter` создан.
- `nearbyMomentsProvider` зависит от camera center.
- `MapboxMapPanel` показывает настоящую карту.
- Seed moments отображаются как annotations.
- Marker tap открывает bottom sheet.
- Light/dark theme меняет map style.
- Widget tests не создают native map и проходят через fake map surface.
- `flutter gen-l10n` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная Android-проверка карты выполнена.

## Что я буду проверять в ревью

- Нет ли Mapbox/Supabase calls прямо в неуместных widgets.
- Не перепутаны ли `latitude/longitude`.
- Нет ли deprecated API: `AnnotationOnClickListener`, `Color.value`, `withOpacity`.
- Camera events не создают flood backend-запросов.
- Native map заменяется fake surface в widget tests.
- Bottom sheet открывается по marker tap, а не по list item only.
- Token не попал в Git.
- Light/dark map styles соответствуют app theme.

Когда закончишь, напиши:

```text
Глава 7 готова, проверь код.
```
