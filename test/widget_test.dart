import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/app/app.dart';
import 'package:geo_moments/src/app/config/app_config.dart';
import 'package:geo_moments/src/app/localization/locale_controller.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:geo_moments/src/features/auth/presentation/controllers/auth_providers.dart';

void main() {
  const testAppConfig = AppConfig(
    supabaseUrl: 'https://test.supabase.co',
    supabaseAnonKey: 'test-anon-key',
    authRedirectUrl: 'test_redirect_url',
  );

  const testUser = AppUser(
    id: 'test-user-id',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  Widget buildTestApp({AppUser? currentUser = testUser}) {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testAppConfig),
        currentUserProvider.overrideWith((ref) => Stream.value(currentUser)),
      ],
      child: const GeoMomentsApp(),
    );
  }

  testWidgets('shows auth screen when signed out', (tester) async {
    await tester.pumpWidget(buildTestApp(currentUser: null));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shows map screen on app start', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Geo Moments'), findsOneWidget);
    expect(find.text('Map placeholder'), findsOneWidget);
  });

  testWidgets('opens settings screen', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System'), findsWidgets);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('Supabase configured: test.supabase.co'), findsOneWidget);
  });

  testWidgets('switches app language to Russian', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    // Open the language dropdown.
    await tester.tap(find.byType(DropdownMenu<LocalePreference>));
    await tester.pumpAndSettle();

    // Select Russian from the menu.
    await tester.tap(find.text('Russian').last);
    await tester.pumpAndSettle();

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Тема'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
  });
}
