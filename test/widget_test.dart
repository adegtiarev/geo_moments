import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/app/app.dart';
import 'package:geo_moments/src/app/localization/locale_controller.dart';

void main() {
  testWidgets('shows map screen on app start', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GeoMomentsApp()));

    expect(find.text('Geo Moments'), findsOneWidget);
    expect(find.text('Map placeholder'), findsOneWidget);
  });

  testWidgets('opens settings screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GeoMomentsApp()));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System'), findsWidgets);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('switches app language to Russian', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GeoMomentsApp()));

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
