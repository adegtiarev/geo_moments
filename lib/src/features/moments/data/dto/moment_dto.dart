import '../../domain/entities/moment.dart';

class MomentDto {
  const MomentDto({
    required this.id,
    required this.authorId,
    required this.latitude,
    required this.longitude,
    required this.text,
    required this.mediaType,
    required this.createdAt,
    this.emotion,
    this.mediaUrl,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String authorId;
  final double latitude;
  final double longitude;
  final String text;
  final String mediaType;
  final DateTime createdAt;
  final String? emotion;
  final String? mediaUrl;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final int likeCount;
  final int commentCount;

  factory MomentDto.fromJson(Map<String, dynamic> json) {
    return MomentDto(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      text: json['text'] as String,
      mediaType: json['media_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      emotion: json['emotion'] as String?,
      mediaUrl: json['media_url'] as String?,
      authorDisplayName: json['author_display_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory MomentDto.fromDetailsJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    final profileJson = profile is Map<String, dynamic> ? profile : null;

    return MomentDto(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      text: json['text'] as String,
      mediaType: json['media_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      emotion: json['emotion'] as String?,
      mediaUrl: json['media_url'] as String?,
      authorDisplayName: profileJson?['display_name'] as String?,
      authorAvatarUrl: profileJson?['avatar_url'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    );
  }

  Moment toDomain() {
    return Moment(
      id: id,
      authorId: authorId,
      latitude: latitude,
      longitude: longitude,
      text: text,
      mediaType: mediaType,
      createdAt: createdAt,
      emotion: emotion,
      mediaUrl: mediaUrl,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      likeCount: likeCount,
      commentCount: commentCount,
    );
  }
}