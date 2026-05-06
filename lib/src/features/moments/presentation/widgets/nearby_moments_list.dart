import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';

class NearbyMomentsList extends StatelessWidget {
  const NearbyMomentsList({required this.moments, super.key});

  final List<Moment> moments;

  @override
  Widget build(BuildContext context) {
    if (moments.isEmpty) {
      return Center(child: Text(context.l10n.nearbyMomentsEmpty));
    }

    return ListView.separated(
      itemCount: moments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final moment = moments[index];

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(moment.text),
          subtitle: Text(moment.authorDisplayName ?? moment.authorId),
          leading: const Icon(Icons.place_outlined),
        );
      },
    );
  }
}
