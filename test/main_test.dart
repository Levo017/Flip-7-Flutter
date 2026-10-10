import 'package:flip7_flutter/main.dart';
import 'package:flip7_flutter/ui/game_screen.dart';
import 'package:flip7_flutter/ui/setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui/ui_helpers.dart';

void main() {
  testWidgets('the app goes from setup to a game and back', (tester) async {
    setSurface(tester, const Size(1280, 1100));
    await tester.pumpWidget(const Flip7App());
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'Flip 7: With a Vengeance');

    await tester.tap(find.text('START GAME'));
    await tester.pump();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('ROUND 1'), findsOneWidget);
    expect(find.text('Player 1'), findsWidgets);

    await tester.tap(find.text('NEW GAME'));
    await tester.pump();
    expect(find.byType(SetupScreen), findsOneWidget);

    // Unmounting disposes the controller and its timers.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Brutal Mode chosen at setup reaches the game', (tester) async {
    setSurface(tester, const Size(1280, 1100));
    await tester.pumpWidget(const Flip7App());
    await tester.tap(find.text('BRUTAL MODE'));
    await tester.pump();
    await tester.tap(find.text('START GAME'));
    await tester.pump();
    expect(find.text('ROUND 1 · BRUTAL MODE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
