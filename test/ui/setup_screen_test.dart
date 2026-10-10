import 'package:flip7_flutter/game/game.dart';
import 'package:flip7_flutter/ui/setup_screen.dart';
import 'package:flip7_flutter/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_helpers.dart';

void main() {
  late List<PlayerConfig>? started;
  late bool? brutal;

  Future<void> pumpSetup(WidgetTester tester, {Size size = const Size(800, 1100)}) async {
    setSurface(tester, size);
    started = null;
    brutal = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: SetupScreen(
          onStart: (players, isBrutal) {
            started = players;
            brutal = isBrutal;
          },
        ),
      ),
    );
  }

  List<String> names(WidgetTester tester) => [
    for (final field in tester.widgetList<TextField>(find.byType(TextField)))
      field.controller!.text,
  ];

  testWidgets('offers one human and three CPU players by default', (
    tester,
  ) async {
    await pumpSetup(tester);
    expect(names(tester), ['Player 1', 'Ash', 'Blaze', 'Cinder']);
    expect(find.text('HUMAN'), findsOneWidget);
    expect(find.text('CPU'), findsNWidgets(3));
    expect(find.text('4 OF 8'), findsOneWidget);
  });

  testWidgets('starts the game with the chosen players', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.text('START GAME'));
    expect(started!.map((p) => p.name), ['Player 1', 'Ash', 'Blaze', 'Cinder']);
    expect(started!.map((p) => p.bot), [false, true, true, true]);
    expect(brutal, isFalse);
  });

  testWidgets('a seat toggles between CPU and human', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.text('CPU').first);
    await tester.pump();
    expect(find.text('HUMAN'), findsNWidgets(2));
    await tester.tap(find.text('HUMAN').first);
    await tester.pump();
    expect(find.text('HUMAN'), findsOneWidget);

    await tester.tap(find.text('START GAME'));
    expect(started!.map((p) => p.bot), [true, false, true, true]);
  });

  testWidgets('names can be edited, and a blank one falls back', (
    tester,
  ) async {
    await pumpSetup(tester);
    await tester.enterText(find.byType(TextField).at(0), '  Leo ');
    await tester.enterText(find.byType(TextField).at(1), '   ');
    await tester.tap(find.text('START GAME'));
    expect(started!.map((p) => p.name), ['Leo', 'Player 2', 'Blaze', 'Cinder']);
  });

  testWidgets('players can be added up to eight', (tester) async {
    await pumpSetup(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('+ ADD PLAYER'));
      await tester.pump();
    }
    expect(find.text('8 OF 8'), findsOneWidget);
    expect(names(tester).last, 'Player 8');

    await tester.tap(find.text('+ ADD PLAYER'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(8));

    await tester.tap(find.text('START GAME'));
    expect(started, hasLength(8));
    expect(started!.last.bot, isTrue);
  });

  testWidgets('players can be removed down to two', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.byTooltip('Remove player').at(1));
    await tester.pump();
    expect(names(tester), ['Player 1', 'Blaze', 'Cinder']);

    await tester.tap(find.byTooltip('Remove player').first);
    await tester.pump();
    expect(names(tester), ['Blaze', 'Cinder']);
    expect(find.text('2 OF 8'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove player').first);
    await tester.pump();
    expect(names(tester), ['Blaze', 'Cinder'], reason: 'two is the minimum');
  });

  testWidgets('Brutal Mode can be switched on and off', (tester) async {
    await pumpSetup(tester);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    await tester.tap(find.text('BRUTAL MODE'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    await tester.tap(find.text('START GAME'));
    expect(brutal, isTrue);

    await tester.tap(find.text('BRUTAL MODE'));
    await tester.pump();
    await tester.tap(find.text('START GAME'));
    expect(brutal, isFalse);
  });

  testWidgets('How to play opens the rules', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pumpAndSettle();
    expect(find.text('RULES & CARD GUIDE'), findsOneWidget);
  });

  testWidgets('fits a phone screen', (tester) async {
    await pumpSetup(tester, size: phone);
    expect(find.text('START GAME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
