import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../controllers/moments_providers.dart';
import '../widgets/moment_details_content.dart';
import '../widgets/moment_details_skeleton.dart';
import '../widgets/moment_error_view.dart';

class MomentDetailsScreen extends ConsumerWidget {
  const MomentDetailsScreen({required this.momentId, super.key});

  final String momentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moment = ref.watch(momentDetailsProvider(momentId));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.momentDetailsTitle)),
      body: moment.when(
        loading: () => const MomentDetailsSkeleton(),
        error: (error, _) => MomentErrorView(
          error: error,
          onRetry: () => ref.invalidate(momentDetailsProvider(momentId)),
        ),
        data: (moment) => MomentDetailsContent(moment: moment),
      ),
    );
  }
}
