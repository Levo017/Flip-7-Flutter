enum CardKind { number, modifier, action }

enum Special { zero, unlucky7, lucky13 }

enum ActionKind { justOneMore, swap, steal, discard, flipFour }

const _actionNames = {
  ActionKind.justOneMore: 'Just One More!',
  ActionKind.swap: 'Swap',
  ActionKind.steal: 'Steal',
  ActionKind.discard: 'Discard',
  ActionKind.flipFour: 'Flip Four!',
};

class GameCard {
  const GameCard.number(this.id, this.value, {this.special})
    : kind = CardKind.number,
      divides = false,
      action = null;

  /// A minus modifier; [value] is the amount subtracted.
  const GameCard.minus(this.id, this.value)
    : kind = CardKind.modifier,
      divides = false,
      special = null,
      action = null;

  const GameCard.divide(this.id)
    : kind = CardKind.modifier,
      value = 0,
      divides = true,
      special = null,
      action = null;

  const GameCard.action(this.id, ActionKind this.action)
    : kind = CardKind.action,
      value = 0,
      divides = false,
      special = null;

  final int id;
  final CardKind kind;
  final int value;
  final bool divides;
  final Special? special;
  final ActionKind? action;

  bool get isNumber => kind == CardKind.number;

  String get label {
    switch (kind) {
      case CardKind.action:
        return _actionNames[action]!;
      case CardKind.modifier:
        return divides ? '÷2' : '−$value';
      case CardKind.number:
        return switch (special) {
          Special.zero => 'The Zero',
          Special.unlucky7 => 'Unlucky 7',
          Special.lucky13 => 'Lucky 13',
          null => '$value',
        };
    }
  }
}

/// The 108-card deck: 89 numbers, 3 special numbers, 6 modifiers, 10 actions.
List<GameCard> buildDeck() {
  final cards = <GameCard>[];
  var id = 0;
  for (var v = 1; v <= 13; v++) {
    final count = v == 7 ? 6 : (v == 13 ? 12 : v);
    for (var i = 0; i < count; i++) {
      cards.add(GameCard.number(id++, v));
    }
  }
  cards.add(GameCard.number(id++, 0, special: Special.zero));
  cards.add(GameCard.number(id++, 7, special: Special.unlucky7));
  cards.add(GameCard.number(id++, 13, special: Special.lucky13));
  for (final amount in [2, 4, 6, 8, 10]) {
    cards.add(GameCard.minus(id++, amount));
  }
  cards.add(GameCard.divide(id++));
  for (final action in ActionKind.values) {
    for (var i = 0; i < 2; i++) {
      cards.add(GameCard.action(id++, action));
    }
  }
  return cards;
}
