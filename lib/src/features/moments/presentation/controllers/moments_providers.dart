import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../../map/domain/entities/map_camera_center.dart';
import '../../data/repositories/supabase_moments_repository.dart';
import '../../domain/entities/moment.dart';
import '../../domain/repositories/moments_repository.dart';

final momentsRepositoryProvider = Provider<MomentsRepository>((ref) {
  return SupabaseMomentsRepository(ref.watch(supabaseClientProvider));
});

final nearbyMomentsProvider = FutureProvider.family<List<Moment>, MapCameraCenter>((ref, center) {
  final repository = ref.watch(momentsRepositoryProvider);

  return repository.fetchNearbyMoments(latitude: center.latitude, longitude: center.longitude);
});

final momentDetailsProvider = FutureProvider.family<Moment, String>((ref, id) {
  final repository = ref.watch(momentsRepositoryProvider);
  return repository.fetchMomentById(id);
});
