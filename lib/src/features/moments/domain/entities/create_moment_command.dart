class CreateMomentCommand {
  const CreateMomentCommand({
    required this.authorId,
    required this.latitude,
    required this.longitude,
    required this.text,
    required this.mediaUrl,
    required this.mediaType,
    this.emotion,
  });

  final String authorId;
  final double latitude;
  final double longitude;
  final String text;
  final String? emotion;
  final String mediaUrl;
  final String mediaType;
}
