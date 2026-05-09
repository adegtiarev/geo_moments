import '../entities/create_comment_command.dart';
import '../entities/moment_comment.dart';

abstract interface class MomentCommentsRepository {
  Future<List<MomentComment>> fetchCommentsPage({
    required String momentId,
    int limit = 20,
    DateTime? before,
  });

  Future<MomentComment> createComment(CreateCommentCommand command);
}
