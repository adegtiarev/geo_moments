import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/core/database/app_database.dart';
import 'package:geo_moments/src/features/moments/data/local/moments_cache.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';

void main() {
  test('details provider returns cached moment when remote fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);
    await cache.upsertMoment(
      Moment(
        id: 'cached-moment',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Cached details',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
        authorDisplayName: 'Cached User',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        momentsRepositoryProvider.overrideWithValue(
          ThrowingMomentsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final moment = await container.read(
      momentDetailsProvider('cached-moment').future,
    );

    expect(moment.text, 'Cached details');
    expect(moment.authorDisplayName, 'Cached User');
  });

  test('details provider updates cached moment with remote details', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);
    await cache.upsertMoment(
      Moment(
        id: 'moment-1',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Cached details',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
      ),
    );

    final remoteMoment = Moment(
      id: 'moment-1',
      authorId: 'author-1',
      latitude: -34.6037,
      longitude: -58.3816,
      text: 'Remote details',
      mediaType: 'none',
      createdAt: DateTime.utc(2026, 5, 11),
      authorDisplayName: 'Remote User',
    );
    final remoteResult = Completer<Moment>();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        momentsRepositoryProvider.overrideWithValue(
          ControlledDetailsRepository(remoteResult.future),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = momentDetailsProvider('moment-1');
    final refreshed = Completer<Moment>();
    final subscription = container.listen<AsyncValue<Moment>>(provider, (
      previous,
      next,
    ) {
      final value = next.value;
      if (value != null &&
          value.text == 'Remote details' &&
          !refreshed.isCompleted) {
        refreshed.complete(value);
      }
    });
    addTearDown(subscription.close);

    final first = await container.read(provider.future);
    expect(first.text, 'Cached details');

    remoteResult.complete(remoteMoment);

    final fresh = await refreshed.future;
    expect(fresh.text, 'Remote details');
    expect(fresh.authorDisplayName, 'Remote User');
  });
}

class ControlledDetailsRepository implements MomentsRepository {
  const ControlledDetailsRepository(this.detailsResult);

  final Future<Moment> detailsResult;

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    return detailsResult;
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
