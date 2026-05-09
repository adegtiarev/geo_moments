import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/picked_moment_media.dart';
import '../../domain/entities/uploaded_moment_media.dart';
import 'moment_media_storage.dart';

class SupabaseMomentMediaStorage implements MomentMediaStorage {
  const SupabaseMomentMediaStorage(this._client);

  static const bucket = 'moment-media';

  final SupabaseClient _client;

  @override
  Future<UploadedMomentMedia> upload({
    required String authorId,
    required PickedMomentMedia media,
  }) async {
    final path = _buildPath(authorId: authorId, media: media);

    await _client.storage
        .from(bucket)
        .upload(
          path,
          File(media.path),
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: media.mimeType,
          ),
        );

    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);

    return UploadedMomentMedia(
      path: path,
      publicUrl: publicUrl,
      mediaType: media.storageMediaType,
    );
  }

  @override
  Future<void> remove(String path) async {
    await _client.storage.from(bucket).remove([path]);
  }

  String _buildPath({
    required String authorId,
    required PickedMomentMedia media,
  }) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final extension = _extensionFor(media);

    return '$authorId/$timestamp$extension';
  }

  String _extensionFor(PickedMomentMedia media) {
    final dotIndex = media.name.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < media.name.length - 1) {
      return media.name.substring(dotIndex).toLowerCase();
    }

    return switch (media.kind) {
      MomentMediaKind.image => '.jpg',
      MomentMediaKind.video => '.mp4',
    };
  }
}
