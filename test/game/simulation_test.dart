import 'dart:math';

import 'package:flip7_flutter/game/bot.dart';
import 'package:flip7_flutter/game/game.dart';
import 'package:flutter_test/flutter_test.dart';

int _cardsInPlay(Game g) {
  var held = 0;
  for (final task in g.stack) {
    if (task is ResolveTask) held++;
    if (task is FlipFourTask) held += task.held.length;
  }
  if (g.prompt is TargetPrompt) held++;
  final onTable = g.players.fold(
    0,
    (sum, p) => sum + p.line.length + p.mods.length,
  );
  return g.deck.length + g.discard.length + held + onTable;
}

void main() {
  test('all-CPU games finish with every card accounted for', () {
    for (var seed = 0; seed < 150; seed++) {
      final game = Game(
        [for (var i = 0; i < 2 + seed % 7; i++) PlayerConfig('P$i', bot: true)],
        brutal: seed % 3 == 0,
        random: Random(seed),
      );
      var guard = 0;
      while (game.phase != Phase.gameOver) {
        expect(guard++, lessThan(200000), reason: 'seed $seed never finished');
        if (game.phase == Phase.roundEnd) {
          if (!game.brutal) {
            expect(game.players.every((p) => p.roundScore! >= 0), isTrue);
          }
          game.nextRound();
        } else if (game.prompt != null) {
          final before = game.prompt;
          playBot(game);
          expect(game.prompt, isNot(same(before)), reason: 'seed $seed stuck');
        } else {
          expect(game.step(), isTrue, reason: 'seed $seed stalled');
        }
        expect(_cardsInPlay(game), 108, reason: 'seed $seed lost a card');
        for (final p in game.players) {
          expect(p.line.length, lessThanOrEqualTo(7));
          if (p.status != Status.busted) expect(isBust(p.line), isFalse);
        }
      }
      expect(game.players[game.winner!].total, greaterThanOrEqualTo(200));
    }
  });
}
