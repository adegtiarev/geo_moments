import '../../domain/entities/moment_comment.dart';

class MomentCommentDto {
  const MomentCommentDto({
    required this.id,
    required this.momentId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  final String id;
  final String momentId;
  final String authorId;
  final String? parentId;
  final String body;
  final DateTime createdAt;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  factory MomentCommentDto.fromJson(Map<String, dynamic> json) {
    return MomentCommentDto(
      id: json['id'] as String,
      momentId: json['moment_id'] as String,
      authorId: json['author_id'] as String,
      parentId: json['parent_id'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorDisplayName: json['author_display_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
    );
  }

  MomentComment toDomain() {
    return MomentComment(
      id: id,
      momentId: momentId,
      authorId: authorId,
      parentId: parentId,
      body: body,
      createdAt: createdAt,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
    );
  }
}
