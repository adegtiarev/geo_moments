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
    );
  }
}