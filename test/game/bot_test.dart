import 'package:flip7_flutter/game/bot.dart';
import 'package:flip7_flutter/game/cards.dart';
import 'package:flip7_flutter/game/game.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Lets the CPU answer until the prompt is no longer [pid]'s.
void playOut(Game g, int pid) {
  while (g.prompt?.pid == pid && g.phase == Phase.playing && !g.roundOver) {
    playBot(g);
  }
}

void main() {
  group('bustChance', () {
    test('is the share of unseen cards that would bust the player', () {
      final g = rig(bots: true);
      final p = g.players[0]..line = [n(5)];
      g.deck = [n(5), n(6), minus(2), action(ActionKind.swap)];
      expect(bustChance(g, p), 0.25);
    });

    test('is zero with no cards to draw', () {
      final g = rig(bots: true);
      expect(bustChance(g, g.players[0]..line = [n(5)]), 0);
    });

    test('looks at the discards when the deck is about to be reshuffled', () {
      final g = rig(bots: true);
      g.discard = [n(5)];
      expect(bustChance(g, g.players[0]..line = [n(5)]), 1);
    });

    test('knows Unlucky 7 cannot bust and Lucky 13 forgives one 13', () {
      final g = rig(bots: true);
      g.deck = [unlucky7()];
      expect(bustChance(g, g.players[0]..line = [n(7)]), 0);
      g.deck = [n(13)];
      expect(bustChance(g, g.players[0]..line = [lucky13()]), 0);
      expect(bustChance(g, g.players[0]..line = [lucky13(), n(13)]), 1);
    });
  });

  group('hit or stay', () {
    Game arrange(List<GameCard> line, List<GameCard> deck) {
      final g = rig(bots: true);
      g.players[0].line = line;
      g.deck = deck;
      g.prompt = HitStayPrompt(0, mustHit: g.players[0].hasZero);
      return g;
    }

    bool hits(Game g) {
      playBot(g);
      return g.stack.whereType<DrawTask>().isNotEmpty;
    }

    test('always hits with nothing to lose', () {
      expect(hits(arrange([], [n(1)])), isTrue);
    });

    test('hits when the next card is likely to help', () {
      expect(hits(arrange([n(13)], [n(1), n(2), n(3)])), isTrue);
    });

    test('stays when the deck is stacked against it', () {
      final g = arrange([n(13), n(12), n(11)], [n(13), n(12), n(11), n(1)]);
      expect(hits(g), isFalse);
      expect(g.players[0].status, Status.stayed);
    });

    test('chases the Flip 7 bonus on a sixth card', () {
      final line = [for (var v = 1; v <= 6; v++) n(v)];
      // Two of three cards bust 21 points, but the third is worth 21 + 13 + 15.
      expect(hits(arrange(line, [n(1), n(2), n(13)])), isFalse);
      expect(hits(arrange(line, [n(1), n(13), n(12)])), isTrue);
    });

    test('must hit while holding The Zero', () {
      final g = arrange([zero(), n(13), n(12)], [n(13), n(12)]);
      expect(hits(g), isTrue);
    });

    test('weighs modifiers and Unlucky 7 in the expected value', () {
      final g = arrange([n(13), n(12)], [unlucky7(), unlucky7(), minus(2)]);
      // Unlucky 7 would turn 25 points into 7, so it stays.
      expect(hits(g), isFalse);
    });

    test('does nothing when there is no prompt', () {
      final g = rig(bots: true);
      playBot(g);
      expect(g.stack, isEmpty);
      expect(g.prompt, isNull);
    });
  });

  group('choosing who gets a card', () {
    test('puts a minus card where it costs an opponent the most', () {
      final g = rig(bots: true);
      g.players[1].line = [n(12)];
      g.players[2].line = [n(2)];
      final m = minus(10);
      g.prompt = TargetPrompt(0, m, [0, 1, 2]);
      playBot(g);
      expect(g.players[1].mods, [m]);
    });

    test('puts ÷2 on the biggest hand', () {
      final g = rig(bots: true);
      g.players[1].line = [n(4)];
      g.players[2].line = [n(13), n(12)];
      g.prompt = TargetPrompt(0, divide(), [0, 1, 2]);
      playBot(g);
      expect(g.players[2].mods, hasLength(1));
    });

    test('keeps a modifier only when it has no choice', () {
      final g = rig(bots: true);
      final m = minus(2);
      g.prompt = TargetPrompt(0, m, [0]);
      playBot(g);
      expect(g.players[0].mods, [m]);
    });

    test('aims Just One More! at the opponent most likely to bust', () {
      final g = rig(bots: true);
      g.players[1].line = [n(5), n(13)];
      g.players[2].line = [n(1)];
      g.deck = [n(5), n(5), n(5), n(9)];
      g.prompt = TargetPrompt(0, action(ActionKind.justOneMore), [0, 1, 2]);
      playBot(g);
      expect(g.stack.whereType<DrawTask>().single.pid, 1);
    });

    test('takes Flip Four! itself when the deck is safe', () {
      final g = rig(bots: true);
      g.deck = [n(1), n(2), n(3), n(4), n(5), n(6)];
      g.prompt = TargetPrompt(0, action(ActionKind.flipFour), [0, 1, 2]);
      playBot(g);
      expect(g.stack.whereType<FlipFourTask>().single.pid, 0);
    });

    test('throws Flip Four! at an opponent when the deck is dangerous', () {
      final g = rig(bots: true);
      g.players[0].line = [n(9)];
      g.players[1].line = [n(9), n(13)];
      g.deck = [n(9), n(9), n(9), n(13)];
      g.prompt = TargetPrompt(0, action(ActionKind.flipFour), [0, 1]);
      playBot(g);
      expect(g.stack.whereType<FlipFourTask>().single.pid, 1);
    });
  });

  group('Steal', () {
    test('keeps it and takes the best card that does not bust', () {
      final g = rig(bots: true);
      final twelve = n(12);
      g.players[0].line = [n(3)];
      g.players[1].line = [twelve, n(3)];
      g.prompt = TargetPrompt(0, action(ActionKind.steal), [0, 1, 2]);
      playOut(g, 0);
      expect(g.players[0].line, contains(twelve));
      expect(g.players[0].status, Status.active);
    });

    test('hands it to an opponent when every option would bust it', () {
      final g = rig(bots: true);
      g.players[0]
        ..line = [n(13)]
        ..total = 50;
      g.players[1].line = [n(13)];
      g.players[2].total = 10;
      g.prompt = TargetPrompt(0, action(ActionKind.steal), [0, 2]);
      playBot(g);
      expect(g.prompt!.pid, 2);
    });

    test('must use it when it is the only valid receiver', () {
      final g = rig(bots: true);
      g.players[0].line = [n(13)];
      g.players[1].line = [n(13)];
      g.prompt = TargetPrompt(0, action(ActionKind.steal), [0]);
      playOut(g, 0);
      expect(g.players[0].status, Status.busted);
    });
  });

  group('Discard', () {
    test('gets rid of its own Zero when that gains the most', () {
      final g = rig(bots: true);
      g.players[0].line = [zero(), n(10), n(9)];
      g.players[1].line = [n(2)];
      g.prompt = TargetPrompt(0, action(ActionKind.discard), [0, 1]);
      playOut(g, 0);
      expect(g.players[0].hasZero, isFalse);
      expect(values(g.players[0]), [10, 9]);
    });

    test("otherwise removes an opponent's best card", () {
      final g = rig(bots: true);
      g.players[0].line = [n(4)];
      g.players[1].line = [n(2), n(13)];
      g.prompt = TargetPrompt(0, action(ActionKind.discard), [0, 1]);
      playOut(g, 0);
      expect(values(g.players[1]), [2]);
      expect(values(g.players[0]), [4]);
    });
  });

  group('Swap', () {
    test('trades its worst card for an opponent\'s best', () {
      final g = rig(bots: true);
      g.players[0].line = [n(1)];
      g.players[1].line = [n(13)];
      g.prompt = TargetPrompt(0, action(ActionKind.swap), [0, 1]);
      playOut(g, 0);
      expect(values(g.players[0]), [13]);
      expect(values(g.players[1]), [1]);
    });

    test('passes its own modifier to someone else', () {
      final g = rig(bots: true);
      g.players[0]
        ..line = [n(10)]
        ..mods = [minus(10)];
      g.players[1].line = [n(12)];
      g.prompt = TargetPrompt(0, action(ActionKind.swap), [0, 1]);
      playOut(g, 0);
      expect(g.players[0].mods, isEmpty);
      expect(values(g.players[0]), [10, 12]);
      expect(g.players[1].mods, hasLength(1));
    });

    test('uses it as the receiver when a rival hands it over', () {
      final g = rig(bots: true);
      g.players[0].line = [n(1)];
      g.players[1].line = [n(13)];
      g.prompt = TargetPrompt(2, action(ActionKind.swap), [1, 2]);
      playBot(g);
      expect(g.prompt, isA<PickPrompt>());
      expect(g.prompt!.pid, 2);
    });
  });

  group('the Brutal Mode bonus', () {
    Game arrange({required int rivalTotal}) {
      final g = rig(brutal: true, bots: true);
      g.players[0]
        ..line = [for (var v = 1; v <= 7; v++) n(v)]
        ..flip7 = true
        ..total = 50;
      g.players[1].total = rivalTotal;
      g.roundOver = true;
      g.prompt = const BonusPrompt(0, [0, 1, 2]);
      return g;
    }

    test('takes +15 when it is comfortably ahead', () {
      final g = arrange(rivalTotal: 20)..let(playBot);
      expect(g.players[0].roundScore, 28 + flip7Bonus);
      expect(g.players[1].roundScore, 0);
    });

    test('docks the leader 15 when it is behind', () {
      final g = arrange(rivalTotal: 150)..let(playBot);
      expect(g.players[0].roundScore, 28);
      expect(g.players[1].roundScore, -flip7Bonus);
    });
  });
}

extension on Game {
  void let(void Function(Game) f) => f(this);
}
