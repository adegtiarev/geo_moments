import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/core/database/app_database.dart';
import 'package:geo_moments/src/features/moments/data/local/moments_cache.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';

void main() {
  test('stores and reads cached nearby moments', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);
    final moments = [
      Moment(
        id: 'moment-1',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Cached coffee',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
        authorDisplayName: 'Test User',
        likeCount: 2,
        commentCount: 1,
      ),
    ];

    await cache.replaceNearbyMoments(moments);

    final cached = await cache.readNearbyMoments();

    expect(cached, hasLength(1));
    expect(cached.single.id, 'moment-1');
    expect(cached.single.text, 'Cached coffee');
    expect(cached.single.authorDisplayName, 'Test User');
    expect(cached.single.likeCount, 2);
    expect(cached.single.commentCount, 1);
  });

  test('upserts moment details by id', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);

    await cache.upsertMoment(
      Moment(
        id: 'moment-1',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Initial text',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
      ),
    );

    await cache.upsertMoment(
      Moment(
        id: 'moment-1',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Updated text',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
      ),
    );

    final cached = await cache.readMomentById('moment-1');

    expect(cached?.text, 'Updated text');
  });
}
