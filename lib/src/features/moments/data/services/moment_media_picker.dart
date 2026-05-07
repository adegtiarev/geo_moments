import '../../domain/entities/picked_moment_media.dart';

abstract interface class MomentMediaPicker {
  Future<PickedMomentMedia?> pickImageFromGallery();
  Future<PickedMomentMedia?> takePhoto();
  Future<PickedMomentMedia?> pickVideoFromGallery();
  Future<PickedMomentMedia?> recordVideo();
  Future<PickedMomentMedia?> retrieveLostData();
}
