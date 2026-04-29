import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/app/app.dart';

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
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });
}
