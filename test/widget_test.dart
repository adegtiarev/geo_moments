import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/generated/l10n/app_localizations.dart';

import 'helpers/test_app.dart';
import 'helpers/test_data.dart';

void main() {
  testWidgets('shows auth screen when signed out', (tester) async {
    await pumpGeoMomentsTestApp(tester, currentUser: null);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shows map screen on app start', (tester) async {
    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Geo Moments'), findsOneWidget);
    expect(find.text('Test map surface'), findsOneWidget);
    expect(find.text(testMoment.text), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
  });

  testWidgets('opens moment details from initial notification', (tester) async {
    await pumpGeoMomentsTestApp(
      tester,
      initialNotificationMessage: const RemoteMessage(
        data: {'moment_id': 'test-moment-id'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Moment details'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text(testMoment.text), findsOneWidget);
  });

  testWidgets('keeps compact preview sheet on phone width', (tester) async {
    await setTestSurfaceSize(tester, const Size(390, 844));

    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text(testMoment.text));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.viewMomentDetails), findsOneWidget);
  });

  testWidgets('shows side detail panel on tablet width', (tester) async {
    await setTestSurfaceSize(tester, const Size(1180, 820));

    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.nearbyMomentsTitle), findsOneWidget);

    await tester.tap(find.text(testMoment.text));
    await tester.pumpAndSettle();

    expect(find.text(l10n.selectedMomentTitle), findsOneWidget);
    expect(find.text(l10n.momentDetailsTitle), findsNothing);
  });

  testWidgets('requests location and sends focus command to map', (
    tester,
  ) async {
    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Location enabled: false'), findsOneWidget);
    expect(find.text('Location focus: 0'), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.byTooltip(l10n.enableLocation));
    await tester.pumpAndSettle();

    expect(find.text('Location enabled: true'), findsOneWidget);
    expect(find.text('Location focus: 1'), findsOneWidget);
  });

  testWidgets('map exposes semantic label', (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.bySemanticsLabel(l10n.mapSemanticLabel), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('create moment route wins over moment details pattern', (
    tester,
  ) async {
    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create moment'));
    await tester.pumpAndSettle();

    expect(find.text('Create moment'), findsOneWidget);
    expect(find.text('Moment details'), findsNothing);
  });

  testWidgets('cached details remain visible when comments are unavailable', (
    tester,
  ) async {
    await setTestSurfaceSize(tester, const Size(390, 844));

    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text(testMoment.text));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text(testMoment.text), findsOneWidget);
  });
}
