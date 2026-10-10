import 'package:flip7_flutter/game/cards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameCard', () {
    test('a plain number is labelled by its value', () {
      const card = GameCard.number(1, 9);
      expect(card.kind, CardKind.number);
      expect(card.isNumber, isTrue);
      expect(card.special, isNull);
      expect(card.label, '9');
    });

    test('special numbers keep their value and get a name', () {
      const zero = GameCard.number(1, 0, special: Special.zero);
      const unlucky = GameCard.number(2, 7, special: Special.unlucky7);
      const lucky = GameCard.number(3, 13, special: Special.lucky13);
      expect([zero.label, unlucky.label, lucky.label], [
        'The Zero',
        'Unlucky 7',
        'Lucky 13',
      ]);
      expect([zero.value, unlucky.value, lucky.value], [0, 7, 13]);
      expect(lucky.isNumber, isTrue);
    });

    test('a minus modifier carries the amount it subtracts', () {
      const card = GameCard.minus(1, 8);
      expect(card.kind, CardKind.modifier);
      expect(card.isNumber, isFalse);
      expect(card.divides, isFalse);
      expect(card.value, 8);
      expect(card.label, '−8');
    });

    test('the divide modifier subtracts nothing', () {
      const card = GameCard.divide(1);
      expect(card.kind, CardKind.modifier);
      expect(card.divides, isTrue);
      expect(card.value, 0);
      expect(card.label, '÷2');
    });

    test('every action has a readable name', () {
      final labels = {
        for (final kind in ActionKind.values)
          kind: GameCard.action(1, kind).label,
      };
      expect(labels, {
        ActionKind.justOneMore: 'Just One More!',
        ActionKind.swap: 'Swap',
        ActionKind.steal: 'Steal',
        ActionKind.discard: 'Discard',
        ActionKind.flipFour: 'Flip Four!',
      });
      expect(const GameCard.action(1, ActionKind.swap).isNumber, isFalse);
    });
  });

  group('buildDeck', () {
    final deck = buildDeck();
    int plain(int value) => deck
        .where((c) => c.isNumber && c.special == null && c.value == value)
        .length;

    test('has 108 uniquely numbered cards', () {
      expect(deck, hasLength(108));
      expect({for (final c in deck) c.id}, hasLength(108));
    });

    test('has as many of each number as its value, except 7 and 13', () {
      for (final v in [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12]) {
        expect(plain(v), v, reason: 'count of $v');
      }
      expect(plain(7), 6);
      expect(plain(13), 12);
    });

    test('has one of each special number', () {
      for (final special in Special.values) {
        expect(deck.where((c) => c.special == special), hasLength(1));
      }
    });

    test('has the six modifiers', () {
      final mods = deck.where((c) => c.kind == CardKind.modifier).toList();
      expect(mods.where((c) => c.divides), hasLength(1));
      expect(
        mods.where((c) => !c.divides).map((c) => c.value),
        unorderedEquals([2, 4, 6, 8, 10]),
      );
    });

    test('has two of each action', () {
      for (final kind in ActionKind.values) {
        expect(deck.where((c) => c.action == kind), hasLength(2));
      }
    });
  });
}
