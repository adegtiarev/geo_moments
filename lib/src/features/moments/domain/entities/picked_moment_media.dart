enum MomentMediaKind { image, video }

class PickedMomentMedia {
  const PickedMomentMedia({
    required this.kind,
    required this.path,
    required this.name,
    this.mimeType,
  });

  final MomentMediaKind kind;
  final String path;
  final String name;
  final String? mimeType;

  String get storageMediaType {
    return switch (kind) {
      MomentMediaKind.image => 'image',
      MomentMediaKind.video => 'video',
    };
  }
}
