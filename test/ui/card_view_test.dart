import 'package:flip7_flutter/game/cards.dart';
import 'package:flip7_flutter/ui/card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'ui_helpers.dart';

Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  group('PlayingCard', () {
    testWidgets('a number shows its value in the middle and both corners', (
      tester,
    ) async {
      await tester.pumpWidget(host(PlayingCard(card: n(8), width: 100)));
      await _settle(tester);
      expect(find.text('8'), findsNWidgets(3));
      expect(tester.getSize(find.byType(Container).first).width, 100);
    });

    testWidgets('keeps the card proportions', (tester) async {
      await tester.pumpWidget(host(PlayingCard(card: n(8), width: 69)));
      await _settle(tester);
      final size = tester.getSize(
        find
            .descendant(
              of: find.byType(PlayingCard),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(size.height, closeTo(100, 0.01));
    });

    for (final (card, value, caption) in [
      (minus(6), '−6', 'MODIFIER'),
      (divide(), '÷2', 'MODIFIER'),
      (zero(), '0', 'THE ZERO'),
      (unlucky7(), '7', 'UNLUCKY'),
      (lucky13(), '13', 'LUCKY'),
      (action(ActionKind.steal), '⚡', 'STEAL'),
      (action(ActionKind.flipFour), '⚡', 'FLIP FOUR!'),
    ]) {
      testWidgets('${card.label} is captioned $caption', (tester) async {
        await tester.pumpWidget(host(PlayingCard(card: card, width: 100)));
        await _settle(tester);
        expect(find.text(caption), findsOneWidget);
        expect(find.text(value), findsNWidgets(3));
      });
    }

    testWidgets('reports a tap only when it is pickable', (tester) async {
      var taps = 0;
      final card = n(4);
      await tester.pumpWidget(
        host(PlayingCard(card: card, width: 100, onTap: () => taps++)),
      );
      await _settle(tester);
      await tester.tap(find.byType(PlayingCard), warnIfMissed: false);
      expect(taps, 0);

      await tester.pumpWidget(
        host(
          PlayingCard(card: card, width: 100, pickable: true, onTap: () => taps++),
        ),
      );
      await tester.tap(find.byType(PlayingCard));
      expect(taps, 1);
    });

    testWidgets('lifts and straightens when selected', (tester) async {
      await tester.pumpWidget(
        host(PlayingCard(card: n(4), width: 100, index: 0, selected: true)),
      );
      await _settle(tester);
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset.dy, lessThan(0));
      final rotate = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(AnimatedSlide),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(rotate.transform.isIdentity(), isTrue);
    });
  });

  group('MiniCard', () {
    testWidgets('shows the short value with the full name as a tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(host(MiniCard(card: unlucky7())));
      expect(find.text('7'), findsOneWidget);
      expect(find.byTooltip('Unlucky 7'), findsOneWidget);
    });

    testWidgets('reports a tap only when it is pickable', (tester) async {
      var taps = 0;
      final card = minus(4);
      await tester.pumpWidget(host(MiniCard(card: card, onTap: () => taps++)));
      await tester.tap(find.byType(MiniCard), warnIfMissed: false);
      expect(taps, 0);

      await tester.pumpWidget(
        host(MiniCard(card: card, pickable: true, onTap: () => taps++)),
      );
      await tester.tap(find.byType(MiniCard));
      expect(taps, 1);
    });

    testWidgets('is struck through and faded for a busted player', (
      tester,
    ) async {
      await tester.pumpWidget(host(MiniCard(card: n(6), faded: true)));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.52);
      final text = tester.widget<Text>(find.text('6'));
      expect(text.style!.decoration, TextDecoration.lineThrough);
    });

    testWidgets('lifts when selected', (tester) async {
      await tester.pumpWidget(
        host(MiniCard(card: n(6), pickable: true, selected: true)),
      );
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset.dy, lessThan(0));
    });
  });
}
