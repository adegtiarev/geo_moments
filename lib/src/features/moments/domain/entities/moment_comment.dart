class MomentComment {
  const MomentComment({
    required this.id,
    required this.momentId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.replies = const [],
  });

  final String id;
  final String momentId;
  final String authorId;
  final String? parentId;
  final String body;
  final DateTime createdAt;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final List<MomentComment> replies;

  bool get isReply => parentId != null;

  MomentComment copyWith({List<MomentComment>? replies}) {
    return MomentComment(
      id: id,
      momentId: momentId,
      authorId: authorId,
      parentId: parentId,
      body: body,
      createdAt: createdAt,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      replies: replies ?? this.replies,
    );
  }
}
