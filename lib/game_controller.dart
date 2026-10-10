import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'game/bot.dart';
import 'game/game.dart';

const _stepDelay = Duration(milliseconds: 650);
const _botDelay = Duration(milliseconds: 1000);

/// Owns the running [Game], paces dealing and CPU turns, and holds the bits of
/// UI state that depend on the game (focused hand, tentatively picked card).
class GameController extends ChangeNotifier {
  /// Pass a seeded [random] to make shuffles repeatable in tests.
  GameController({this.random});

  final Random? random;
  Game? game;
  bool fast = false;
  Timer? _timer;

  int _focusId = 0;
  int? _chosenCard;
  Prompt? _chosenFor;

  void start(List<PlayerConfig> players, {required bool brutal}) {
    final g = Game(players, brutal: brutal, random: random);
    game = g;
    _focusId = g.players.where((p) => !p.bot).firstOrNull?.id ?? 0;
    _changed();
  }

  void quit() {
    _timer?.cancel();
    game = null;
    notifyListeners();
  }

  void toggleFast() {
    fast = !fast;
    _changed();
  }

  /// The prompt, if it is a human's to answer.
  Prompt? get humanPrompt {
    final prompt = game?.prompt;
    return prompt != null && !game!.players[prompt.pid].bot ? prompt : null;
  }

  bool get canHit => humanPrompt is HitStayPrompt;

  bool get canStay {
    final prompt = humanPrompt;
    return prompt is HitStayPrompt && !prompt.mustHit;
  }

  /// The hand shown large in the centre: whichever human is deciding, or the
  /// last one who did. With no humans it follows the acting CPU.
  Player get focus => game!.players[_focusId];

  PickPrompt? get pickPrompt {
    final prompt = humanPrompt;
    return prompt is PickPrompt ? prompt : null;
  }

  /// A picked card waits for confirmation; it is forgotten once the prompt changes.
  int? get chosenCard => _chosenFor == game?.prompt ? _chosenCard : null;

  void selectCard(int cardId) {
    final prompt = pickPrompt;
    if (prompt == null || !prompt.options.contains(cardId)) return;
    _chosenCard = cardId;
    _chosenFor = prompt;
    notifyListeners();
  }

  void confirmCard() {
    final cardId = chosenCard;
    if (cardId == null) return;
    game!.chooseCard(cardId);
    _changed();
  }

  void hit() {
    if (!canHit) return;
    game!.hit();
    _changed();
  }

  void stay() {
    if (!canStay) return;
    game!.stay();
    _changed();
  }

  void choosePlayer(int id) {
    if (humanPrompt == null) return;
    game!.choosePlayer(id);
    _changed();
  }

  void nextRound() {
    game?.nextRound();
    _changed();
  }

  void _changed() {
    final g = game;
    if (g != null) {
      final hasHumans = g.players.any((p) => !p.bot);
      final wanted = hasHumans ? humanPrompt?.pid : g.prompt?.pid;
      if (wanted != null) _focusId = wanted;
    }
    notifyListeners();
    _schedule();
  }

  /// Auto-steps dealing and lets CPU players answer their prompts.
  void _schedule() {
    _timer?.cancel();
    final g = game;
    if (g == null || g.phase != Phase.playing) return;
    final prompt = g.prompt;
    if (prompt != null && !g.players[prompt.pid].bot) return;
    final delay = (prompt != null ? _botDelay : _stepDelay) * (fast ? 0.3 : 1);
    _timer = Timer(delay, () {
      if (prompt != null) {
        playBot(g);
      } else {
        g.step();
      }
      _changed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
