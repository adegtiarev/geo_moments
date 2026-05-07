import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_breakpoints.dart';
import '../../../../core/ui/app_spacing.dart';
import '../controllers/create_moment_draft_controller.dart';
import '../widgets/create_moment_media_preview.dart';

class CreateMomentScreen extends ConsumerStatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  ConsumerState<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends ConsumerState<CreateMomentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textController;
  late final TextEditingController _emotionController;

  @override
  void initState() {
    super.initState();

    final draft = ref.read(createMomentDraftControllerProvider);
    _textController = TextEditingController(text: draft.text);
    _emotionController = TextEditingController(text: draft.emotion);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createMomentDraftControllerProvider.notifier).restoreLostData();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _emotionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(createMomentDraftControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.createMomentTitle),
        actions: [
          TextButton(
            onPressed: () => _saveDraft(context, draft.canSaveDraft),
            child: Text(context.l10n.saveDraft),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = AppBreakpoints.isTabletWidth(constraints.maxWidth);
            final maxWidth = isTablet ? 720.0 : double.infinity;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    CreateMomentMediaPreview(
                      media: draft.media,
                      onClear: () {
                        ref
                            .read(createMomentDraftControllerProvider.notifier)
                            .clearMedia();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MediaActions(onError: _showPickError),
                    const SizedBox(height: AppSpacing.lg),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _textController,
                            decoration: InputDecoration(
                              labelText: context.l10n.createMomentTextLabel,
                              border: const OutlineInputBorder(),
                            ),
                            maxLines: 4,
                            maxLength: 280,
                            textInputAction: TextInputAction.newline,
                            onChanged: (value) {
                              ref
                                  .read(
                                    createMomentDraftControllerProvider
                                        .notifier,
                                  )
                                  .updateText(value);
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return context.l10n.createMomentTextRequired;
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _emotionController,
                            decoration: InputDecoration(
                              labelText: context.l10n.createMomentEmotionLabel,
                              border: const OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.done,
                            onChanged: (value) {
                              ref
                                  .read(
                                    createMomentDraftControllerProvider
                                        .notifier,
                                  )
                                  .updateEmotion(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _saveDraft(BuildContext context, bool canSaveDraft) {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || !canSaveDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createMomentDraftInvalid)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.createMomentDraftSaved)),
    );
    context.pop();
  }

  void _showPickError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.createMomentMediaPickError)),
    );
  }
}

class _MediaActions extends ConsumerWidget {
  const _MediaActions({required this.onError});

  final void Function(BuildContext context) onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createMomentDraftControllerProvider.notifier);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          onPressed: () => _runPicker(context, controller.pickImageFromGallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(context.l10n.pickPhoto),
        ),
        OutlinedButton.icon(
          onPressed: () => _runPicker(context, controller.takePhoto),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(context.l10n.takePhoto),
        ),
        OutlinedButton.icon(
          onPressed: () => _runPicker(context, controller.pickVideoFromGallery),
          icon: const Icon(Icons.video_library_outlined),
          label: Text(context.l10n.pickVideo),
        ),
        OutlinedButton.icon(
          onPressed: () => _runPicker(context, controller.recordVideo),
          icon: const Icon(Icons.videocam_outlined),
          label: Text(context.l10n.recordVideo),
        ),
      ],
    );
  }

  Future<void> _runPicker(
    BuildContext context,
    Future<void> Function() pick,
  ) async {
    try {
      await pick();
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      onError(context);
    }
  }
}
