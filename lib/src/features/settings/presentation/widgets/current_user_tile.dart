import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';

class CurrentUserTile extends ConsumerWidget {
  const CurrentUserTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(user?.bestDisplayName ?? context.l10n.unknownUser),
      subtitle: Text(user?.email ?? user?.id ?? ''),
    );
  }
}
