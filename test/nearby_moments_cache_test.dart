import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/core/database/app_database.dart';
import 'package:geo_moments/src/features/map/domain/entities/map_camera_center.dart';
import 'package:geo_moments/src/features/moments/data/local/moments_cache.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';

void main() {
  test('nearby provider returns cached moments when remote fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);
    await cache.replaceNearbyMoments([
      Moment(
        id: 'cached-moment',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Cached moment',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        momentsRepositoryProvider.overrideWithValue(
          ThrowingMomentsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final moments = await container.read(
      nearbyMomentsProvider(MapCameraCenter.buenosAires).future,
    );

    expect(moments.single.id, 'cached-moment');
  });

  test('nearby provider refreshes stale cache with remote moments', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);
    await cache.replaceNearbyMoments([
      Moment(
        id: 'cached-moment',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Cached moment',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
      ),
    ]);

    final remoteMoment = Moment(
      id: 'remote-moment',
      authorId: 'author-1',
      latitude: -34.6037,
      longitude: -58.3816,
      text: 'Remote moment',
      mediaType: 'none',
      createdAt: DateTime.utc(2026, 5, 11),
    );
    final remoteResult = Completer<List<Moment>>();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        momentsRepositoryProvider.overrideWithValue(
          ControlledNearbyMomentsRepository(remoteResult.future),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = nearbyMomentsProvider(MapCameraCenter.buenosAires);
    final refreshed = Completer<List<Moment>>();
    final subscription = container.listen<AsyncValue<List<Moment>>>(provider, (
      previous,
      next,
    ) {
      final value = next.value;
      if (value != null &&
          value.single.id == 'remote-moment' &&
          !refreshed.isCompleted) {
        refreshed.complete(value);
      }
    });
    addTearDown(subscription.close);

    final first = await container.read(provider.future);
    expect(first.single.id, 'cached-moment');

    remoteResult.complete([remoteMoment]);

    final fresh = await refreshed.future;
    expect(fresh.single.id, 'remote-moment');
  });
}

class ControlledNearbyMomentsRepository implements MomentsRepository {
  const ControlledNearbyMomentsRepository(this.nearbyResult);

  final Future<List<Moment>> nearbyResult;

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    return nearbyResult;
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) {
    throw UnimplementedError();
  }
}

class ThrowingMomentsRepository implements MomentsRepository {
  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    throw StateError('offline');
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    throw StateError('offline');
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) {
    throw UnimplementedError();
  }
}
