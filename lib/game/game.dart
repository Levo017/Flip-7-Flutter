import 'dart:math';

import 'cards.dart';

const targetScore = 200;
const flip7Bonus = 15;
const _maxLog = 80;

enum Status { active, stayed, busted }

enum Phase { playing, roundEnd, gameOver }

enum DrawVia { deal, hit, justOneMore }

enum PickPurpose { steal, discard, swapFirst, swapSecond }

class PlayerConfig {
  const PlayerConfig(this.name, {required this.bot});
  final String name;
  final bool bot;
}

class Player {
  Player(this.id, this.name, {required this.bot});

  final int id;
  final String name;
  final bool bot;
  int total = 0;
  List<GameCard> line = [];
  List<GameCard> mods = [];
  Status status = Status.active;
  bool flip7 = false;

  /// Score of the last finished round, null while a round is in progress.
  int? roundScore;

  List<GameCard> get cards => [...mods, ...line];
  bool get hasZero => line.any((c) => c.special == Special.zero);

  Player copy() => Player(id, name, bot: bot)
    ..total = total
    ..line = [...line]
    ..mods = [...mods]
    ..status = status
    ..flip7 = flip7
    ..roundScore = roundScore;
}

/// A line busts on a duplicate number; Lucky 13 allows one extra 13.
bool isBust(List<GameCard> line) {
  final counts = <int, int>{};
  for (final c in line) {
    counts[c.value] = (counts[c.value] ?? 0) + 1;
  }
  final lucky = line.any((c) => c.special == Special.lucky13);
  return counts.entries.any((e) => e.value > (e.key == 13 && lucky ? 2 : 1));
}

/// Numbers, then ÷2 (rounded down), then minus modifiers, then the Flip 7 bonus.
int scoreCards({
  required List<GameCard> line,
  required List<GameCard> mods,
  required bool busted,
  required bool flip7,
  required bool brutal,
  bool bonus = true,
}) {
  final dead = busted || (line.any((c) => c.special == Special.zero) && !flip7);
  var n = dead ? 0 : line.fold(0, (sum, c) => sum + c.value);
  if (mods.any((m) => m.divides)) n ~/= 2;
  for (final m in mods) {
    n -= m.value;
  }
  if (!brutal) n = max(0, n);
  if (flip7 && bonus) n += flip7Bonus;
  return n;
}

int scoreOf(Player p, bool brutal, {bool bonus = true}) => scoreCards(
  line: p.line,
  mods: p.mods,
  busted: p.status == Status.busted,
  flip7: p.flip7,
  brutal: brutal,
  bonus: bonus,
);

Player ownerOf(List<Player> players, int cardId) =>
    players.firstWhere((p) => p.cards.any((c) => c.id == cardId));

(GameCard, Player) takeCard(List<Player> players, int cardId) {
  final owner = ownerOf(players, cardId);
  final card = owner.cards.firstWhere((c) => c.id == cardId);
  owner.line.remove(card);
  owner.mods.remove(card);
  return (card, owner);
}

void giveCard(Player p, GameCard card) {
  if (card.isNumber) {
    p.line.add(card);
  } else if (card.kind == CardKind.modifier) {
    p.mods.add(card);
  }
}

// ---------- Queued work and pending decisions ----------

sealed class Task {
  const Task(this.pid);
  final int pid;
}

class DrawTask extends Task {
  const DrawTask(super.pid, this.via);
  final DrawVia via;
}

class ForceStayTask extends Task {
  const ForceStayTask(super.pid);
}

class FlipFourTask extends Task {
  FlipFourTask(super.pid, this.left, this.held);
  int left;

  /// Actions and modifiers flipped so far; they resolve once all four are drawn.
  final List<GameCard> held;
}

class ResolveTask extends Task {
  const ResolveTask(super.pid, this.card);
  final GameCard card;
}

sealed class Prompt {
  const Prompt(this.pid);

  /// The player who has to decide.
  final int pid;
}

class HitStayPrompt extends Prompt {
  const HitStayPrompt(super.pid, {required this.mustHit});
  final bool mustHit;
}

/// Choose which player receives an action or modifier card.
class TargetPrompt extends Prompt {
  const TargetPrompt(super.pid, this.card, this.options);
  final GameCard card;
  final List<int> options;
}

/// Choose a face-up card (by id) to steal, discard or swap.
class PickPrompt extends Prompt {
  const PickPrompt(super.pid, this.purpose, this.options, {this.first});
  final PickPurpose purpose;
  final List<int> options;
  final int? first;
}

/// Brutal Mode: take the Flip 7 bonus, or make another player lose it.
class BonusPrompt extends Prompt {
  const BonusPrompt(super.pid, this.options);
  final List<int> options;
}

// ---------- The game ----------

class Game {
  Game(List<PlayerConfig> configs, {required this.brutal, Random? random})
    : _random = random ?? Random(),
      players = [
        for (final (i, c) in configs.indexed) Player(i, c.name, bot: c.bot),
      ] {
    deck = buildDeck()..shuffle(_random);
    dealer = _random.nextInt(players.length);
    _startRound();
  }

  final Random _random;
  final bool brutal;
  final List<Player> players;
  List<GameCard> deck = [];
  List<GameCard> discard = [];
  int dealer = 0;
  int turn = 0;
  int round = 0;
  Phase phase = Phase.playing;
  bool roundOver = false;
  final List<Task> stack = [];
  Prompt? prompt;
  final List<String> log = [];
  int? winner;

  Iterable<Player> get _live => players.where((p) => p.status != Status.busted);

  List<int> stealOptions(int pid) => [
    for (final p in _live)
      if (p.id != pid)
        for (final c in p.cards) c.id,
  ];

  List<int> swapFirstOptions() {
    final holders = _live.where((p) => p.cards.isNotEmpty).toList();
    if (holders.length < 2) return [];
    return [
      for (final p in holders)
        for (final c in p.cards) c.id,
    ];
  }

  List<int> swapSecondOptions(int first) {
    final owner = ownerOf(players, first);
    return [
      for (final p in _live)
        if (p != owner)
          for (final c in p.cards) c.id,
    ];
  }

  List<int> _validReceivers(GameCard card) {
    final ids = [for (final p in _live) p.id];
    if (card.kind == CardKind.modifier) {
      return brutal ? [for (final p in players) p.id] : ids;
    }
    return switch (card.action!) {
      ActionKind.justOneMore || ActionKind.flipFour => ids,
      ActionKind.steal =>
        ids.where((id) => stealOptions(id).isNotEmpty).toList(),
      ActionKind.swap => swapFirstOptions().isNotEmpty ? ids : [],
      ActionKind.discard =>
        ids.where((id) => players[id].cards.isNotEmpty).toList(),
    };
  }

  void _log(String message) {
    log.add(message);
    if (log.length > _maxLog) log.removeAt(0);
  }

  GameCard? _drawCard() {
    if (deck.isEmpty && discard.isNotEmpty) {
      deck = discard..shuffle(_random);
      discard = [];
      _log('The deck ran out — the discards are shuffled into a new deck.');
    }
    return deck.isEmpty ? null : deck.removeLast();
  }

  void _flushStack() {
    for (final task in stack) {
      if (task is ResolveTask) discard.add(task.card);
      if (task is FlipFourTask) discard.addAll(task.held);
    }
    stack.clear();
  }

  void _finalizeRound(int? penaltyTo) {
    for (final p in players) {
      var score = scoreOf(p, brutal, bonus: penaltyTo == null);
      if (p.id == penaltyTo) score -= flip7Bonus;
      p.roundScore = score;
      p.total += score;
    }
    prompt = null;
    final best = players.map((p) => p.total).reduce(max);
    final leaders = players.where((p) => p.total == best).toList();
    if (best >= targetScore && leaders.length == 1) {
      phase = Phase.gameOver;
      winner = leaders.first.id;
      _log('${leaders.first.name} wins the game with $best points!');
    } else {
      phase = Phase.roundEnd;
      if (best >= targetScore) {
        _log('Tied at $best — play another round to break the tie.');
      }
    }
  }

  void _endRound() {
    _flushStack();
    roundOver = true;
    final flipper = players.where((p) => p.flip7).firstOrNull;
    if (brutal && flipper != null) {
      prompt = BonusPrompt(flipper.id, [for (final p in players) p.id]);
      return;
    }
    _finalizeRound(null);
  }

  void _bust(Player p) {
    discard
      ..addAll(p.line)
      ..addAll(p.mods);
    p.line = [];
    p.mods = [];
    p.status = Status.busted;
    _log('💥 ${p.name} busts!');
  }

  void _checkStatus(Player p) {
    if (p.status == Status.busted || roundOver) return;
    if (isBust(p.line)) {
      _bust(p);
    } else if (p.line.length >= 7) {
      p.flip7 = true;
      _log('🎉 ${p.name} FLIPS 7! The round ends immediately.');
      _endRound();
    }
  }

  /// Hands a freshly flipped card to a player. Actions and modifiers go to
  /// [hold] during a Flip Four.
  void _receive(Player p, GameCard card, List<GameCard>? hold) {
    _log('${p.name} flips ${card.label}.');
    if (!card.isNumber) {
      if (hold != null) {
        hold.add(card);
      } else {
        stack.add(ResolveTask(p.id, card));
      }
      return;
    }
    if (card.special == Special.unlucky7 && p.cards.isNotEmpty) {
      discard
        ..addAll(p.line)
        ..addAll(p.mods);
      p.line = [];
      p.mods = [];
      _log('Unlucky 7! ${p.name} discards everything else.');
    }
    p.line.add(card);
    _checkStatus(p);
  }

  void _applyTarget(int pid, GameCard card, int targetId) {
    final from = players[pid];
    final target = players[targetId];
    final who = target == from ? 'themself' : target.name;
    if (card.kind == CardKind.modifier) {
      target.mods.add(card);
      _log('${from.name} puts ${card.label} on $who.');
      return;
    }
    discard.add(card);
    _log('${from.name} plays ${card.label} on $who.');
    switch (card.action!) {
      case ActionKind.justOneMore:
        stack
          ..add(ForceStayTask(targetId))
          ..add(DrawTask(targetId, DrawVia.justOneMore));
      case ActionKind.flipFour:
        stack.add(FlipFourTask(targetId, 4, []));
      case ActionKind.steal:
        prompt = PickPrompt(
          targetId,
          PickPurpose.steal,
          stealOptions(targetId),
        );
      case ActionKind.swap:
        prompt = PickPrompt(
          targetId,
          PickPurpose.swapFirst,
          swapFirstOptions(),
        );
      case ActionKind.discard:
        prompt = PickPrompt(pid, PickPurpose.discard, [
          for (final c in target.cards) c.id,
        ]);
    }
  }

  void _nextTurn() {
    final n = players.length;
    for (var i = 1; i <= n; i++) {
      final p = players[(turn + i) % n];
      if (p.status == Status.active) {
        turn = p.id;
        prompt = HitStayPrompt(p.id, mustHit: p.hasZero);
        return;
      }
    }
    _endRound();
  }

  void _startRound() {
    for (final p in players) {
      discard
        ..addAll(p.line)
        ..addAll(p.mods);
      p.line = [];
      p.mods = [];
      p.status = Status.active;
      p.flip7 = false;
      p.roundScore = null;
    }
    final n = players.length;
    round++;
    dealer = (dealer + 1) % n;
    turn = dealer;
    phase = Phase.playing;
    roundOver = false;
    prompt = null;
    stack.clear();
    for (var i = n; i >= 1; i--) {
      stack.add(DrawTask((dealer + i) % n, DrawVia.deal));
    }
    _log('— Round $round — ${players[dealer].name} deals.');
  }

  void nextRound() {
    if (phase == Phase.roundEnd) _startRound();
  }

  /// Advances the game by one automatic step. Returns false when it is
  /// waiting on a prompt or the round is over.
  bool step() {
    if (phase != Phase.playing || prompt != null || roundOver) return false;
    if (stack.isEmpty) {
      _nextTurn();
      return true;
    }
    final task = stack.removeLast();
    final p = players[task.pid];
    switch (task) {
      case DrawTask():
        final skip = task.via == DrawVia.deal
            ? p.status != Status.active
            : p.status == Status.busted;
        if (skip) break;
        final card = _drawCard();
        if (card == null) {
          _log('No cards left anywhere — the round ends.');
          _endRound();
          break;
        }
        _receive(p, card, null);
      case ForceStayTask():
        if (p.status == Status.active) {
          p.status = Status.stayed;
          _log('${p.name} must stay.');
        }
      case FlipFourTask():
        if (p.status == Status.busted) {
          discard.addAll(task.held);
          break;
        }
        if (task.left == 0) {
          for (final card in task.held.reversed) {
            stack.add(ResolveTask(p.id, card));
          }
          break;
        }
        final card = _drawCard();
        if (card == null) {
          discard.addAll(task.held);
          _log('No cards left anywhere — the round ends.');
          _endRound();
          break;
        }
        _receive(p, card, task.held);
        if (roundOver || p.status == Status.busted) {
          discard.addAll(task.held);
        } else {
          task.left--;
          stack.add(task);
        }
      case ResolveTask():
        final options = p.status == Status.busted
            ? <int>[]
            : _validReceivers(task.card);
        if (options.isEmpty) {
          discard.add(task.card);
          _log('${task.card.label} has no valid target and is discarded.');
        } else if (options.length == 1) {
          _applyTarget(p.id, task.card, options.first);
        } else {
          prompt = TargetPrompt(p.id, task.card, options);
        }
    }
    return true;
  }

  // ---------- Answers to the current prompt (invalid ones are ignored) ----------

  void hit() {
    final current = prompt;
    if (current is! HitStayPrompt) return;
    prompt = null;
    stack.add(DrawTask(current.pid, DrawVia.hit));
  }

  void stay() {
    final current = prompt;
    if (current is! HitStayPrompt || current.mustHit) return;
    final p = players[current.pid];
    prompt = null;
    p.status = Status.stayed;
    _log('${p.name} stays with ${scoreOf(p, brutal)}.');
  }

  void choosePlayer(int id) {
    final current = prompt;
    if (current is TargetPrompt && current.options.contains(id)) {
      prompt = null;
      _applyTarget(current.pid, current.card, id);
    } else if (current is BonusPrompt && current.options.contains(id)) {
      final p = players[current.pid];
      if (id == p.id) {
        _log('${p.name} takes the +$flip7Bonus Flip 7 bonus.');
      } else {
        _log(
          '${p.name} hits ${players[id].name} with −$flip7Bonus instead of taking the bonus.',
        );
      }
      _finalizeRound(id == p.id ? null : id);
    }
  }

  void chooseCard(int cardId) {
    final current = prompt;
    if (current is! PickPrompt || !current.options.contains(cardId)) return;
    final p = players[current.pid];
    prompt = null;
    switch (current.purpose) {
      case PickPurpose.swapFirst:
        prompt = PickPrompt(
          p.id,
          PickPurpose.swapSecond,
          swapSecondOptions(cardId),
          first: cardId,
        );
      case PickPurpose.swapSecond:
        final (a, ownerA) = takeCard(players, current.first!);
        final (b, ownerB) = takeCard(players, cardId);
        giveCard(ownerA, b);
        giveCard(ownerB, a);
        _log(
          "${p.name} swaps ${ownerA.name}'s ${a.label} with ${ownerB.name}'s ${b.label}.",
        );
        // Resolve busts for both before a Flip 7 can end the round.
        for (final owner in [ownerA, ownerB]) {
          if (isBust(owner.line)) _bust(owner);
        }
        _checkStatus(ownerA);
        _checkStatus(ownerB);
      case PickPurpose.steal:
        final (card, owner) = takeCard(players, cardId);
        giveCard(p, card);
        _log('${p.name} steals ${card.label} from ${owner.name}.');
        _checkStatus(p);
      case PickPurpose.discard:
        final (card, owner) = takeCard(players, cardId);
        discard.add(card);
        _log("${p.name} discards ${owner.name}'s ${card.label}.");
    }
  }
}
