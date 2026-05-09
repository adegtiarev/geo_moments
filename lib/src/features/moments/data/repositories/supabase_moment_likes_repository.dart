import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/moment_like_summary.dart';
import '../../domain/repositories/moment_likes_repository.dart';
import '../dto/moment_like_summary_dto.dart';

class SupabaseMomentLikesRepository implements MomentLikesRepository {
  const SupabaseMomentLikesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MomentLikeSummary> fetchSummary(String momentId) {
    return _summaryRpc('moment_like_summary', momentId);
  }

  @override
  Future<MomentLikeSummary> likeMoment(String momentId) {
    return _summaryRpc('like_moment', momentId);
  }

  @override
  Future<MomentLikeSummary> unlikeMoment(String momentId) {
    return _summaryRpc('unlike_moment', momentId);
  }

  Future<MomentLikeSummary> _summaryRpc(
    String functionName,
    String momentId,
  ) async {
    final response = await _client.rpc<dynamic>(
      functionName,
      params: {'target_moment_id': momentId},
    );

    final json = Map<String, dynamic>.from(response as Map);
    return MomentLikeSummaryDto.fromJson(json).toDomain();
  }
}
