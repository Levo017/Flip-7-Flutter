import 'dart:math';

import 'package:flip7_flutter/game/cards.dart';
import 'package:flip7_flutter/game/game.dart';

var _nextId = 1000;

GameCard n(int value) => GameCard.number(_nextId++, value);
GameCard zero() => GameCard.number(_nextId++, 0, special: Special.zero);
GameCard unlucky7() => GameCard.number(_nextId++, 7, special: Special.unlucky7);
GameCard lucky13() => GameCard.number(_nextId++, 13, special: Special.lucky13);
GameCard minus(int amount) => GameCard.minus(_nextId++, amount);
GameCard divide() => GameCard.divide(_nextId++);
GameCard action(ActionKind kind) => GameCard.action(_nextId++, kind);

/// Empties the table, deck and queue so a test can set up an exact position.
/// The first player to be offered a turn is player 0.
void clearTable(Game g) {
  g.stack.clear();
  g.prompt = null;
  g.deck = [];
  g.discard = [];
  g.dealer = g.players.length - 1;
  g.turn = g.players.length - 1;
  for (final p in g.players) {
    p.line = [];
    p.mods = [];
    p.status = Status.active;
  }
}

/// A game named P0, P1, … with an empty table, ready to be arranged.
Game rig({int players = 3, bool brutal = false, bool bots = false}) {
  final g = Game(
    [for (var i = 0; i < players; i++) PlayerConfig('P$i', bot: bots)],
    brutal: brutal,
    random: Random(7),
  );
  clearTable(g);
  return g;
}

/// Puts [cards] on top of the deck; the first one listed is drawn first.
void topDeck(Game g, List<GameCard> cards) {
  g.deck = [...g.deck, ...cards.reversed];
}

/// Steps until the game needs a decision or the round is over.
void run(Game g) {
  while (g.step()) {}
}

/// Has [pid] hit, drawing [cards] off the top, then runs to the next decision.
void flip(Game g, int pid, List<GameCard> cards) {
  topDeck(g, cards);
  g.prompt = HitStayPrompt(pid, mustHit: false);
  g.hit();
  run(g);
}

/// Every remaining active player stays, which ends the round.
void stayAll(Game g) {
  run(g);
  while (g.prompt is HitStayPrompt) {
    g.stay();
    run(g);
  }
}

List<int> values(Player p) => [for (final c in p.line) c.value];
