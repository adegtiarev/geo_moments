import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/moment.dart';
import '../../domain/repositories/moments_repository.dart';
import '../dto/moment_dto.dart';

class SupabaseMomentsRepository implements MomentsRepository {
  const SupabaseMomentsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'nearby_moments',
      params: {
        'center_lat': latitude,
        'center_lng': longitude,
        'limit_count': limit,
      },
    );

    return response
        .cast<Map<String, dynamic>>()
        .map(MomentDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();
  }
}