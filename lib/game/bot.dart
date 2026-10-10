import 'dart:math';

import 'cards.dart';
import 'game.dart';

/// Round score a player is on track for, treating an illegal line as a bust.
double _projected(Player p, bool brutal) {
  final busted = p.status == Status.busted;
  if (!busted && isBust(p.line)) return 0;
  final score = scoreCards(
    line: p.line,
    mods: p.mods,
    busted: busted,
    flip7: p.flip7 || (!busted && p.line.length >= 7),
    brutal: brutal,
  );
  return score + p.line.length * 0.5;
}

/// How good the table looks for [me]: own projection minus the average opponent's.
double _utility(List<Player> players, int me, bool brutal) {
  final others = players.where((p) => p.id != me).toList();
  final sum = others.fold(0.0, (total, p) => total + _projected(p, brutal));
  return _projected(players[me], brutal) - sum / others.length;
}

double _simulate(Game g, int me, void Function(List<Player> players) mutate) {
  final players = [for (final p in g.players) p.copy()];
  mutate(players);
  return _utility(players, me, g.brutal);
}

T _best<T>(Iterable<T> items, double Function(T item) score) {
  late T top;
  var topScore = double.negativeInfinity;
  for (final item in items) {
    final value = score(item);
    if (value > topScore) {
      top = item;
      topScore = value;
    }
  }
  return top;
}

/// Unseen cards the next flip comes from (the discards, if the deck is about
/// to be reshuffled).
List<GameCard> _pool(Game g) => g.deck.isNotEmpty ? g.deck : g.discard;

List<GameCard> _withCard(Player p, GameCard card) =>
    card.special == Special.unlucky7 ? [card] : [...p.line, card];

/// Chance that the next flip busts [p].
double bustChance(Game g, Player p) {
  final cards = _pool(g);
  if (cards.isEmpty) return 0;
  final busts = cards
      .where((c) => c.isNumber && isBust(_withCard(p, c)))
      .length;
  return busts / cards.length;
}

/// Expected round score after one more flip.
double _hitValue(Game g, Player p) {
  final cards = _pool(g);
  if (cards.isEmpty) return 0;
  final current = scoreOf(p, g.brutal);
  var sum = 0;
  for (final c in cards) {
    if (!c.isNumber) {
      sum += current;
      continue;
    }
    final line = _withCard(p, c);
    if (isBust(line)) continue;
    sum += scoreCards(
      line: line,
      mods: c.special == Special.unlucky7 ? const [] : p.mods,
      busted: false,
      flip7: line.length >= 7,
      brutal: g.brutal,
    );
  }
  return sum / cards.length;
}

double _swapUtility(Game g, int me, int a, int b) => _simulate(g, me, (ps) {
  final (cardA, ownerA) = takeCard(ps, a);
  final (cardB, ownerB) = takeCard(ps, b);
  giveCard(ownerA, cardB);
  giveCard(ownerB, cardA);
});

double _stealUtility(Game g, int me, int cardId) =>
    _simulate(g, me, (ps) => giveCard(ps[me], takeCard(ps, cardId).$1));

double _discardUtility(Game g, int me, int cardId) =>
    _simulate(g, me, (ps) => takeCard(ps, cardId));

/// Answers the current prompt on behalf of a CPU player.
void playBot(Game g) {
  final prompt = g.prompt;
  if (prompt == null) return;
  final me = g.players[prompt.pid];
  double standing(Player p) => p.total + _projected(p, g.brutal);

  switch (prompt) {
    case HitStayPrompt():
      final current = scoreOf(me, g.brutal);
      if (prompt.mustHit || current == 0 || _hitValue(g, me) > current) {
        g.hit();
      } else {
        g.stay();
      }

    case BonusPrompt():
      int after(Player p) => p.total + scoreOf(p, g.brutal);
      final rival = _best(
        g.players.where((p) => p.id != me.id),
        (p) => after(p).toDouble(),
      );
      g.choosePlayer(after(rival) >= after(me) ? rival.id : me.id);

    case TargetPrompt():
      g.choosePlayer(_chooseTarget(g, prompt, me, standing));

    case PickPrompt():
      final options = prompt.options;
      final choice = switch (prompt.purpose) {
        PickPurpose.steal => _best(
          options,
          (id) => _stealUtility(g, me.id, id),
        ),
        PickPurpose.discard => _best(
          options,
          (id) => _discardUtility(g, me.id, id),
        ),
        PickPurpose.swapSecond => _best(
          options,
          (id) => _swapUtility(g, me.id, prompt.first!, id),
        ),
        PickPurpose.swapFirst => _best(
          options,
          (a) => g
              .swapSecondOptions(a)
              .map((b) => _swapUtility(g, me.id, a, b))
              .reduce(max),
        ),
      };
      g.chooseCard(choice);
  }
}

int _chooseTarget(
  Game g,
  TargetPrompt prompt,
  Player me,
  double Function(Player) standing,
) {
  final card = prompt.card;
  final options = prompt.options;
  final opponents = options.where((id) => id != me.id).toList();

  if (card.kind == CardKind.modifier) {
    return _best(
      opponents.isNotEmpty ? opponents : options,
      (id) =>
          _simulate(g, me.id, (ps) => ps[id].mods.add(card)) +
          standing(g.players[id]) * 0.01,
    );
  }

  switch (card.action!) {
    case ActionKind.justOneMore:
    case ActionKind.flipFour:
      final flips = card.action == ActionKind.flipFour ? 4 : 1;
      return _best(options, (id) {
        final p = g.players[id];
        final risk = 1 - pow(1 - bustChance(g, p), flips);
        final swing = risk * _projected(p, g.brutal) - (1 - risk) * 8 * flips;
        if (id != me.id) return swing + standing(p) * 0.01;
        // Just One More! on yourself also ends your round early.
        final endsRound =
            card.action == ActionKind.justOneMore && me.status == Status.active;
        return -swing - (endsRound ? 5 : 0);
      });

    case ActionKind.steal:
      if (options.contains(me.id)) {
        final base = _utility(g.players, me.id, g.brutal);
        final bestGain = g
            .stealOptions(me.id)
            .map((id) => _stealUtility(g, me.id, id))
            .reduce(max);
        if (opponents.isEmpty || bestGain >= base - 1) return me.id;
      }
      return _best(opponents, (id) => -standing(g.players[id]));

    case ActionKind.swap:
      return options.contains(me.id) ? me.id : options.first;

    case ActionKind.discard:
      return _best(
        options,
        (id) => g.players[id].cards
            .map((c) => _discardUtility(g, me.id, c.id))
            .reduce(max),
      );
  }
}
