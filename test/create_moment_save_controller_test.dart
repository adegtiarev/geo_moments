import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/core/database/app_database.dart';
import 'package:geo_moments/src/features/moments/data/services/moment_media_storage.dart';
import 'package:geo_moments/src/features/moments/data/services/moment_media_picker.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';
import 'package:geo_moments/src/features/moments/domain/entities/picked_moment_media.dart';
import 'package:geo_moments/src/features/moments/domain/entities/uploaded_moment_media.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/create_moment_draft_controller.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/create_moment_save_controller.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:geo_moments/src/features/auth/presentation/controllers/auth_providers.dart';

void main() {
  const testUser = AppUser(
    id: 'user-id',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  test('removes uploaded media when moment insert fails', () async {
    final storage = FakeMomentMediaStorage();

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(const AsyncData(testUser)),
        momentMediaPickerProvider.overrideWithValue(FakeMomentMediaPicker()),
        momentMediaStorageProvider.overrideWithValue(storage),
        momentsRepositoryProvider.overrideWithValue(
          ThrowingMomentsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final draftController = container.read(
      createMomentDraftControllerProvider.notifier,
    );
    draftController
      ..setLocation(latitude: -34.6037, longitude: -58.3816)
      ..updateText('Test moment');
    await draftController.pickImageFromGallery();

    final result = await container
        .read(createMomentSaveControllerProvider.notifier)
        .submit();

    expect(result, isNull);
    expect(storage.removedPath, 'user-id/test.jpg');
    expect(
      container.read(createMomentSaveControllerProvider).step,
      CreateMomentSaveStep.failure,
    );
  });

  test('stores created moment in cache after successful submit', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(const AsyncData(testUser)),
        appDatabaseProvider.overrideWithValue(database),
        momentMediaPickerProvider.overrideWithValue(FakeMomentMediaPicker()),
        momentMediaStorageProvider.overrideWithValue(FakeMomentMediaStorage()),
        momentsRepositoryProvider.overrideWithValue(
          SuccessfulMomentsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final draftController = container.read(
      createMomentDraftControllerProvider.notifier,
    );
    draftController
      ..setLocation(latitude: -34.6037, longitude: -58.3816)
      ..updateText('Test moment');
    await draftController.pickImageFromGallery();

    final result = await container
        .read(createMomentSaveControllerProvider.notifier)
        .submit();

    final cached = await container
        .read(momentsCacheProvider)
        .readMomentById('created-moment');

    expect(result?.id, 'created-moment');
    expect(cached?.text, 'Test moment');
    expect(
      container.read(createMomentSaveControllerProvider).step,
      CreateMomentSaveStep.success,
    );
  });
}

class FakeMomentMediaPicker implements MomentMediaPicker {
  static const media = PickedMomentMedia(
    kind: MomentMediaKind.image,
    path: 'local/test.jpg',
    name: 'test.jpg',
    mimeType: 'image/jpeg',
  );

  @override
  Future<PickedMomentMedia?> pickImageFromGallery() async {
    return media;
  }

  @override
  Future<PickedMomentMedia?> pickVideoFromGallery() async {
    return media;
  }

  @override
  Future<PickedMomentMedia?> recordVideo() async {
    return media;
  }

  @override
  Future<PickedMomentMedia?> retrieveLostData() async {
    return null;
  }

  @override
  Future<PickedMomentMedia?> takePhoto() async {
    return media;
  }
}

class FakeMomentMediaStorage implements MomentMediaStorage {
  String? removedPath;

  @override
  Future<UploadedMomentMedia> upload({
    required String authorId,
    required PickedMomentMedia media,
  }) async {
    return const UploadedMomentMedia(
      path: 'user-id/test.jpg',
      publicUrl: 'https://example.com/test.jpg',
      mediaType: 'image',
    );
  }

  @override
  Future<void> remove(String path) async {
    removedPath = path;
  }
}

class ThrowingMomentsRepository implements MomentsRepository {
  @override
  Future<Moment> createMoment(CreateMomentCommand command) {
    throw StateError('insert failed');
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    throw UnimplementedError();
  }
}

class SuccessfulMomentsRepository implements MomentsRepository {
  @override
  Future<Moment> createMoment(CreateMomentCommand command) async {
    return Moment(
      id: 'created-moment',
      authorId: command.authorId,
      latitude: command.latitude,
      longitude: command.longitude,
      text: command.text,
      emotion: command.emotion,
      mediaUrl: command.mediaUrl,
      mediaType: command.mediaType,
      createdAt: DateTime.utc(2026, 5, 10),
      authorDisplayName: 'Test User',
    );
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    throw UnimplementedError();
  }
}
