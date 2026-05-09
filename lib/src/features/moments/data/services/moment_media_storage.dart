import '../../domain/entities/picked_moment_media.dart';
import '../../domain/entities/uploaded_moment_media.dart';

abstract interface class MomentMediaStorage {
  Future<UploadedMomentMedia> upload({
    required String authorId,
    required PickedMomentMedia media,
  });

  Future<void> remove(String path);
}
