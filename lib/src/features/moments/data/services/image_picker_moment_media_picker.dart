import 'package:image_picker/image_picker.dart';

import '../../domain/entities/picked_moment_media.dart';
import 'moment_media_picker.dart';

class ImagePickerMomentMediaPicker implements MomentMediaPicker {
  ImagePickerMomentMediaPicker(this._picker);

  final ImagePicker _picker;

  @override
  Future<PickedMomentMedia?> pickImageFromGallery() {
    return _pick(
      kind: MomentMediaKind.image,
      pick: () => _picker.pickImage(source: ImageSource.gallery),
    );
  }

  @override
  Future<PickedMomentMedia?> takePhoto() {
    return _pick(
      kind: MomentMediaKind.image,
      pick: () => _picker.pickImage(source: ImageSource.camera),
    );
  }

  @override
  Future<PickedMomentMedia?> pickVideoFromGallery() {
    return _pick(
      kind: MomentMediaKind.video,
      pick: () => _picker.pickVideo(source: ImageSource.gallery),
    );
  }

  @override
  Future<PickedMomentMedia?> recordVideo() {
    return _pick(
      kind: MomentMediaKind.video,
      pick: () => _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      ),
    );
  }

  @override
  Future<PickedMomentMedia?> retrieveLostData() async {
    final response = await _picker.retrieveLostData();

    if (response.exception != null) {
      throw response.exception!;
    }

    final files = response.files;
    if (files == null || files.isEmpty) {
      return null;
    }

    final file = files.first;
    return _fromXFile(file, _guessKind(file));
  }

  Future<PickedMomentMedia?> _pick({
    required MomentMediaKind kind,
    required Future<XFile?> Function() pick,
  }) async {
    final file = await pick();
    if (file == null) {
      return null;
    }

    return _fromXFile(file, kind);
  }

  PickedMomentMedia _fromXFile(XFile file, MomentMediaKind kind) {
    return PickedMomentMedia(
      kind: kind,
      path: file.path,
      name: file.name,
      mimeType: file.mimeType,
    );
  }

  MomentMediaKind _guessKind(XFile file) {
    final mimeType = file.mimeType;
    if (mimeType != null && mimeType.startsWith('video/')) {
      return MomentMediaKind.video;
    }

    final name = file.name.toLowerCase();
    if (name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.m4v')) {
      return MomentMediaKind.video;
    }

    return MomentMediaKind.image;
  }
}
