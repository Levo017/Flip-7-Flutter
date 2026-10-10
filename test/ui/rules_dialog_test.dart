import 'package:flip7_flutter/ui/rules_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_helpers.dart';

void main() {
  Future<void> open(WidgetTester tester, Size size) async {
    setSurface(tester, size);
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRules(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every section of the rules', (tester) async {
    await open(tester, const Size(1000, 2400));
    expect(find.text('How to play'), findsOneWidget);
    for (final title in [
      'THE BASICS',
      'THE DECK (108 CARDS)',
      'SPECIAL NUMBERS',
      'MODIFIERS (−2, −4, −6, −8, −10, ÷2)',
      'ACTIONS',
      'SCORING',
      'BRUTAL MODE',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.textContaining('Flip Four!'), findsOneWidget);
  });

  testWidgets('Got it closes the dialog', (tester) async {
    await open(tester, desktop);
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('scrolls on a phone instead of overflowing', (tester) async {
    await open(tester, phone);
    expect(find.text('GOT IT'), findsOneWidget);
    expect(find.text('BRUTAL MODE'), findsNothing, reason: 'below the fold');
    await tester.scrollUntilVisible(find.text('BRUTAL MODE'), 300);
    expect(find.text('BRUTAL MODE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
