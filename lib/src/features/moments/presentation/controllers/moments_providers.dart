import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/retry_policy.dart';
import '../../../map/domain/entities/map_camera_center.dart';
import '../../data/local/moments_cache.dart';
import '../../data/repositories/supabase_moment_comments_repository.dart';
import '../../data/repositories/supabase_moment_likes_repository.dart';
import '../../data/repositories/supabase_moments_repository.dart';
import '../../data/services/moment_media_storage.dart';
import '../../data/services/supabase_moment_media_storage.dart';
import '../../domain/entities/moment.dart';
import '../../domain/repositories/moment_comments_repository.dart';
import '../../domain/repositories/moment_likes_repository.dart';
import '../../domain/repositories/moments_repository.dart';

final momentsRepositoryProvider = Provider<MomentsRepository>((ref) {
  return SupabaseMomentsRepository(ref.watch(supabaseClientProvider));
});

final nearbyMomentsProvider =
    AsyncNotifierProvider.family<
      NearbyMomentsController,
      List<Moment>,
      MapCameraCenter
    >(NearbyMomentsController.new);

class NearbyMomentsController extends AsyncNotifier<List<Moment>> {
  NearbyMomentsController(this._center);

  final MapCameraCenter _center;

  @override
  Future<List<Moment>> build() async {
    final cache = ref.watch(momentsCacheProvider);
    final cached = await cache.readNearbyMoments();

    if (cached.isNotEmpty) {
      unawaited(_refreshFromRemote(fallback: cached));
      return cached;
    }

    return _refreshFromRemote();
  }

  Future<List<Moment>> _refreshFromRemote({List<Moment>? fallback}) async {
    final repository = ref.read(momentsRepositoryProvider);
    final retryPolicy = ref.read(retryPolicyProvider);
    final cache = ref.read(momentsCacheProvider);

    try {
      final fresh = await retryPolicy.run(
        () => repository.fetchNearbyMoments(
          latitude: _center.latitude,
          longitude: _center.longitude,
        ),
      );

      await cache.replaceNearbyMoments(fresh);
      state = AsyncData(fresh);
      return fresh;
    } catch (error, stackTrace) {
      final cached =
          fallback ??
          switch (state) {
            AsyncData(:final value) => value,
            _ => null,
          };
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final momentDetailsProvider =
    AsyncNotifierProvider.family<MomentDetailsController, Moment, String>(
      MomentDetailsController.new,
    );

class MomentDetailsController extends AsyncNotifier<Moment> {
  MomentDetailsController(this._momentId);

  final String _momentId;

  @override
  Future<Moment> build() async {
    final cache = ref.watch(momentsCacheProvider);
    final cached = await cache.readMomentById(_momentId);

    if (cached != null) {
      unawaited(_refreshFromRemote(fallback: cached));
      return cached;
    }

    return _refreshFromRemote();
  }

  Future<Moment> _refreshFromRemote({Moment? fallback}) async {
    final repository = ref.read(momentsRepositoryProvider);
    final retryPolicy = ref.read(retryPolicyProvider);
    final cache = ref.read(momentsCacheProvider);

    try {
      final moment = await retryPolicy.run(
        () => repository.fetchMomentById(_momentId),
      );
      await cache.upsertMoment(moment);
      state = AsyncData(moment);
      return moment;
    } catch (error, stackTrace) {
      final cached = fallback ?? await cache.readMomentById(_momentId);
      if (cached != null) {
        return cached;
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final momentMediaStorageProvider = Provider<MomentMediaStorage>((ref) {
  return SupabaseMomentMediaStorage(ref.watch(supabaseClientProvider));
});

final momentLikesRepositoryProvider = Provider<MomentLikesRepository>((ref) {
  return SupabaseMomentLikesRepository(ref.watch(supabaseClientProvider));
});

final momentCommentsRepositoryProvider = Provider<MomentCommentsRepository>((
  ref,
) {
  return SupabaseMomentCommentsRepository(ref.watch(supabaseClientProvider));
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});

final momentsCacheProvider = Provider<MomentsCache>((ref) {
  return MomentsCache(ref.watch(appDatabaseProvider));
});
