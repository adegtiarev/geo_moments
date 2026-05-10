import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger_provider.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../domain/entities/create_moment_command.dart';
import '../../domain/entities/moment.dart';
import '../../domain/entities/uploaded_moment_media.dart';
import 'create_moment_draft_controller.dart';
import 'moments_providers.dart';

enum CreateMomentSaveStep {
  idle,
  uploadingMedia,
  savingMoment,
  success,
  failure,
}

class CreateMomentSaveState {
  const CreateMomentSaveState({
    this.step = CreateMomentSaveStep.idle,
    this.createdMoment,
    this.error,
  });

  final CreateMomentSaveStep step;
  final Moment? createdMoment;
  final Object? error;

  bool get isSubmitting {
    return step == CreateMomentSaveStep.uploadingMedia ||
        step == CreateMomentSaveStep.savingMoment;
  }

  double? get progress {
    return switch (step) {
      CreateMomentSaveStep.uploadingMedia => 0.45,
      CreateMomentSaveStep.savingMoment => 0.85,
      CreateMomentSaveStep.success => 1,
      _ => null,
    };
  }
}

final createMomentSaveControllerProvider =
    NotifierProvider<CreateMomentSaveController, CreateMomentSaveState>(
      CreateMomentSaveController.new,
    );

class CreateMomentSaveController extends Notifier<CreateMomentSaveState> {
  @override
  CreateMomentSaveState build() {
    return const CreateMomentSaveState();
  }

  Future<Moment?> submit() async {
    final draft = ref.read(createMomentDraftControllerProvider);
    final media = draft.media;
    final latitude = draft.latitude;
    final longitude = draft.longitude;
    final currentUser = ref
        .read(currentUserProvider)
        .maybeWhen(data: (user) => user, orElse: () => null);

    if (media == null ||
        latitude == null ||
        longitude == null ||
        !draft.hasText ||
        currentUser == null) {
      state = const CreateMomentSaveState(step: CreateMomentSaveStep.failure);
      return null;
    }

    UploadedMomentMedia? uploadedMedia;

    try {
      state = const CreateMomentSaveState(
        step: CreateMomentSaveStep.uploadingMedia,
      );

      uploadedMedia = await ref
          .read(momentMediaStorageProvider)
          .upload(authorId: currentUser.id, media: media);

      state = const CreateMomentSaveState(
        step: CreateMomentSaveStep.savingMoment,
      );

      final moment = await ref
          .read(momentsRepositoryProvider)
          .createMoment(
            CreateMomentCommand(
              authorId: currentUser.id,
              latitude: latitude,
              longitude: longitude,
              text: draft.text,
              emotion: draft.emotion,
              mediaUrl: uploadedMedia.publicUrl,
              mediaType: uploadedMedia.mediaType,
            ),
          );

      try {
        await ref.read(momentsCacheProvider).upsertMoment(moment);
      } catch (error, stackTrace) {
        ref
            .read(appLoggerProvider)
            .warning(
              'Cache created moment failed',
              error: error,
              stackTrace: stackTrace,
              context: {'momentId': moment.id},
            );
      }

      ref.invalidate(nearbyMomentsProvider);
      ref.read(createMomentDraftControllerProvider.notifier).reset();

      state = CreateMomentSaveState(
        step: CreateMomentSaveStep.success,
        createdMoment: moment,
      );

      return moment;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning(
            'Create moment failed',
            error: error,
            stackTrace: stackTrace,
          );

      if (uploadedMedia != null) {
        await ref.read(momentMediaStorageProvider).remove(uploadedMedia.path);
      }

      state = CreateMomentSaveState(
        step: CreateMomentSaveStep.failure,
        error: error,
      );

      return null;
    }
  }
}
