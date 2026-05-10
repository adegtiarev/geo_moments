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
