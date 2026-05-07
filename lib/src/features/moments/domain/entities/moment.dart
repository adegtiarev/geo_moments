class Moment {
  const Moment({
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
}