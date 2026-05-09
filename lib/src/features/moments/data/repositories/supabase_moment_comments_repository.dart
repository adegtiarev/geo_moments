import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/create_comment_command.dart';
import '../../domain/entities/moment_comment.dart';
import '../../domain/repositories/moment_comments_repository.dart';
import '../dto/moment_comment_dto.dart';

class SupabaseMomentCommentsRepository implements MomentCommentsRepository {
  const SupabaseMomentCommentsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MomentComment>> fetchCommentsPage({
    required String momentId,
    int limit = 20,
    DateTime? before,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'moment_comments_page',
      params: {
        'target_moment_id': momentId,
        'page_limit': limit,
        'before_created_at': before?.toUtc().toIso8601String(),
      },
    );

    final flat = response
        .cast<Map<String, dynamic>>()
        .map(MomentCommentDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();

    return _toTree(flat);
  }

  @override
  Future<MomentComment> createComment(CreateCommentCommand command) async {
    final response = await _client.rpc<dynamic>(
      'create_moment_comment',
      params: {
        'target_moment_id': command.momentId,
        'comment_body': command.body,
        'parent_comment_id': command.parentId,
      },
    );

    final json = Map<String, dynamic>.from(response as Map);
    return MomentCommentDto.fromJson(json).toDomain();
  }

  List<MomentComment> _toTree(List<MomentComment> flat) {
    final roots = <String, MomentComment>{};
    final repliesByParent = <String, List<MomentComment>>{};

    for (final comment in flat) {
      final parentId = comment.parentId;
      if (parentId == null) {
        roots[comment.id] = comment;
      } else {
        repliesByParent.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    return roots.values.map((root) {
      return root.copyWith(replies: repliesByParent[root.id] ?? const []);
    }).toList();
  }
}
