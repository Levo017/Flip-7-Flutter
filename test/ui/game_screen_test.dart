import 'package:flip7_flutter/game/cards.dart';
import 'package:flip7_flutter/game/game.dart';
import 'package:flip7_flutter/ui/card_view.dart';
import 'package:flip7_flutter/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'ui_helpers.dart';

void main() {
  group('layout', () {
    testGame('a desktop shows the players, the table and the feed', (
      tester,
      c,
    ) async {
      expect(find.text('PLAYERS'), findsOneWidget);
      expect(find.text('TABLE TALK'), findsOneWidget);
      expect(find.text('BUST RISK'), findsOneWidget);
      expect(find.text('ROUND 1'), findsOneWidget);
      expect(find.text('First to 200 wins'), findsOneWidget);
      expect(find.text('3 LEFT'), findsOneWidget);
      expect(find.byType(KeyHint), findsNWidgets(2));
    }, arrange: (g) => topDeck(g, [n(1), n(2), n(3)]));

    testGame('a tablet drops the feed', (tester, c) async {
      expect(find.text('PLAYERS'), findsOneWidget);
      expect(find.text('TABLE TALK'), findsNothing);
      expect(find.text('BUST RISK'), findsOneWidget);
    }, size: tablet);

    testGame('a phone shows only the table, without keyboard hints', (
      tester,
      c,
    ) async {
      expect(find.text('PLAYERS'), findsNothing);
      expect(find.text('TABLE TALK'), findsNothing);
      expect(find.text('BUST RISK'), findsNothing);
      expect(find.text('ROUND 1'), findsNothing);
      expect(find.byType(KeyHint), findsNothing);
      expect(find.text('FLIP A CARD'), findsOneWidget);
      expect(find.text('STAY'), findsOneWidget);
    }, size: phone);

    testGame(
      'eight players fit on every screen size',
      (tester, c) async {
        for (final size in [desktop, tablet, phone]) {
          tester.view.physicalSize = size;
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$size');
        }
        expect(find.byType(MiniCard), findsNWidgets(21));
      },
      players: [
        leo,
        for (var i = 1; i < 8; i++) PlayerConfig('Robot $i', bot: true),
      ],
      arrange: (g) {
        for (final p in g.players.skip(1)) {
          p.line = [n(13), n(12), n(11)];
        }
      },
    );

    testGame('a full hand of cards and modifiers fits on a phone', (
      tester,
      c,
    ) async {
      expect(find.byType(PlayingCard), findsNWidgets(10));
      expect(tester.takeException(), isNull);
    }, size: phone, arrange: (g) {
      g.players[0]
        ..line = [for (var v = 1; v <= 6; v++) n(v)]
        ..mods = [minus(2), minus(4), minus(6), divide()];
      g.prompt = const HitStayPrompt(0, mustHit: false);
    });

    testGame('the heading names Brutal Mode', (tester, c) async {
      expect(find.text('ROUND 1 · BRUTAL MODE'), findsOneWidget);
    }, brutal: true);
  });

  group('taking a turn', () {
    testGame('waits for the deal, then offers the turn', (tester, c) async {
      expect(find.text('DEALING'), findsOneWidget);
      expect(find.text('NO CARDS YET'), findsOneWidget);
      await stepOnce(tester);
      expect(find.text('YOUR TURN'), findsOneWidget);
      expect(find.text('ROUND SCORE'), findsOneWidget);
      expect(find.text('Keep flipping or lock in your points.'), findsOneWidget);
    });

    testGame('Flip a card puts a card in the hand', (tester, c) async {
      await stepOnce(tester);
      await tester.tap(find.text('FLIP A CARD'));
      await stepOnce(tester);
      expect(find.byType(PlayingCard), findsOneWidget);
      expect(values(c.focus), [5]);
      expect(find.text('1 of 7 numbers'), findsOneWidget);
    }, arrange: (g) => topDeck(g, [n(5), n(1)]));

    testGame('Stay locks the hand in', (tester, c) async {
      await tester.tap(find.text('STAY'));
      await tester.pump();
      expect(c.focus.status, Status.stayed);
      expect(find.text('2 of 7 numbers · stayed'), findsOneWidget);
      expect(find.text('Leo stays with 15.'), findsWidgets);
    }, arrange: (g) {
      g.players[0].line = [n(9), n(6)];
      g.prompt = const HitStayPrompt(0, mustHit: false);
    });

    testGame('F flips and S stays from the keyboard', (tester, c) async {
      await stepOnce(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await stepOnce(tester);
      expect(values(c.focus), [5]);

      c.game!.prompt = const HitStayPrompt(0, mustHit: false);
      await refresh(tester, c);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(c.focus.status, Status.stayed);
    }, arrange: (g) => topDeck(g, [n(5)]));

    testGame('the buttons are disabled when it is not your turn', (
      tester,
      c,
    ) async {
      await tester.tap(find.text('FLIP A CARD'));
      await tester.tap(find.text('STAY'));
      await tester.pump();
      expect(c.game!.prompt!.pid, 1);
      expect(c.game!.stack, isEmpty);
      expect(find.text('ASH IS CHOOSING'), findsOneWidget);
    }, arrange: (g) => g.prompt = const HitStayPrompt(1, mustHit: false));

    testGame('The Zero forbids staying and says why', (tester, c) async {
      expect(find.textContaining('you must keep flipping'), findsOneWidget);
      expect(find.text('1 of 7 numbers · The Zero'), findsOneWidget);
      expect(find.text('THE ZERO'), findsOneWidget);
      await tester.tap(find.text('STAY'));
      await tester.pump();
      expect(c.focus.status, Status.active);
    }, arrange: (g) {
      g.players[0].line = [zero()];
      g.prompt = const HitStayPrompt(0, mustHit: true);
    });

    testGame('bust risk reflects the cards left in the deck', (tester, c) async {
      expect(find.text('50%'), findsOneWidget);
    }, arrange: (g) {
      g.players[0].line = [n(5)];
      g.deck = [n(5), n(6)];
      g.prompt = const HitStayPrompt(0, mustHit: false);
    });
  });

  group('giving a card to a player', () {
    void arrange(Game g) {
      g.players[1].line = [n(12)];
      g.prompt = TargetPrompt(0, minus(6), [0, 1, 2, 3]);
    }

    testGame('the action bar offers every valid player', (tester, c) async {
      expect(find.text('Leo, who gets it?'), findsOneWidget);
      for (final label in ['MYSELF', 'ASH', 'BLAZE', 'CINDER']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('ASH'));
      await tester.pump();
      expect(c.game!.players[1].mods.single.label, '−6');
      expect(find.byTooltip('−6'), findsOneWidget);
    }, arrange: arrange);

    testGame('the card can be kept', (tester, c) async {
      await tester.tap(find.text('MYSELF'));
      await tester.pump();
      expect(c.focus.mods, hasLength(1));
      expect(find.text('MODIFIER'), findsOneWidget);
    }, arrange: arrange);

    testGame("tapping an opponent's hand also chooses them", (tester, c) async {
      await tester.tap(find.text('Blaze').last);
      await tester.pump();
      expect(c.game!.players[2].mods, hasLength(1));
    }, arrange: arrange);

    testGame('only the offered players are listed', (tester, c) async {
      expect(find.text('ASH'), findsOneWidget);
      expect(find.text('BLAZE'), findsNothing);
      expect(find.text('JUST ONE MORE!'), findsOneWidget);
    }, arrange: (g) {
      g.prompt = TargetPrompt(0, action(ActionKind.justOneMore), [0, 1]);
    });

    testGame('a CPU deciding is shown, not offered', (tester, c) async {
      expect(find.text('Ash is deciding…'), findsOneWidget);
      expect(find.text('ASH IS CHOOSING'), findsOneWidget);
      expect(find.text('MYSELF'), findsNothing);
    }, arrange: (g) => g.prompt = TargetPrompt(1, minus(2), [0, 1, 2, 3]));
  });

  group('picking a card', () {
    testGame('Steal: select a glowing card, then confirm', (tester, c) async {
      expect(find.text('STEAL'), findsOneWidget);
      expect(find.text('Leo: Select a glowing card to steal.'), findsOneWidget);
      await tester.tap(find.text('CHOOSE A CARD'));
      await tester.pump();
      expect(c.focus.line, isEmpty, reason: 'nothing is selected yet');

      await tester.tap(find.byType(MiniCard).first);
      await tester.pump();
      expect(c.chosenCard, isNotNull);
      await tester.tap(find.text('USE ACTION'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(values(c.focus), [12]);
      expect(find.byType(PlayingCard), findsOneWidget);
    }, arrange: (g) {
      final twelve = n(12);
      g.players[1].line = [twelve];
      g.players[2].line = [n(3)];
      g.prompt = PickPrompt(0, PickPurpose.steal, [twelve.id]);
    });

    testGame('only the offered cards can be selected', (tester, c) async {
      await tester.tap(find.byTooltip('3'), warnIfMissed: false);
      await tester.pump();
      expect(c.chosenCard, isNull);
      expect(find.text('CHOOSE A CARD'), findsOneWidget);
    }, arrange: (g) {
      final twelve = n(12);
      g.players[1].line = [twelve];
      g.players[2].line = [n(3)];
      g.prompt = PickPrompt(0, PickPurpose.steal, [twelve.id]);
    });

    testGame('Swap takes two cards in sequence', (tester, c) async {
      expect(find.text('SWAP'), findsOneWidget);
      await tester.tap(find.byType(PlayingCard));
      await tester.pump();
      await tester.tap(find.text('NEXT CARD'));
      await tester.pump();
      expect(
        find.text("Leo: Now select another player's card to swap it with."),
        findsOneWidget,
      );
      await tester.tap(find.byType(MiniCard));
      await tester.pump();
      await tester.tap(find.text('USE ACTION'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(values(c.focus), [13]);
      expect(values(c.game!.players[1]), [1]);
    }, arrange: (g) {
      final one = n(1);
      final thirteen = n(13);
      g.players[0].line = [one];
      g.players[1].line = [thirteen];
      g.prompt = PickPrompt(0, PickPurpose.swapFirst, [one.id, thirteen.id]);
    });

    testGame('Discard names itself', (tester, c) async {
      expect(find.text('DISCARD'), findsOneWidget);
      expect(find.text('Leo: Select a glowing card to discard.'), findsOneWidget);
    }, arrange: (g) {
      final nine = n(9);
      g.players[1].line = [nine];
      g.prompt = PickPrompt(0, PickPurpose.discard, [nine.id]);
    });
  });

  group('other moments', () {
    testGame('Flip Four progress shows the cards set aside', (tester, c) async {
      expect(find.text('FLIP FOUR!'), findsOneWidget);
      expect(
        find.text('Ash flips 3 more. Set aside until the flips are done:'),
        findsOneWidget,
      );
      expect(find.byTooltip('−2'), findsOneWidget);
    }, arrange: (g) {
      g.deck = [n(1), n(2), n(3)];
      g.stack.add(FlipFourTask(1, 3, [minus(2)]));
    });

    testGame('Flip Four with nothing set aside says only how many are left', (
      tester,
      c,
    ) async {
      expect(find.text('Ash flips 4 more.'), findsOneWidget);
    }, arrange: (g) {
      g.deck = [n(1), n(2), n(3), n(4)];
      g.stack.add(FlipFourTask(1, 4, []));
    });

    testGame('the Brutal Mode bonus can be turned on a rival', (tester, c) async {
      expect(find.text('FLIP 7!'), findsOneWidget);
      expect(find.text('Leo, take the bonus or take revenge?'), findsOneWidget);
      expect(find.text('+15 FOR ME'), findsOneWidget);
      await tester.tap(find.text('−15 ASH'));
      await tester.pump();
      expect(c.game!.players[1].roundScore, -15);
      expect(find.text('ROUND 1 RESULTS'), findsOneWidget);
    }, brutal: true, arrange: _flipSeven);

    testGame('the Brutal Mode bonus can be kept', (tester, c) async {
      await tester.tap(find.text('+15 FOR ME'));
      await tester.pump();
      expect(c.game!.players[0].roundScore, 28 + 15);
    }, brutal: true, arrange: _flipSeven);

    testGame('every player state is labelled', (tester, c) async {
      // Ash's chip, plus the note and the empty-hand placeholder for my own bust.
      expect(find.text('BUSTED'), findsNWidgets(3));
      expect(find.text('STAYED'), findsOneWidget);
      expect(find.text('FLIP 7'), findsOneWidget);
      expect(find.text('Busted'), findsNWidgets(2));
      expect(find.text('Stayed'), findsOneWidget);
      expect(find.text('Flip 7'), findsOneWidget);
    }, arrange: (g) {
      g.players[0].status = Status.busted;
      g.players[1].status = Status.busted;
      g.players[2]
        ..status = Status.stayed
        ..line = [n(9)];
      g.players[3]
        ..flip7 = true
        ..line = [for (var v = 1; v <= 7; v++) n(v)];
      g.roundOver = true;
    });

    testGame('the dealer is named in the players list', (tester, c) async {
      expect(find.text('Dealer'), findsOneWidget);
      expect(find.text('DEALER'), findsOneWidget);
    });
  });

  group('the players panel', () {
    testGame('ranks by total and says who leads', (tester, c) async {
      final names = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .where((t) => ['Leo', 'Ash', 'Blaze', 'Cinder'].contains(t));
      expect(names, ['Blaze', 'Ash', 'Leo', 'Cinder']);
      expect(find.text('Blaze leads by 5 points'), findsOneWidget);
      expect(find.text('+9 round'), findsOneWidget);
    }, arrange: (g) {
      g.players[0].total = 20;
      g.players[1]
        ..total = 40
        ..line = [n(9)];
      g.players[2].total = 45;
    });

    testGame('uses the singular for a one-point lead', (tester, c) async {
      expect(find.text('Ash leads by 1 point'), findsOneWidget);
    }, arrange: (g) => g.players[1].total = 1);

    testGame('reports a tie', (tester, c) async {
      expect(find.text('Tied at 0'), findsOneWidget);
    });
  });

  group('table talk', () {
    testGame('shows recent events, newest first, split by player', (
      tester,
      c,
    ) async {
      expect(find.text('busts!'), findsOneWidget);
      expect(find.text('puts −6 on Leo.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('puts −6 on Leo.')).dy,
        lessThan(tester.getTopLeft(find.text('busts!')).dy),
      );
      expect(find.textContaining('Round 1'), findsOneWidget);
    }, arrange: (g) {
      g.log
        ..add('💥 Ash busts!')
        ..add('Blaze puts −6 on Leo.');
    });

    testGame('its rules card opens the rules', (tester, c) async {
      await tester.tap(find.text('How to play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('RULES & CARD GUIDE'), findsOneWidget);
    }, arrange: (g) => g.prompt = const HitStayPrompt(0, mustHit: false));
  });

  group('the top bar', () {
    void arrange(Game g) => g.prompt = const HitStayPrompt(0, mustHit: false);

    testGame('toggles fast mode', (tester, c) async {
      await tester.tap(find.byTooltip('Fast mode is off'));
      await tester.pump();
      expect(c.fast, isTrue);
      expect(find.byTooltip('Fast mode is on'), findsOneWidget);
    }, arrange: arrange);

    testGame('opens the rules', (tester, c) async {
      await tester.tap(find.byTooltip('Rules'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('RULES & CARD GUIDE'), findsOneWidget);
      await tester.tap(find.text('GOT IT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('RULES & CARD GUIDE'), findsNothing);
    }, arrange: arrange);

    testGame('New game leaves the table', (tester, c) async {
      await tester.tap(find.text('NEW GAME'));
      await tester.pump();
      expect(c.game, isNull);
      expect(find.text('NO GAME'), findsOneWidget);
    }, arrange: arrange);
  });

  group('results', () {
    testGame('a finished round shows the scores and deals the next', (
      tester,
      c,
    ) async {
      stayAll(c.game!);
      await refresh(tester, c);
      expect(find.text('ROUND 1 RESULTS'), findsOneWidget);
      expect(find.text('Scores are in'), findsOneWidget);
      expect(find.text('ROUND OVER'), findsOneWidget);

      await tester.tap(find.text('DEAL ROUND 2'));
      await tester.pump();
      expect(c.game!.round, 2);
      expect(find.text('ROUND 1 RESULTS'), findsNothing);
      expect(find.text('ROUND 2'), findsOneWidget);
    }, arrange: (g) => g.players[0].line = [n(9)]);

    testGame('the end of the game names the winner', (tester, c) async {
      stayAll(c.game!);
      await refresh(tester, c);
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('Ash wins!'), findsOneWidget);
      expect(find.text('DEAL ROUND 2'), findsNothing);

      await tester.tap(find.text('NEW GAME').last);
      await tester.pump();
      expect(c.game, isNull);
    }, arrange: (g) {
      g.players[1]
        ..total = 195
        ..line = [n(10)];
    });

    testGame('results fit a phone', (tester, c) async {
      stayAll(c.game!);
      await refresh(tester, c);
      expect(find.text('DEAL ROUND 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, size: phone);
  });

  group('who is in the centre', () {
    testGame(
      'with several humans it is whoever is deciding',
      (tester, c) async {
        expect(find.text('MAYA’S TURN'), findsOneWidget);
        expect(find.text('MAYA · ROUND SCORE'), findsOneWidget);
        expect(c.focus.name, 'Maya');
      },
      players: const [leo, PlayerConfig('Maya', bot: false), ash],
      arrange: (g) => g.prompt = const HitStayPrompt(1, mustHit: false),
    );

    testGame(
      'with no humans it follows the acting CPU',
      (tester, c) async {
        expect(find.text('BLAZE IS CHOOSING'), findsOneWidget);
        expect(find.text('BLAZE · ROUND SCORE'), findsOneWidget);
      },
      players: const [ash, blaze],
      arrange: (g) => g.prompt = const HitStayPrompt(1, mustHit: false),
    );
  });
}

void _flipSeven(Game g) {
  g.players[0]
    ..line = [for (var v = 1; v <= 7; v++) n(v)]
    ..flip7 = true;
  g.roundOver = true;
  g.prompt = const BonusPrompt(0, [0, 1, 2, 3]);
}
