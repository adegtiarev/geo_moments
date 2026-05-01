import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/localization/app_localizations_context.dart';

class BackendStatusTile extends ConsumerWidget {
  const BackendStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final host = Uri.parse(config.supabaseUrl).host;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cloud_done_outlined),
      title: Text(context.l10n.backendSettingTitle),
      subtitle: Text(context.l10n.backendConfigured(host)),
    );
  }
}
