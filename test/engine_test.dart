import 'dart:math';

import 'package:flip7_flutter/game/bot.dart';
import 'package:flip7_flutter/game/cards.dart';
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
  test('the deck has 108 cards in the published mix', () {
    final deck = buildDeck();
    expect(deck, hasLength(108));
    expect(deck.where((c) => c.isNumber && c.special == null), hasLength(89));
    expect(deck.where((c) => c.kind == CardKind.modifier), hasLength(6));
    expect(deck.where((c) => c.kind == CardKind.action), hasLength(10));
  });

  test('Lucky 13 allows exactly one extra 13', () {
    const lucky = GameCard.number(0, 13, special: Special.lucky13);
    const a = GameCard.number(1, 13);
    const b = GameCard.number(2, 13);
    expect(isBust([a, b]), isTrue);
    expect(isBust([lucky, a]), isFalse);
    expect(isBust([lucky, a, b]), isTrue);
  });

  test('scoring halves, subtracts, floors at zero, then adds the bonus', () {
    int score(List<int> values, {bool flip7 = false, bool brutal = false}) =>
        scoreCards(
          line: [for (final v in values) GameCard.number(v, v)],
          mods: const [GameCard.divide(100), GameCard.minus(101, 4)],
          busted: false,
          flip7: flip7,
          brutal: brutal,
        );
    expect(score([13, 12, 11, 10, 2]), 20);
    expect(score([13, 12, 11, 10, 2], flip7: true), 35);
    expect(score([3]), 0);
    expect(score([3], brutal: true), -3);
  });

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
