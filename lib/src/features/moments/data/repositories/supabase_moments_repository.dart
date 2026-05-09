import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/create_moment_command.dart';
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

  @override
  Future<Moment> fetchMomentById(String id) async {
    final moment = await _fetchMomentDetails(id);

    try {
      final likeSummary = await _client.rpc<dynamic>(
        'moment_like_summary',
        params: {'target_moment_id': id},
      );
      final likeSummaryJson = Map<String, dynamic>.from(likeSummary as Map);

      final count = await _client.rpc<int>(
        'moment_comment_count',
        params: {'target_moment_id': id},
      );

      return moment.copyWith(
        likeCount: (likeSummaryJson['like_count'] as num).toInt(),
        commentCount: count,
      );
    } on PostgrestException {
      return moment;
    }
  }

  Future<Moment> _fetchMomentDetails(String id) async {
    try {
      final response = await _client
          .from('moments')
          .select('''
          id,
          author_id,
          latitude,
          longitude,
          text,
          emotion,
          media_url,
          media_type,
          created_at,
          profiles(display_name, avatar_url)
        ''')
          .eq('id', id)
          .single();

      return MomentDto.fromDetailsJson(response).toDomain();
    } on PostgrestException {
      final response = await _client
          .from('moments')
          .select('''
          id,
          author_id,
          latitude,
          longitude,
          text,
          emotion,
          media_url,
          media_type,
          created_at
        ''')
          .eq('id', id)
          .single();

      final moment = MomentDto.fromDetailsJson(response).toDomain();
      return _withAuthorProfile(moment);
    }
  }

  Future<Moment> _withAuthorProfile(Moment moment) async {
    try {
      final response = await _client
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', moment.authorId)
          .maybeSingle();

      if (response == null) {
        return moment;
      }

      return moment.copyWith(
        authorDisplayName: response['display_name'] as String?,
        authorAvatarUrl: response['avatar_url'] as String?,
      );
    } on PostgrestException {
      return moment;
    }
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) async {
    final response = await _client
        .from('moments')
        .insert({
          'author_id': command.authorId,
          'latitude': command.latitude,
          'longitude': command.longitude,
          'text': command.text.trim(),
          'emotion': _nullableTrim(command.emotion),
          'media_url': command.mediaUrl,
          'media_type': command.mediaType,
        })
        .select('''
        id,
        author_id,
        latitude,
        longitude,
        text,
        emotion,
        media_url,
        media_type,
        created_at,
        profiles(display_name, avatar_url)
      ''')
        .single();

    return MomentDto.fromDetailsJson(response).toDomain();
  }

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
