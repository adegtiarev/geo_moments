import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/image_picker_moment_media_picker.dart';
import '../../data/services/moment_media_picker.dart';
import '../../domain/entities/create_moment_draft.dart';
import '../../domain/entities/picked_moment_media.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) {
  return ImagePicker();
});

final momentMediaPickerProvider = Provider<MomentMediaPicker>((ref) {
  return ImagePickerMomentMediaPicker(ref.watch(imagePickerProvider));
});

final createMomentDraftControllerProvider =
    NotifierProvider<CreateMomentDraftController, CreateMomentDraft>(
      CreateMomentDraftController.new,
    );

class CreateMomentDraftController extends Notifier<CreateMomentDraft> {
  @override
  CreateMomentDraft build() {
    return const CreateMomentDraft();
  }

  void updateText(String value) {
    state = state.copyWith(text: value);
  }

  void updateEmotion(String value) {
    state = state.copyWith(emotion: value);
  }

  void clearMedia() {
    state = state.copyWith(clearMedia: true);
  }

  void reset() {
    state = const CreateMomentDraft();
  }

  Future<void> pickImageFromGallery() {
    return _pickMedia(
      () => ref.read(momentMediaPickerProvider).pickImageFromGallery(),
    );
  }

  Future<void> takePhoto() async {
    final granted = await _ensureCameraPermission();
    if (!granted) {
      return;
    }

    await _pickMedia(() => ref.read(momentMediaPickerProvider).takePhoto());
  }

  Future<void> pickVideoFromGallery() {
    return _pickMedia(
      () => ref.read(momentMediaPickerProvider).pickVideoFromGallery(),
    );
  }

  Future<void> recordVideo() async {
    final granted = await _ensureCameraPermission();
    if (!granted) {
      return;
    }

    await _pickMedia(() => ref.read(momentMediaPickerProvider).recordVideo());
  }

  Future<void> restoreLostData() {
    return _pickMedia(
      () => ref.read(momentMediaPickerProvider).retrieveLostData(),
    );
  }

  Future<void> _pickMedia(Future<PickedMomentMedia?> Function() pick) async {
    final media = await pick();
    if (media == null) {
      return;
    }

    state = state.copyWith(media: media);
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
}
