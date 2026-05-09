import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../../map/domain/entities/map_camera_center.dart';
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
    FutureProvider.family<List<Moment>, MapCameraCenter>((ref, center) {
      final repository = ref.watch(momentsRepositoryProvider);

      return repository.fetchNearbyMoments(
        latitude: center.latitude,
        longitude: center.longitude,
      );
    });

final momentDetailsProvider = FutureProvider.family<Moment, String>((ref, id) {
  final repository = ref.watch(momentsRepositoryProvider);
  return repository.fetchMomentById(id);
});

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
