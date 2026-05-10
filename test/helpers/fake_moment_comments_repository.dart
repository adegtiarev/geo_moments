import 'package:geo_moments/src/features/moments/domain/entities/create_comment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment_comment.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_comments_repository.dart';

class FakeMomentCommentsRepository implements MomentCommentsRepository {
  const FakeMomentCommentsRepository();

  @override
  Future<List<MomentComment>> fetchCommentsPage({
    required String momentId,
    int limit = 20,
    DateTime? before,
  }) async {
    return const [];
  }

  @override
  Future<MomentComment> createComment(CreateCommentCommand command) async {
    return MomentComment(
      id: 'created-comment',
      momentId: command.momentId,
      authorId: 'test-user-id',
      parentId: command.parentId,
      body: command.body,
      createdAt: DateTime.utc(2026, 5, 9),
      authorDisplayName: 'Test User',
    );
  }
}
