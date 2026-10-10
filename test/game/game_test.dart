import 'dart:math';

import 'package:flip7_flutter/game/cards.dart';
import 'package:flip7_flutter/game/game.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('Player', () {
    test('lists modifiers before numbers and spots The Zero', () {
      final p = Player(0, 'Ann', bot: false);
      final m = minus(4);
      final five = n(5);
      p
        ..mods = [m]
        ..line = [five];
      expect(p.cards, [m, five]);
      expect(p.hasZero, isFalse);
      p.line.add(zero());
      expect(p.hasZero, isTrue);
    });

    test('copy is independent of the original', () {
      final p = Player(2, 'Bo', bot: true)
        ..total = 40
        ..line = [n(3)]
        ..mods = [minus(2)]
        ..status = Status.stayed
        ..flip7 = true
        ..roundScore = 9;
      final c = p.copy();
      expect(
        [c.id, c.name, c.bot, c.total, c.status, c.flip7, c.roundScore],
        [2, 'Bo', true, 40, Status.stayed, true, 9],
      );
      c.line.add(n(8));
      c.mods.clear();
      expect(p.line, hasLength(1));
      expect(p.mods, hasLength(1));
    });
  });

  group('isBust', () {
    test('distinct numbers are safe, a duplicate busts', () {
      expect(isBust([]), isFalse);
      expect(isBust([n(4), n(9), n(13)]), isFalse);
      expect(isBust([n(4), n(9), n(4)]), isTrue);
    });

    test('Lucky 13 allows exactly one extra 13', () {
      expect(isBust([n(13), n(13)]), isTrue);
      expect(isBust([lucky13(), n(13)]), isFalse);
      expect(isBust([lucky13(), n(13), n(13)]), isTrue);
    });

    test('Unlucky 7 counts as a 7', () {
      expect(isBust([unlucky7(), n(7)]), isTrue);
    });
  });

  group('scoring', () {
    int score(
      List<GameCard> line, {
      List<GameCard> mods = const [],
      bool busted = false,
      bool flip7 = false,
      bool brutal = false,
      bool bonus = true,
    }) => scoreCards(
      line: line,
      mods: mods,
      busted: busted,
      flip7: flip7,
      brutal: brutal,
      bonus: bonus,
    );

    test('adds the number cards', () {
      expect(score([n(13), n(4), n(1)]), 18);
      expect(score([]), 0);
    });

    test('halves (rounding down) before subtracting', () {
      expect(score([n(13), n(12)], mods: [divide()]), 12);
      expect(score([n(13), n(12)], mods: [minus(4), divide()]), 8);
    });

    test('matches the rulebook example: 48 → 24 → 20 → 35', () {
      final line = [n(13), n(12), n(11), n(10), n(2)];
      final mods = [divide(), minus(4)];
      expect(score(line, mods: mods), 20);
      expect(score(line, mods: mods, flip7: true), 35);
      expect(score(line, mods: mods, flip7: true, bonus: false), 20);
    });

    test('cannot go below zero unless Brutal Mode is on', () {
      expect(score([n(3)], mods: [minus(10)]), 0);
      expect(score([n(3)], mods: [minus(10)], brutal: true), -7);
    });

    test('a bust is worth nothing; in Brutal Mode modifiers still bite', () {
      expect(score([n(9)], busted: true), 0);
      expect(score([], mods: [minus(6)], busted: true, brutal: true), -6);
    });

    test('The Zero wipes the hand unless it is part of a Flip 7', () {
      expect(score([zero(), n(12)]), 0);
      expect(score([zero(), n(12)], flip7: true), 27);
    });

    test('scoreOf reads the player', () {
      final p = Player(0, 'Ann', bot: false)
        ..line = [n(10), n(6)]
        ..mods = [minus(2)];
      expect(scoreOf(p, false), 14);
      p.status = Status.busted;
      expect(scoreOf(p, false), 0);
      p
        ..status = Status.active
        ..flip7 = true;
      expect(scoreOf(p, false), 29);
      expect(scoreOf(p, false, bonus: false), 14);
    });
  });

  group('moving cards between players', () {
    test('ownerOf and takeCard find a card in either zone', () {
      final g = rig();
      final five = n(5);
      final m = minus(2);
      g.players[1].line = [five];
      g.players[2].mods = [m];
      expect(ownerOf(g.players, five.id), g.players[1]);
      final (card, owner) = takeCard(g.players, m.id);
      expect(card, m);
      expect(owner, g.players[2]);
      expect(g.players[2].mods, isEmpty);
    });

    test('giveCard files numbers and modifiers, and ignores actions', () {
      final p = Player(0, 'Ann', bot: false);
      giveCard(p, n(5));
      giveCard(p, divide());
      giveCard(p, action(ActionKind.swap));
      expect(p.line, hasLength(1));
      expect(p.mods, hasLength(1));
    });
  });

  group('a new game', () {
    final g = Game(const [
      PlayerConfig('Ann', bot: false),
      PlayerConfig('Bo', bot: true),
      PlayerConfig('Cy', bot: true),
    ], brutal: false, random: Random(1));

    test('starts round 1 with a full deck and a deal queued for everyone', () {
      expect(g.round, 1);
      expect(g.phase, Phase.playing);
      expect(g.deck, hasLength(108));
      expect(g.stack.whereType<DrawTask>(), hasLength(3));
      expect(g.players.map((p) => p.name), ['Ann', 'Bo', 'Cy']);
      expect(g.players.map((p) => p.bot), [false, true, true]);
      expect(g.log.single, contains('Round 1'));
    });

    test('deals to the player left of the dealer first', () {
      final first = g.stack.last as DrawTask;
      expect(first.pid, (g.dealer + 1) % 3);
      expect(first.via, DrawVia.deal);
    });

    test('gives each active player one card', () {
      final g = rig();
      g.stack.addAll([
        for (var i = 2; i >= 0; i--) DrawTask(i, DrawVia.deal),
      ]);
      topDeck(g, [n(1), n(2), n(3)]);
      run(g);
      expect([for (final p in g.players) values(p)], [
        [1],
        [2],
        [3],
      ]);
      expect(g.prompt, isA<HitStayPrompt>());
      expect(g.prompt!.pid, 0);
    });

    test('skips a player who is already out when dealing', () {
      final g = rig();
      g.players[1].status = Status.stayed;
      g.stack.add(const DrawTask(1, DrawVia.deal));
      topDeck(g, [n(5)]);
      expect(g.step(), isTrue);
      expect(g.players[1].line, isEmpty);
      expect(g.deck, hasLength(1));
    });
  });

  group('hit and stay', () {
    test('hitting adds the top card and passes the turn', () {
      final g = rig();
      run(g);
      expect(g.prompt!.pid, 0);
      topDeck(g, [n(5)]);
      g.hit();
      run(g);
      expect(values(g.players[0]), [5]);
      expect(g.prompt, isA<HitStayPrompt>());
      expect(g.prompt!.pid, 1);
    });

    test('staying locks the hand in and the turn skips that player', () {
      final g = rig();
      g.players[0].line = [n(9)];
      run(g);
      g.stay();
      expect(g.players[0].status, Status.stayed);
      expect(g.log.last, 'P0 stays with 9.');
      run(g);
      g.stay();
      run(g);
      expect(g.prompt!.pid, 2);
    });

    test('a duplicate number busts and the cards are discarded', () {
      final g = rig();
      g.players[0].line = [n(5), n(8)];
      flip(g, 0, [n(5)]);
      final p = g.players[0];
      expect(p.status, Status.busted);
      expect(p.line, isEmpty);
      expect(g.discard, hasLength(3));
      expect(scoreOf(p, false), 0);
    });

    test('the round ends once nobody is active, and scores are banked', () {
      final g = rig();
      g.players[0].line = [n(9)];
      g.players[1].line = [n(4), n(3)];
      g.players[2].total = 10;
      stayAll(g);
      expect(g.phase, Phase.roundEnd);
      expect(g.roundOver, isTrue);
      expect(g.prompt, isNull);
      expect(g.players.map((p) => p.roundScore), [9, 7, 0]);
      expect(g.players.map((p) => p.total), [9, 7, 10]);
      expect(g.step(), isFalse);
    });

    test('answers that do not fit the prompt are ignored', () {
      final g = rig();
      g.hit();
      g.stay();
      expect(g.stack, isEmpty);
      run(g);
      final prompt = g.prompt;
      g.choosePlayer(1);
      g.chooseCard(1);
      expect(g.prompt, same(prompt));
    });
  });

  group('Flip 7', () {
    test('ends the round on the spot with a 15-point bonus', () {
      final g = rig();
      g.players[0].line = [for (var v = 1; v <= 6; v++) n(v)];
      g.players[1].line = [n(3)];
      flip(g, 0, [n(7), n(9)]);
      expect(g.players[0].flip7, isTrue);
      expect(g.phase, Phase.roundEnd);
      expect(g.players[0].roundScore, 28 + flip7Bonus);
      expect(g.players[1].roundScore, 3);
      expect(g.deck, hasLength(1), reason: 'nothing more is drawn');
    });

    test('in Brutal Mode the flipper chooses between +15 and −15', () {
      Game arrange() {
        final g = rig(brutal: true);
        g.players[0].line = [for (var v = 1; v <= 6; v++) n(v)];
        g.players[1].line = [n(3)];
        flip(g, 0, [n(7)]);
        return g;
      }

      final g = arrange();
      final prompt = g.prompt as BonusPrompt;
      expect(prompt.pid, 0);
      expect(prompt.options, [0, 1, 2]);
      expect(g.phase, Phase.playing);
      expect(g.step(), isFalse);
      g.choosePlayer(7);
      expect(g.prompt, same(prompt));

      g.choosePlayer(0);
      expect(g.phase, Phase.roundEnd);
      expect(g.players.map((p) => p.roundScore), [43, 3, 0]);

      final revenge = arrange()..choosePlayer(1);
      expect(revenge.players.map((p) => p.roundScore), [28, -12, 0]);
      expect(revenge.log.last, contains('−15'));
    });
  });

  group('special numbers', () {
    test('The Zero forces its holder to keep hitting', () {
      final g = rig();
      g.players[0].line = [zero()];
      run(g);
      expect((g.prompt as HitStayPrompt).mustHit, isTrue);
      g.stay();
      expect(g.players[0].status, Status.active);
      expect(g.prompt, isNotNull);
    });

    test('The Zero counts toward Flip 7 and then scores normally', () {
      final g = rig();
      g.players[0].line = [zero(), for (var v = 1; v <= 5; v++) n(v)];
      flip(g, 0, [n(6)]);
      expect(g.players[0].roundScore, 21 + flip7Bonus);
    });

    test('Unlucky 7 discards everything else and cannot bust', () {
      final g = rig();
      final p = g.players[0]
        ..line = [n(7), n(9)]
        ..mods = [minus(4)];
      flip(g, 0, [unlucky7()]);
      expect(p.status, Status.active);
      expect(p.line.single.special, Special.unlucky7);
      expect(p.mods, isEmpty);
      expect(g.discard, hasLength(3));

      flip(g, 0, [n(7)]);
      expect(p.status, Status.busted);
    });

    test('Lucky 13 lets its holder keep a second 13 but not a third', () {
      final g = rig();
      final p = g.players[0]..line = [n(13)];
      flip(g, 0, [lucky13()]);
      expect(p.status, Status.active);
      expect(scoreOf(p, false), 26);
      flip(g, 0, [n(13)]);
      expect(p.status, Status.busted);
    });
  });

  group('modifiers', () {
    test('the flipper chooses any player who has not busted', () {
      final g = rig();
      g.players[2].status = Status.busted;
      final m = minus(6);
      flip(g, 0, [m]);
      final prompt = g.prompt as TargetPrompt;
      expect(prompt.pid, 0);
      expect(prompt.card, m);
      expect(prompt.options, [0, 1]);

      g.choosePlayer(2);
      expect(g.prompt, same(prompt), reason: 'a busted player is not valid');
      g.choosePlayer(1);
      expect(g.players[1].mods, [m]);
      expect(g.log.last, 'P0 puts −6 on P1.');
    });

    test('a player may keep it, and must when nobody else is left', () {
      final g = rig();
      g.players[1].status = Status.busted;
      g.players[2].status = Status.busted;
      flip(g, 0, [divide()]);
      expect(g.players[0].mods.single.divides, isTrue);
      expect(g.log, contains('P0 puts ÷2 on themself.'));
    });

    test('never cause a bust and do not count toward Flip 7', () {
      final g = rig();
      final p = g.players[0]
        ..line = [for (var v = 1; v <= 6; v++) n(v)]
        ..mods = [minus(2)];
      g.players[1].status = Status.busted;
      g.players[2].status = Status.busted;
      flip(g, 0, [minus(2)]);
      expect(p.status, Status.active);
      expect(p.flip7, isFalse);
      expect(p.mods, hasLength(2));
    });

    test('in Brutal Mode they can be dumped on a busted player', () {
      final g = rig(brutal: true);
      g.players[1].status = Status.busted;
      flip(g, 0, [minus(4)]);
      expect((g.prompt as TargetPrompt).options, [0, 1, 2]);
      g.choosePlayer(1);
      expect(scoreOf(g.players[1], true), -4);
    });
  });

  group('Just One More!', () {
    test('the target takes one card and must then stay', () {
      final g = rig();
      g.players[1].line = [n(4)];
      flip(g, 0, [action(ActionKind.justOneMore), n(8)]);
      expect((g.prompt as TargetPrompt).options, [0, 1, 2]);
      g.choosePlayer(1);
      run(g);
      expect(values(g.players[1]), [4, 8]);
      expect(g.players[1].status, Status.stayed);
      expect(g.log, contains('P1 must stay.'));
    });

    test('can bust the target instead', () {
      final g = rig();
      g.players[1].line = [n(8)];
      flip(g, 0, [action(ActionKind.justOneMore), n(8)]);
      g.choosePlayer(1);
      run(g);
      expect(g.players[1].status, Status.busted);
    });

    test('works on a player who has stayed, who stays out', () {
      final g = rig();
      g.players[1]
        ..line = [n(4)]
        ..status = Status.stayed;
      flip(g, 0, [action(ActionKind.justOneMore), n(9)]);
      g.choosePlayer(1);
      run(g);
      expect(values(g.players[1]), [4, 9]);
      expect(g.players[1].status, Status.stayed);
    });

    test('an action flipped as the extra card is resolved before staying', () {
      final g = rig();
      g.players[2].line = [n(5)];
      flip(g, 0, [
        action(ActionKind.justOneMore),
        action(ActionKind.discard),
      ]);
      g.choosePlayer(1);
      run(g);
      final pick = g.prompt as PickPrompt;
      expect(pick.pid, 1);
      expect(g.players[1].status, Status.active);
      g.chooseCard(pick.options.single);
      run(g);
      expect(g.players[1].status, Status.stayed);
    });
  });

  group('Flip Four!', () {
    test('deals four cards and resolves modifiers afterwards', () {
      final g = rig();
      final m = minus(2);
      flip(g, 0, [action(ActionKind.flipFour), n(1), m, n(3), n(4), n(9)]);
      g.choosePlayer(1);
      run(g);
      expect(values(g.players[1]), [1, 3, 4]);
      final prompt = g.prompt as TargetPrompt;
      expect(prompt.pid, 1);
      expect(prompt.card, m);
      expect(g.deck, hasLength(1));
    });

    test('holds the set-aside cards on the task while flipping', () {
      final g = rig();
      final m = minus(2);
      flip(g, 0, [action(ActionKind.flipFour), m, n(3), n(4), n(5)]);
      g.choosePlayer(1);
      g.step();
      final task = g.stack.whereType<FlipFourTask>().single;
      expect(task.left, 3);
      expect(task.held, [m]);
    });

    test('stops on a bust and throws away any actions it turned up', () {
      final g = rig();
      g.players[2].line = [n(12)];
      flip(g, 0, [
        action(ActionKind.flipFour),
        n(1),
        action(ActionKind.steal),
        n(1),
        n(9),
      ]);
      g.choosePlayer(1);
      run(g);
      expect(g.players[1].status, Status.busted);
      expect(g.deck, hasLength(1), reason: 'the fourth card stays in the deck');
      expect(g.prompt, isA<HitStayPrompt>());
      expect(g.players[2].line, hasLength(1));
    });

    test('stops on a Flip 7', () {
      final g = rig();
      g.players[1].line = [for (var v = 1; v <= 6; v++) n(v)];
      flip(g, 0, [action(ActionKind.flipFour), minus(2), n(13), n(12)]);
      g.choosePlayer(1);
      run(g);
      expect(g.players[1].flip7, isTrue);
      expect(g.phase, Phase.roundEnd);
      expect(g.players[1].mods, isEmpty, reason: 'the held modifier is lost');
      expect(g.deck, hasLength(1));
    });

    test('applies Unlucky 7 mid-way, then carries on', () {
      final g = rig();
      g.players[1].line = [n(9)];
      flip(g, 0, [action(ActionKind.flipFour), n(2), unlucky7(), n(3), n(4)]);
      g.choosePlayer(1);
      run(g);
      expect(values(g.players[1]), [7, 3, 4]);
    });

    test('a stayed target takes the cards but stays out', () {
      final g = rig();
      g.players[1].status = Status.stayed;
      flip(g, 0, [action(ActionKind.flipFour), n(1), n(2), n(3), n(4)]);
      g.choosePlayer(1);
      run(g);
      expect(g.players[1].line, hasLength(4));
      expect(g.players[1].status, Status.stayed);
    });

    test('ends the round if the cards run out', () {
      final g = rig();
      flip(g, 0, [action(ActionKind.flipFour), n(1)]);
      g.choosePlayer(1);
      g.discard = [];
      run(g);
      expect(g.phase, Phase.roundEnd);
      expect(g.log, contains('No cards left anywhere — the round ends.'));
    });
  });

  group('Steal', () {
    test('the receiver takes any face-up card from another player', () {
      final g = rig();
      final twelve = n(12);
      final m = minus(4);
      g.players[1]
        ..line = [twelve]
        ..mods = [m];
      flip(g, 0, [action(ActionKind.steal)]);
      expect((g.prompt as TargetPrompt).options, [0, 2]);
      g.choosePlayer(0);
      final pick = g.prompt as PickPrompt;
      expect(pick.purpose, PickPurpose.steal);
      expect(pick.pid, 0);
      expect(pick.options, [m.id, twelve.id]);

      g.chooseCard(-1);
      expect(g.prompt, same(pick));
      g.chooseCard(twelve.id);
      expect(g.players[0].line, [twelve]);
      expect(g.players[1].line, isEmpty);
      expect(g.log.last, 'P0 steals 12 from P1.');
    });

    test('a stolen modifier lands with the thief', () {
      final g = rig();
      final m = minus(4);
      g.players[1].mods = [m];
      flip(g, 0, [action(ActionKind.steal)]);
      g.choosePlayer(0);
      g.chooseCard(m.id);
      expect(g.players[0].mods, [m]);
    });

    test('must be used even when the only option busts you', () {
      // The publisher's FAQ example: two players hold a 13, a third hands one of them Steal.
      final g = rig();
      final theirs = n(13);
      g.players[0].line = [n(13)];
      g.players[1].line = [theirs];
      flip(g, 2, [action(ActionKind.steal)]);
      g.choosePlayer(0);
      expect((g.prompt as PickPrompt).options, [theirs.id]);
      g.chooseCard(theirs.id);
      expect(g.players[0].status, Status.busted);
    });

    test('a stolen Unlucky 7 is just a 7', () {
      final g = rig();
      final u = unlucky7();
      g.players[0].line = [n(9)];
      g.players[1].line = [u];
      flip(g, 0, [action(ActionKind.steal)]);
      g.choosePlayer(0);
      g.chooseCard(u.id);
      expect(values(g.players[0]), [9, 7]);
    });

    test('can complete a Flip 7', () {
      final g = rig();
      final seven = n(7);
      g.players[0].line = [for (var v = 1; v <= 6; v++) n(v)];
      g.players[1].line = [seven];
      flip(g, 0, [action(ActionKind.steal)]);
      g.choosePlayer(0);
      g.chooseCard(seven.id);
      expect(g.players[0].flip7, isTrue);
      expect(g.phase, Phase.roundEnd);
    });

    test('is discarded when there is nothing to steal', () {
      final g = rig();
      flip(g, 0, [action(ActionKind.steal)]);
      expect(g.log, contains('Steal has no valid target and is discarded.'));
      expect(g.discard, hasLength(1));
      expect(g.prompt, isA<HitStayPrompt>());
    });
  });

  group('Swap', () {
    test('exchanges two cards that belong to different players', () {
      final g = rig();
      final one = n(1);
      final thirteen = n(13);
      g.players[0].line = [one];
      g.players[1].line = [thirteen, n(2)];
      flip(g, 2, [action(ActionKind.swap)]);
      g.choosePlayer(2);
      final first = g.prompt as PickPrompt;
      expect(first.purpose, PickPurpose.swapFirst);
      expect(first.options, hasLength(3));

      g.chooseCard(one.id);
      final second = g.prompt as PickPrompt;
      expect(second.purpose, PickPurpose.swapSecond);
      expect(second.first, one.id);
      expect(second.options, isNot(contains(one.id)));
      expect(second.options, hasLength(2));

      g.chooseCard(thirteen.id);
      expect(values(g.players[0]), [13]);
      expect(values(g.players[1]), [2, 1]);
      expect(g.log.last, "P2 swaps P0's 1 with P1's 13.");
    });

    test('can bust two players at once', () {
      // The publisher's FAQ example.
      final g = rig();
      final ten = n(10);
      final eleven = n(11);
      g.players[1].line = [ten, n(11)];
      g.players[2].line = [n(10), eleven];
      flip(g, 0, [action(ActionKind.swap)]);
      g.choosePlayer(0);
      g.chooseCard(ten.id);
      g.chooseCard(eleven.id);
      expect(g.players[1].status, Status.busted);
      expect(g.players[2].status, Status.busted);
    });

    test('can trade a number for a modifier', () {
      final g = rig();
      final m = minus(8);
      final five = n(5);
      g.players[1].mods = [m];
      g.players[2].line = [five];
      flip(g, 0, [action(ActionKind.swap)]);
      g.choosePlayer(0);
      g.chooseCard(m.id);
      g.chooseCard(five.id);
      expect(g.players[1].line, [five]);
      expect(g.players[1].mods, isEmpty);
      expect(g.players[2].mods, [m]);
    });

    test('is discarded unless two players hold cards', () {
      final g = rig();
      g.players[1].line = [n(5)];
      flip(g, 0, [action(ActionKind.swap)]);
      expect(g.log, contains('Swap has no valid target and is discarded.'));
    });
  });

  group('Discard', () {
    test('the flipper picks which of the target\'s cards goes', () {
      final g = rig();
      final nine = n(9);
      final m = minus(2);
      g.players[1]
        ..line = [nine]
        ..mods = [m];
      g.players[2].line = [n(4)];
      flip(g, 0, [action(ActionKind.discard)]);
      expect((g.prompt as TargetPrompt).options, [1, 2]);
      g.choosePlayer(1);
      final pick = g.prompt as PickPrompt;
      expect(pick.pid, 0, reason: 'the flipper chooses, not the target');
      expect(pick.purpose, PickPurpose.discard);
      expect(pick.options, [m.id, nine.id]);
      g.chooseCard(nine.id);
      expect(g.players[1].line, isEmpty);
      expect(g.discard, contains(nine));
      expect(g.log.last, "P0 discards P1's 9.");
    });

    test('lets a player throw away their own Zero', () {
      final g = rig();
      final z = zero();
      g.players[0].line = [z, n(10)];
      flip(g, 0, [action(ActionKind.discard)]);
      g.chooseCard(z.id);
      expect(scoreOf(g.players[0], false), 10);
    });

    test('is discarded when nobody holds a card', () {
      final g = rig();
      flip(g, 0, [action(ActionKind.discard)]);
      expect(g.log, contains('Discard has no valid target and is discarded.'));
    });
  });

  group('running out of cards', () {
    test('the discards are shuffled into a new deck', () {
      final g = rig();
      g.discard = [n(5)];
      g.prompt = const HitStayPrompt(0, mustHit: false);
      g.hit();
      run(g);
      expect(values(g.players[0]), [5]);
      expect(g.discard, isEmpty);
      expect(g.log, contains(contains('shuffled into a new deck')));
    });

    test('with nothing left anywhere the round ends', () {
      final g = rig();
      g.players[0].line = [n(6)];
      g.prompt = const HitStayPrompt(0, mustHit: false);
      g.hit();
      run(g);
      expect(g.phase, Phase.roundEnd);
      expect(g.players[0].roundScore, 6);
    });
  });

  group('held cards', () {
    test('are discarded if their owner has busted in the meantime', () {
      final g = rig();
      final card = action(ActionKind.flipFour);
      g.players[1].status = Status.busted;
      g.stack.add(ResolveTask(1, card));
      g.step();
      expect(g.discard, [card]);
      expect(g.prompt, isNull);
    });

    test('are discarded when the round ends under them', () {
      final g = rig();
      final card = minus(2);
      g.players[0].line = [for (var v = 1; v <= 6; v++) n(v)];
      g.stack.add(ResolveTask(1, card));
      flip(g, 0, [n(7)]);
      expect(g.phase, Phase.roundEnd);
      expect(g.discard, contains(card));
      expect(g.stack, isEmpty);
    });
  });

  group('the end of the game', () {
    test('the highest score at 200 or more wins', () {
      final g = rig();
      g.players[0]
        ..total = 190
        ..line = [n(12)];
      g.players[1].total = 150;
      stayAll(g);
      expect(g.phase, Phase.gameOver);
      expect(g.winner, 0);
      expect(g.players[0].total, 202);
      expect(g.log.last, 'P0 wins the game with 202 points!');
    });

    test('a tie at the top means another round', () {
      final g = rig();
      for (final i in [0, 1]) {
        g.players[i]
          ..total = 195
          ..line = [n(10)];
      }
      stayAll(g);
      expect(g.phase, Phase.roundEnd);
      expect(g.winner, isNull);
      expect(g.log.last, contains('Tied at 205'));
    });

    test('below 200 the game simply continues', () {
      final g = rig();
      g.players[0].line = [n(12)];
      stayAll(g);
      expect(g.phase, Phase.roundEnd);
      expect(g.winner, isNull);
    });
  });

  group('nextRound', () {
    test('clears the table, rotates the dealer and deals again', () {
      final g = rig();
      g.players[0].line = [n(12)];
      g.players[1].mods = [minus(2)];
      stayAll(g);
      final dealer = g.dealer;
      g.nextRound();
      expect(g.round, 2);
      expect(g.phase, Phase.playing);
      expect(g.roundOver, isFalse);
      expect(g.dealer, (dealer + 1) % 3);
      expect(g.discard, hasLength(2));
      expect(g.stack.whereType<DrawTask>(), hasLength(3));
      for (final p in g.players) {
        expect(p.cards, isEmpty);
        expect(p.status, Status.active);
        expect(p.roundScore, isNull);
      }
      expect(g.players[0].total, 12, reason: 'totals carry over');
    });

    test('does nothing while a round is in progress', () {
      final g = rig()..nextRound();
      expect(g.round, 1);
    });
  });

  test('the log keeps only the most recent entries', () {
    final g = rig();
    for (var i = 0; i < 60; i++) {
      g.players[0].line = [];
      g.players[0].status = Status.active;
      flip(g, 0, [n(5)]);
      flip(g, 0, [n(5)]);
    }
    expect(g.log.length, lessThanOrEqualTo(80));
    expect(g.log.last, isNot(contains('Round 1')));
  });
}
