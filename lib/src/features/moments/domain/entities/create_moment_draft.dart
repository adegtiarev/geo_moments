import 'picked_moment_media.dart';

class CreateMomentDraft {
  const CreateMomentDraft({
    this.text = '',
    this.emotion = '',
    this.media,
    this.latitude,
    this.longitude,
  });

  final String text;
  final String emotion;
  final PickedMomentMedia? media;
  final double? latitude;
  final double? longitude;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasMedia => media != null;
  bool get hasLocation => latitude != null && longitude != null;
  bool get canSubmit => hasText && hasMedia && hasLocation;

  CreateMomentDraft copyWith({
    String? text,
    String? emotion,
    PickedMomentMedia? media,
    double? latitude,
    double? longitude,
    bool clearMedia = false,
  }) {
    return CreateMomentDraft(
      text: text ?? this.text,
      emotion: emotion ?? this.emotion,
      media: clearMedia ? null : media ?? this.media,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
