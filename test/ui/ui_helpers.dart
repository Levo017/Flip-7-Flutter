import 'dart:math';

import 'package:flip7_flutter/game/game.dart';
import 'package:flip7_flutter/game_controller.dart';
import 'package:flip7_flutter/ui/game_screen.dart';
import 'package:flip7_flutter/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const desktop = Size(1280, 800);
const tablet = Size(900, 800);
const phone = Size(390, 844);

const leo = PlayerConfig('Leo', bot: false);
const ash = PlayerConfig('Ash', bot: true);
const blaze = PlayerConfig('Blaze', bot: true);
const cinder = PlayerConfig('Cinder', bot: true);

void setSurface(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Wraps a small widget in the app's theme for testing.
Widget host(Widget child) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(body: Center(child: child)),
);

/// Re-reads the game after a test has edited it directly.
Future<void> refresh(WidgetTester tester, GameController c) async {
  c
    ..toggleFast()
    ..toggleFast();
  await tester.pump();
}

/// A widget test with the game screen on a cleared table, where Leo (player 0)
/// is the human and acts first. [arrange] sets the position up before the
/// first frame.
void testGame(
  String description,
  Future<void> Function(WidgetTester tester, GameController c) body, {
  Size size = desktop,
  List<PlayerConfig> players = const [leo, ash, blaze, cinder],
  bool brutal = false,
  void Function(Game g)? arrange,
}) {
  testWidgets(description, (tester) async {
    setSurface(tester, size);
    final c = GameController(random: Random(3))..start(players, brutal: brutal);
    try {
      clearTable(c.game!);
      arrange?.call(c.game!);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: ListenableBuilder(
            listenable: c,
            builder: (context, _) => c.game == null
                ? const Scaffold(body: Text('NO GAME'))
                : GameScreen(controller: c),
          ),
        ),
      );
      await refresh(tester, c);
      await body(tester, c);
    } finally {
      c.dispose();
    }
  });
}

/// Lets the 650 ms step timer fire once and the frame after it settle.
Future<void> stepOnce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 400));
}
