import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../data/repositories/supabase_moments_repository.dart';
import '../../domain/entities/moment.dart';
import '../../domain/repositories/moments_repository.dart';

final momentsRepositoryProvider = Provider<MomentsRepository>((ref) {
  return SupabaseMomentsRepository(ref.watch(supabaseClientProvider));
});

final nearbyMomentsProvider = FutureProvider<List<Moment>>((ref) {
  final repository = ref.watch(momentsRepositoryProvider);

  return repository.fetchNearbyMoments(
    latitude: -34.6037,
    longitude: -58.3816,
  );
});