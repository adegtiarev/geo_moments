import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../controllers/auth_providers.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAction = ref.watch(authControllerProvider);
    final isLoading = authAction.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.appTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle(),
                    icon: const Icon(Icons.login_outlined),
                    label: Text(context.l10n.signInWithGoogle),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithApple(),
                    icon: const Icon(Icons.login_outlined),
                    label: Text(context.l10n.signInWithApple),
                  ),
                  if (authAction.hasError) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.authErrorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
