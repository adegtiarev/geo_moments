import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class CachedMoments extends Table {
  TextColumn get id => text()();
  TextColumn get authorId => text().named('author_id')();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get body => text().named('text')();
  TextColumn get emotion => text().nullable()();
  TextColumn get mediaUrl => text().named('media_url').nullable()();
  TextColumn get mediaType => text().named('media_type')();
  TextColumn get authorDisplayName =>
      text().named('author_display_name').nullable()();
  TextColumn get authorAvatarUrl =>
      text().named('author_avatar_url').nullable()();
  IntColumn get likeCount =>
      integer().named('like_count').withDefault(const Constant(0))();
  IntColumn get commentCount =>
      integer().named('comment_count').withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedMoments])
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'geo_moments_cache',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
