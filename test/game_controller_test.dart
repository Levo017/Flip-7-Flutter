import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flip7_flutter/game/game.dart';
import 'package:flip7_flutter/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _human = PlayerConfig('Leo', bot: false);
const _ash = PlayerConfig('Ash', bot: true);
const _blaze = PlayerConfig('Blaze', bot: true);

/// Starts a game and clears the table so Leo (player 0) is offered the first turn.
GameController _started({
  List<PlayerConfig> players = const [_human, _ash, _blaze],
  bool brutal = false,
}) {
  final c = GameController(random: Random(3))..start(players, brutal: brutal);
  clearTable(c.game!);
  return c;
}

void main() {
  test('has no game until one is started', () {
    final c = GameController();
    expect(c.game, isNull);
    expect(c.humanPrompt, isNull);
    expect(c.pickPrompt, isNull);
    expect(c.chosenCard, isNull);
    expect(c.canHit, isFalse);
    expect(c.canStay, isFalse);
    c
      ..hit()
      ..stay()
      ..choosePlayer(0)
      ..confirmCard()
      ..selectCard(1)
      ..nextRound();
    expect(c.game, isNull);
    c.dispose();
  });

  test('start creates the game, notifies and focuses the first human', () {
    fakeAsync((async) {
      var notified = 0;
      final c = GameController(random: Random(3))..addListener(() => notified++);
      c.start(const [_ash, _human, _blaze], brutal: true);
      expect(c.game!.players, hasLength(3));
      expect(c.game!.brutal, isTrue);
      expect(c.focus.name, 'Leo');
      expect(notified, 1);
      c.dispose();
    });
  });

  test('deals on a timer until a human has to decide', () {
    fakeAsync((async) {
      final c = _started();
      expect(c.humanPrompt, isNull);
      async.elapse(const Duration(milliseconds: 600));
      expect(c.game!.prompt, isNull, reason: 'a step takes 650 ms');
      async.elapse(const Duration(milliseconds: 100));
      expect(c.humanPrompt, isA<HitStayPrompt>());
      expect(c.canHit, isTrue);
      expect(c.canStay, isTrue);
      expect(async.pendingTimers, isEmpty, reason: 'it waits for the human');
      c.dispose();
    });
  });

  test('fast mode shortens the delays', () {
    fakeAsync((async) {
      final c = _started()..toggleFast();
      expect(c.fast, isTrue);
      async.elapse(const Duration(milliseconds: 200));
      expect(c.humanPrompt, isA<HitStayPrompt>());
      c.toggleFast();
      expect(c.fast, isFalse);
      c.dispose();
    });
  });

  test('hit flips a card, then the CPU players take their turns', () {
    fakeAsync((async) {
      final c = _started();
      final g = c.game!;
      topDeck(g, [n(5), n(1), n(2)]);
      async.elapse(const Duration(seconds: 1));
      c.hit();
      expect(c.canHit, isFalse);
      // One step flips the card, the next offers the turn to Ash.
      async.elapse(const Duration(milliseconds: 1400));
      expect(values(g.players[0]), [5]);
      expect(g.prompt!.pid, 1, reason: "it is Ash's turn");
      expect(c.humanPrompt, isNull);
      expect(c.focus.name, 'Leo', reason: 'focus stays on the human');

      async.elapse(const Duration(seconds: 6));
      expect(values(g.players[1]), [1]);
      expect(values(g.players[2]), [2]);
      expect(c.humanPrompt, isA<HitStayPrompt>());
      c.dispose();
    });
  });

  test('stay locks the hand in', () {
    fakeAsync((async) {
      final c = _started();
      c.game!.players[0].line = [n(9)];
      async.elapse(const Duration(seconds: 1));
      c.stay();
      expect(c.game!.players[0].status, Status.stayed);
      c.dispose();
    });
  });

  test('stay is refused while holding The Zero', () {
    fakeAsync((async) {
      final c = _started();
      c.game!.players[0].line = [zero()];
      async.elapse(const Duration(seconds: 1));
      expect(c.canHit, isTrue);
      expect(c.canStay, isFalse);
      c.stay();
      expect(c.game!.players[0].status, Status.active);
      c.dispose();
    });
  });

  test("a human cannot answer a CPU player's prompt", () {
    fakeAsync((async) {
      final c = _started();
      final g = c.game!;
      g.prompt = TargetPrompt(1, minus(4), [0, 1, 2]);
      expect(c.humanPrompt, isNull);
      c
        ..hit()
        ..stay()
        ..choosePlayer(0);
      expect(g.prompt, isA<TargetPrompt>());
      expect(g.players[0].mods, isEmpty);
      c.dispose();
    });
  });

  test('choosePlayer answers a target prompt', () {
    fakeAsync((async) {
      final c = _started();
      final g = c.game!;
      final m = minus(4);
      g.prompt = TargetPrompt(0, m, [0, 1, 2]);
      c.choosePlayer(2);
      expect(g.players[2].mods, [m]);
      c.dispose();
    });
  });

  test('a card is selected first and only moved on confirmation', () {
    fakeAsync((async) {
      final c = _started();
      final g = c.game!;
      final nine = n(9);
      final four = n(4);
      g.players[1].line = [nine, four];
      g.prompt = PickPrompt(0, PickPurpose.steal, [nine.id, four.id]);
      var notified = 0;
      c.addListener(() => notified++);

      expect(c.pickPrompt, isNotNull);
      c.confirmCard();
      expect(g.players[1].line, hasLength(2), reason: 'nothing chosen yet');

      c.selectCard(12345);
      expect(c.chosenCard, isNull, reason: 'not one of the options');
      c.selectCard(nine.id);
      expect(c.chosenCard, nine.id);
      c.selectCard(four.id);
      expect(c.chosenCard, four.id);
      expect(notified, 2);

      c.confirmCard();
      expect(g.players[0].line, [four]);
      expect(c.chosenCard, isNull);
      c.dispose();
    });
  });

  test('the selection is forgotten when the prompt changes', () {
    fakeAsync((async) {
      final c = _started();
      final g = c.game!;
      final one = n(1);
      final thirteen = n(13);
      g.players[0].line = [one];
      g.players[1].line = [thirteen];
      g.prompt = PickPrompt(0, PickPurpose.swapFirst, [one.id, thirteen.id]);
      c
        ..selectCard(one.id)
        ..confirmCard();
      expect((c.pickPrompt)!.purpose, PickPurpose.swapSecond);
      expect(c.chosenCard, isNull);
      c
        ..selectCard(thirteen.id)
        ..confirmCard();
      expect(values(g.players[0]), [13]);
      c.dispose();
    });
  });

  test('selecting a card does nothing without a pick prompt', () {
    fakeAsync((async) {
      final c = _started();
      async.elapse(const Duration(seconds: 1));
      c.selectCard(1);
      expect(c.chosenCard, isNull);
      c.dispose();
    });
  });

  test('with no humans the focus follows whichever CPU is deciding', () {
    fakeAsync((async) {
      final c = _started(players: const [_ash, _blaze]);
      final g = c.game!;
      expect(c.focus.id, 0);
      g.prompt = TargetPrompt(1, minus(4), [0, 1]);
      c.toggleFast();
      expect(c.focus.id, 1);
      expect(c.humanPrompt, isNull);
      c.dispose();
    });
  });

  test('an all-CPU round plays itself out, and nextRound deals again', () {
    fakeAsync((async) {
      final c = GameController(random: Random(5))
        ..start(const [_ash, _blaze], brutal: false);
      async.elapse(const Duration(minutes: 10));
      final g = c.game!;
      expect(g.phase, Phase.roundEnd);
      expect(async.pendingTimers, isEmpty, reason: 'nothing runs between rounds');
      c.nextRound();
      expect(g.round, 2);
      expect(g.phase, Phase.playing);
      expect(async.pendingTimers, hasLength(1));
      c.dispose();
    });
  });

  test('quit drops the game and stops the clock', () {
    fakeAsync((async) {
      var notified = 0;
      final c = _started()..addListener(() => notified++);
      expect(async.pendingTimers, hasLength(1));
      c.quit();
      expect(c.game, isNull);
      expect(notified, 1);
      expect(async.pendingTimers, isEmpty);
      c.dispose();
    });
  });

  test('dispose cancels the pending step', () {
    fakeAsync((async) {
      final c = _started();
      expect(async.pendingTimers, hasLength(1));
      c.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('starting over replaces the running game', () {
    fakeAsync((async) {
      final c = _started();
      final first = c.game;
      c.start(const [_human, _ash], brutal: false);
      expect(c.game, isNot(same(first)));
      expect(async.pendingTimers, hasLength(1));
      expect(c.game!.players, hasLength(2));
      c.dispose();
    });
  });
}
