import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../domain/entities/push_permission_status.dart';
import '../controllers/push_notifications_controller.dart';

class NotificationStatusTile extends ConsumerWidget {
  const NotificationStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pushNotificationsControllerProvider);

    return state.when(
      loading: () =>
          const ListTile(leading: CircularProgressIndicator(), title: Text('')),
      error: (_, _) => ListTile(
        leading: const Icon(Icons.notifications_off_outlined),
        title: Text(context.l10n.notificationsTitle),
        subtitle: Text(context.l10n.notificationsDisabled),
        trailing: IconButton(
          tooltip: context.l10n.retry,
          onPressed: () {
            ref
                .read(pushNotificationsControllerProvider.notifier)
                .requestAndRegister();
          },
          icon: const Icon(Icons.refresh_outlined),
        ),
      ),
      data: (status) {
        final enabled =
            status == PushPermissionStatus.authorized ||
            status == PushPermissionStatus.provisional;

        return ListTile(
          leading: Icon(
            enabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
          ),
          title: Text(context.l10n.notificationsTitle),
          subtitle: Text(
            enabled
                ? context.l10n.notificationsEnabled
                : context.l10n.notificationsDisabled,
          ),
          trailing: enabled
              ? null
              : TextButton(
                  onPressed: () {
                    ref
                        .read(pushNotificationsControllerProvider.notifier)
                        .requestAndRegister();
                  },
                  child: Text(context.l10n.notificationsAsk),
                ),
        );
      },
    );
  }
}
