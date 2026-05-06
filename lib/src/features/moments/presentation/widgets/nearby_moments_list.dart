import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../controllers/moments_providers.dart';

class NearbyMomentsList extends ConsumerWidget {
  const NearbyMomentsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moments = ref.watch(nearbyMomentsProvider);

    return moments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Could not load moments: $error'),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(context.l10n.nearbyMomentsEmpty));
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final moment = items[index];

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(moment.text),
              subtitle: Text(moment.authorDisplayName ?? moment.authorId),
              leading: const Icon(Icons.place_outlined),
            );
          },
        );
      },
    );
  }
}
