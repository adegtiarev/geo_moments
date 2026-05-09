class CreateCommentCommand {
  const CreateCommentCommand({
    required this.momentId,
    required this.body,
    this.parentId,
  });

  final String momentId;
  final String body;
  final String? parentId;

  bool get isReply => parentId != null;
}
