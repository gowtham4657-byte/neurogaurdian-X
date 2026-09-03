import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neuroguardian_app/app.dart';

void main() {
  testWidgets('NeuroGuardian shell renders live dashboard', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NeuroGuardianApp(skipSafetyGate: true)),
    );

    expect(find.text('NeuroGuardian X'), findsOneWidget);
    expect(find.text('No live signal yet'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Care'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
  });
}
