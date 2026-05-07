import 'picked_moment_media.dart';

class CreateMomentDraft {
  const CreateMomentDraft({this.text = '', this.emotion = '', this.media});

  final String text;
  final String emotion;
  final PickedMomentMedia? media;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasMedia => media != null;
  bool get canSaveDraft => hasText && hasMedia;

  CreateMomentDraft copyWith({
    String? text,
    String? emotion,
    PickedMomentMedia? media,
    bool clearMedia = false,
  }) {
    return CreateMomentDraft(
      text: text ?? this.text,
      emotion: emotion ?? this.emotion,
      media: clearMedia ? null : media ?? this.media,
    );
  }
}
