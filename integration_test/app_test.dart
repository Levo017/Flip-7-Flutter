// End-to-end UI test: runs the real app on a device or emulator and plays a
// whole round through the on-screen controls.
//
//   flutter test integration_test -d <device-id>
import 'package:flip7_flutter/main.dart';
import 'package:flip7_flutter/ui/card_view.dart';
import 'package:flip7_flutter/ui/game_screen.dart';
import 'package:flip7_flutter/ui/setup_screen.dart';
import 'package:flip7_flutter/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Whether the button showing [label] is on screen and enabled.
bool _enabled(WidgetTester tester, String label) {
  final text = find.text(label);
  if (text.evaluate().isEmpty) return false;
  final ink = find.ancestor(of: text, matching: find.byType(InkWell));
  return tester.widget<InkWell>(ink.first).onTap != null;
}

final _glowingCard = find.byWidgetPredicate(
  (w) => (w is MiniCard && w.pickable) || (w is PlayingCard && w.pickable),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a human can play a round from setup to the results', (
    tester,
  ) async {
    // Keep the run independent of the network.
    downloadFonts = false;
    await tester.pumpWidget(const Flip7App());
    expect(find.byType(SetupScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Tester');
    await tester.tap(find.text('START GAME'));
    await tester.pump();
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Fast mode is off'));
    await tester.pump();

    var flips = 0;
    var decisions = 0;
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (find.text('ROUND 1 RESULTS').evaluate().isEmpty) {
      expect(
        DateTime.now().isBefore(deadline),
        isTrue,
        reason: 'the round never finished',
      );
      await tester.pump(const Duration(milliseconds: 150));

      if (_enabled(tester, 'USE ACTION') || _enabled(tester, 'NEXT CARD')) {
        final confirm = _enabled(tester, 'USE ACTION') ? 'USE ACTION' : 'NEXT CARD';
        await tester.tap(find.text(confirm));
        decisions++;
      } else if (find.text('CHOOSE A CARD').evaluate().isNotEmpty) {
        await tester.ensureVisible(_glowingCard.first);
        await tester.tap(_glowingCard.first);
      } else if (find.text('MYSELF').evaluate().isNotEmpty) {
        await tester.tap(find.text('MYSELF'));
        decisions++;
      } else if (find.text('+15 FOR ME').evaluate().isNotEmpty) {
        await tester.tap(find.text('+15 FOR ME'));
        decisions++;
      } else if (flips >= 2 && _enabled(tester, 'STAY')) {
        await tester.tap(find.text('STAY'));
      } else if (_enabled(tester, 'FLIP A CARD')) {
        await tester.tap(find.text('FLIP A CARD'));
        flips++;
      }
    }

    expect(find.text('Scores are in'), findsOneWidget);
    expect(find.text('Tester'), findsWidgets);
    debugPrint('Round finished after $flips flips and $decisions other decisions.');

    await tester.tap(find.text('DEAL ROUND 2'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ROUND 1 RESULTS'), findsNothing);
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.tap(find.text('NEW GAME'));
    await tester.pump();
    expect(find.byType(SetupScreen), findsOneWidget);

    // Unmounting disposes the controller and its timers.
    await tester.pumpWidget(const SizedBox());
  });
}
