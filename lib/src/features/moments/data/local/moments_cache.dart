import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/moment.dart';

class MomentsCache {
  const MomentsCache(this._database);

  final AppDatabase _database;

  Future<List<Moment>> readNearbyMoments({int limit = 50}) async {
    final query = _database.select(_database.cachedMoments)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_rowToDomain).toList();
  }

  Future<Moment?> readMomentById(String id) async {
    final query = _database.select(_database.cachedMoments)
      ..where((table) => table.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    return _rowToDomain(row);
  }

  Future<void> replaceNearbyMoments(List<Moment> moments) async {
    final cachedAt = DateTime.now().toUtc();

    await _database.transaction(() async {
      await _database.delete(_database.cachedMoments).go();
      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _database.cachedMoments,
          moments.map((moment) => _toCompanion(moment, cachedAt)).toList(),
        );
      });
    });
  }

  Future<void> upsertMoment(Moment moment) async {
    await _database
        .into(_database.cachedMoments)
        .insertOnConflictUpdate(_toCompanion(moment, DateTime.now().toUtc()));
  }

  Moment _rowToDomain(CachedMoment row) {
    return Moment(
      id: row.id,
      authorId: row.authorId,
      latitude: row.latitude,
      longitude: row.longitude,
      text: row.body,
      mediaType: row.mediaType,
      createdAt: row.createdAt,
      emotion: row.emotion,
      mediaUrl: row.mediaUrl,
      authorDisplayName: row.authorDisplayName,
      authorAvatarUrl: row.authorAvatarUrl,
      likeCount: row.likeCount,
      commentCount: row.commentCount,
    );
  }

  CachedMomentsCompanion _toCompanion(Moment moment, DateTime cachedAt) {
    return CachedMomentsCompanion.insert(
      id: moment.id,
      authorId: moment.authorId,
      latitude: moment.latitude,
      longitude: moment.longitude,
      body: moment.text,
      mediaType: moment.mediaType,
      createdAt: moment.createdAt,
      cachedAt: cachedAt,
      emotion: Value(moment.emotion),
      mediaUrl: Value(moment.mediaUrl),
      authorDisplayName: Value(moment.authorDisplayName),
      authorAvatarUrl: Value(moment.authorAvatarUrl),
      likeCount: Value(moment.likeCount),
      commentCount: Value(moment.commentCount),
    );
  }
}
