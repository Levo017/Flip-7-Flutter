import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/bot.dart';
import '../game/game.dart';
import '../game_controller.dart';
import 'card_view.dart';
import 'rules_dialog.dart';
import 'theme.dart';

const _wideBreakpoint = 1100.0;
const _narrowBreakpoint = 780.0;

String _statusOf(Game game, Player p) {
  if (p.flip7) return 'Flip 7';
  if (p.status == Status.busted) return 'Busted';
  if (p.status == Status.stayed) return 'Stayed';
  if (game.prompt?.pid == p.id) return 'Choosing';
  return game.dealer == p.id ? 'Dealer' : 'Playing';
}

Color _statusColor(String status) => switch (status) {
  'Flip 7' => lime,
  'Busted' => coralSoft,
  'Stayed' || 'Choosing' => mint,
  _ => const Color(0xFF6F7A89),
};

int _roundScore(Game game, Player p) => p.roundScore ?? scoreOf(p, game.brutal);

String _signed(int n) => n > 0 ? '+$n' : '$n';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): controller.hit,
        const SingleActivator(LogicalKeyboardKey.keyS): controller.stay,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= _wideBreakpoint;
                  final narrow = box.maxWidth < _narrowBreakpoint;
                  return Stack(
                    children: [
                      Column(
                        children: [
                          _TopBar(controller: controller, narrow: narrow),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!narrow)
                                  _PlayersPanel(game: game, compact: !wide),
                                Expanded(
                                  child: _Table(
                                    controller: controller,
                                    narrow: narrow,
                                    screenWidth: box.maxWidth,
                                  ),
                                ),
                                if (wide) _FeedPanel(game: game),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (game.phase != Phase.playing)
                        _Summary(controller: controller),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Top bar ----------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.narrow});
  final GameController controller;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final game = controller.game!;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          onTap: controller.toggleFast,
          tooltip: controller.fast ? 'Fast mode is on' : 'Fast mode is off',
          padding: EdgeInsets.zero,
          color: controller.fast ? lime.withValues(alpha: 0.08) : const Color(0x06FFFFFF),
          border: controller.fast ? lime.withValues(alpha: 0.4) : line,
          foreground: controller.fast ? lime : const Color(0xFF9CA6B4),
          child: const SizedBox(width: 40, child: Icon(Icons.bolt)),
        ),
        const SizedBox(width: 8),
        AppButton(
          onTap: () => showRules(context),
          tooltip: 'Rules',
          padding: EdgeInsets.zero,
          color: const Color(0x06FFFFFF),
          border: line,
          foreground: const Color(0xFF9CA6B4),
          child: const SizedBox(width: 40, child: Icon(Icons.style_outlined)),
        ),
        const SizedBox(width: 13),
        AppButton(
          onTap: controller.quit,
          color: const Color(0x06FFFFFF),
          border: line,
          foreground: const Color(0xFFAAB3BF),
          child: const Text('NEW GAME'),
        ),
      ],
    );

    return Container(
      height: narrow ? 70 : 82,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 30),
      decoration: const BoxDecoration(
        color: Color(0xD1060A11),
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Align(alignment: Alignment.centerLeft, child: Brand()),
          if (!narrow)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ROUND ${game.round}${game.brutal ? ' · BRUTAL MODE' : ''}',
                  style: labelStyle(),
                ),
                const SizedBox(height: 5),
                Text(
                  'First to $targetScore wins',
                  style: sans(14, weight: FontWeight.w500),
                ),
              ],
            ),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      ),
    );
  }
}

// ---------- Players panel ----------

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.game,
    required this.player,
    required this.rank,
    required this.highlighted,
    this.compact = false,
  });
  final Game game;
  final Player player;
  final int rank;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(game, player);
    final round = _roundScore(game, player);
    return Container(
      constraints: const BoxConstraints(minHeight: 67),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: highlighted
            ? LinearGradient(
                colors: [mint.withValues(alpha: 0.12), Colors.transparent],
              )
            : null,
        border: Border.all(
          color: highlighted ? mint.withValues(alpha: 0.22) : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (!compact) ...[
            SizedBox(width: 16, child: Text('$rank', style: mono(11, color: dim))),
            const SizedBox(width: 10),
          ],
          Avatar(
            name: player.name,
            color: avatarColor(player.id),
            human: !player.bot,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(13, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(status, style: sans(10, color: _statusColor(status))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${player.total}', style: mono(17)),
              const SizedBox(height: 2),
              Text(
                compact ? _signed(round) : '${_signed(round)} round',
                style: mono(9, color: round > 0 ? mint : const Color(0xFF6F7A89)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayersPanel extends StatelessWidget {
  const _PlayersPanel({required this.game, required this.compact});
  final Game game;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ranked = [...game.players]..sort((a, b) => b.total.compareTo(a.total));
    final leader = ranked.first;
    final lead = leader.total - ranked[1].total;
    return Container(
      width: compact ? 215 : 245,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: 26),
      decoration: const BoxDecoration(
        color: panel,
        border: Border(right: BorderSide(color: line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PLAYERS', style: labelStyle()),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: muted),
                  const SizedBox(width: 5),
                  Text('${game.players.length}', style: labelStyle()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                for (final (i, p) in ranked.indexed)
                  _PlayerRow(
                    game: game,
                    player: p,
                    rank: i + 1,
                    highlighted: game.prompt?.pid == p.id,
                    compact: compact,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0x05FFFFFF),
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Winning score', style: sans(10, color: const Color(0xFF6F7A89))),
                    Text('$targetScore', style: mono(17)),
                  ],
                ),
                const SizedBox(height: 12),
                _Track(value: leader.total / targetScore, color: lime),
                const SizedBox(height: 8),
                Text(
                  lead > 0
                      ? '${leader.name} leads by $lead point${lead == 1 ? '' : 's'}'
                      : 'Tied at ${leader.total}',
                  style: sans(10, color: const Color(0xFF6F7A89)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.value, required this.color, this.endColor});
  final double value;
  final Color color;
  final Color? endColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 4,
        color: const Color(0x12FFFFFF),
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 250),
          widthFactor: value.clamp(0, 1).toDouble(),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, endColor ?? color]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Table ----------

class _Table extends StatelessWidget {
  const _Table({
    required this.controller,
    required this.narrow,
    required this.screenWidth,
  });
  final GameController controller;
  final bool narrow;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final game = controller.game!;
    final focus = controller.focus;
    final humans = game.players.where((p) => !p.bot).length;
    final prompt = game.prompt;
    final humanPrompt = controller.humanPrompt;
    final chooser = prompt == null ? null : game.players[prompt.pid];

    final opponents = [
      for (final p in game.players)
        if (p.id != focus.id)
          _OpponentHand(
            controller: controller,
            player: p,
            compact: narrow || game.players.length > 4,
            targetable:
                humanPrompt is TargetPrompt && humanPrompt.options.contains(p.id),
          ),
    ];

    final String turnText;
    if (game.phase != Phase.playing) {
      turnText = 'ROUND OVER';
    } else if (chooser == null) {
      turnText = 'DEALING';
    } else if (chooser.bot) {
      turnText = '${chooser.name} IS CHOOSING';
    } else {
      turnText = humans == 1 ? 'YOUR TURN' : '${chooser.name}’S TURN';
    }
    final myTurn = chooser != null && !chooser.bot;

    final String handNote;
    if (focus.flip7) {
      handNote = 'FLIP 7!';
    } else if (focus.status == Status.busted) {
      handNote = 'BUSTED';
    } else {
      handNote =
          '${focus.line.length} of 7 numbers'
          '${focus.status == Status.stayed ? ' · stayed' : ''}'
          '${focus.hasZero ? ' · The Zero' : ''}';
    }

    final String message;
    if (humanPrompt is HitStayPrompt) {
      message = humanPrompt.mustHit
          ? 'The Zero is in your hand — you must keep flipping until you Flip 7.'
          : 'Keep flipping or lock in your points.';
    } else {
      message = game.log.last;
    }
    final messageColor = switch (focus.status) {
      Status.busted => coralSoft,
      Status.stayed => mint,
      Status.active => const Color(0xFF7E8998),
    };

    final cards = focus.cards;
    final dense = cards.length > 5;
    final double cardWidth = narrow
        ? (screenWidth * (dense ? 0.14 : 0.2)).clamp(dense ? 46 : 58, dense ? 64 : 90)
        : (screenWidth * (dense ? 0.054 : 0.082)).clamp(dense ? 56 : 78, dense ? 78 : 112);
    final pick = controller.pickPrompt;

    final center = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TurnPill(text: turnText.toUpperCase(), active: myTurn),
        const SizedBox(height: 12),
        Text(
          humans == 1 && !focus.bot
              ? 'ROUND SCORE'
              : '${focus.name.toUpperCase()} · ROUND SCORE',
          style: labelStyle(),
        ),
        Text(
          '${_roundScore(game, focus)}',
          style: mono(narrow ? 46 : 62, spacing: -3),
        ),
        Text(handNote, style: sans(10, color: const Color(0xFF768190))),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: cardWidth / 0.69 + 24),
          child: Center(
            child: cards.isEmpty
                ? _EmptyHand(
                    width: cardWidth,
                    text: focus.status == Status.busted ? 'BUSTED' : 'NO CARDS YET',
                  )
                : Wrap(
                    alignment: WrapAlignment.center,
                    spacing: dense ? 7 : 12,
                    runSpacing: 12,
                    children: [
                      for (final (i, card) in cards.indexed)
                        PlayingCard(
                          key: ValueKey(card.id),
                          card: card,
                          width: cardWidth,
                          index: i,
                          pickable: pick?.options.contains(card.id) ?? false,
                          selected:
                              card.id == controller.chosenCard || card.id == pick?.first,
                          onTap: () => controller.selectCard(card.id),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: messageColor.withValues(alpha: 0.7)),
              ),
              child: Text(
                switch (focus.status) {
                  Status.busted => '!',
                  Status.stayed => '✓',
                  Status.active => 'i',
                },
                style: mono(10, color: messageColor),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message, style: sans(11, color: messageColor))),
          ],
        ),
        _ActionBar(controller: controller),
      ],
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          radius: 0.75,
          colors: [Color(0x4717523D), Color(0x0017523D)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: narrow
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: opponents),
                  )
                : Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: opponents,
                  ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: center,
              ),
            ),
          ),
          _Dock(controller: controller, narrow: narrow),
        ],
      ),
    );
  }
}

class _TurnPill extends StatelessWidget {
  const _TurnPill({required this.text, required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? lime : const Color(0xFF8E98A4);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: active ? lime.withValues(alpha: 0.08) : const Color(0x08FFFFFF),
        border: Border.all(color: active ? lime.withValues(alpha: 0.3) : line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [if (active) const BoxShadow(color: lime, blurRadius: 9)],
            ),
          ),
          const SizedBox(width: 7),
          Text(text, style: mono(9, color: color, spacing: 1.2)),
        ],
      ),
    );
  }
}

class _EmptyHand extends StatelessWidget {
  const _EmptyHand({required this.width, required this.text});
  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / 0.69,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x24FFFFFF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: mono(9, color: dim, spacing: 0.7),
      ),
    );
  }
}

class _OpponentHand extends StatelessWidget {
  const _OpponentHand({
    required this.controller,
    required this.player,
    required this.compact,
    required this.targetable,
  });
  final GameController controller;
  final Player player;
  final bool compact;
  final bool targetable;

  @override
  Widget build(BuildContext context) {
    final game = controller.game!;
    final status = _statusOf(game, player);
    final busted = player.status == Status.busted;
    final acting = game.prompt?.pid == player.id;
    final pick = controller.pickPrompt;
    final cards = player.cards;
    final statusColor = switch (status) {
      'Flip 7' => onLime,
      'Busted' => coralSoft,
      'Stayed' || 'Choosing' => mint,
      _ => amber,
    };

    Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: targetable
            ? lime.withValues(alpha: 0.06)
            : acting
            ? mint.withValues(alpha: 0.07)
            : Colors.transparent,
        border: Border.all(
          color: targetable
              ? lime.withValues(alpha: 0.6)
              : acting
              ? mint.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Avatar(name: player.name, color: avatarColor(player.id), size: 34),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: sans(11, color: const Color(0xFF8E98A4), weight: FontWeight.w500),
              ),
              if (!compact)
                Text(
                  '${cards.length} card${cards.length == 1 ? '' : 's'}',
                  style: sans(9, color: const Color(0xFF65707F)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50, minWidth: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final card in cards)
                  Align(
                    widthFactor: 0.8,
                    child: MiniCard(
                      key: ValueKey(card.id),
                      card: card,
                      faded: busted,
                      pickable: pick?.options.contains(card.id) ?? false,
                      selected:
                          card.id == controller.chosenCard || card.id == pick?.first,
                      onTap: () => controller.selectCard(card.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_roundScore(game, player)} pts',
                style: mono(11, color: const Color(0xFFE9EDF0)),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'Flip 7' ? lime : statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: mono(7, color: statusColor, spacing: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (busted) body = Opacity(opacity: 0.62, child: body);
    if (targetable) {
      body = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => controller.choosePlayer(player.id),
          child: body,
        ),
      );
    }
    return body;
  }
}

// ---------- Action bar ----------

const _pickToken = {
  PickPurpose.steal: 'STEAL',
  PickPurpose.discard: 'DISCARD',
  PickPurpose.swapFirst: 'SWAP',
  PickPurpose.swapSecond: 'SWAP',
};

const _pickText = {
  PickPurpose.steal: 'Select a glowing card to steal.',
  PickPurpose.discard: 'Select a glowing card to discard.',
  PickPurpose.swapFirst: 'Select the first card to swap.',
  PickPurpose.swapSecond: "Now select another player's card to swap it with.",
};

/// The strip under the focused hand: who gets a card, which card to pick,
/// Flip Four progress.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.controller});
  final GameController controller;

  Widget _choice(String label, VoidCallback onTap, {bool revenge = false}) {
    return AppButton(
      onTap: onTap,
      height: 29,
      radius: 6,
      fontSize: 8,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      color: revenge ? coral.withValues(alpha: 0.14) : lime,
      border: revenge ? coral : lime,
      foreground: revenge ? const Color(0xFFFFB1AB) : onLime,
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = controller.game!;
    final prompt = game.prompt;
    if (game.phase != Phase.playing) return const SizedBox.shrink();

    String token;
    String text;
    var highlighted = true;
    List<Widget> trailing = const [];

    if (prompt == null) {
      final flipFour = game.stack.whereType<FlipFourTask>().lastOrNull;
      if (flipFour == null) return const SizedBox.shrink();
      token = 'FLIP FOUR!';
      text =
          '${game.players[flipFour.pid].name} flips ${flipFour.left} more.'
          '${flipFour.held.isEmpty ? '' : ' Set aside until the flips are done:'}';
      trailing = [for (final card in flipFour.held) MiniCard(card: card)];
    } else if (prompt is HitStayPrompt) {
      return const SizedBox.shrink();
    } else {
      final chooser = game.players[prompt.pid];
      String nameOf(int id) =>
          id == chooser.id ? 'MYSELF' : game.players[id].name.toUpperCase();
      token = switch (prompt) {
        TargetPrompt() => prompt.card.label.toUpperCase(),
        PickPrompt() => _pickToken[prompt.purpose]!,
        _ => 'FLIP 7',
      };
      if (chooser.bot) {
        highlighted = false;
        text = '${chooser.name} is deciding…';
      } else {
        switch (prompt) {
          case TargetPrompt():
            text = '${chooser.name}, who gets it?';
            trailing = [
              for (final id in prompt.options)
                _choice(nameOf(id), () => controller.choosePlayer(id)),
            ];
          case PickPrompt():
            final chosen = controller.chosenCard;
            text = '${chooser.name}: ${_pickText[prompt.purpose]}';
            trailing = [
              AppButton(
                onTap: chosen == null ? null : controller.confirmCard,
                height: 29,
                radius: 6,
                fontSize: 8,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                color: lime,
                border: lime,
                foreground: onLime,
                child: Text(
                  chosen == null
                      ? 'CHOOSE A CARD'
                      : prompt.purpose == PickPurpose.swapFirst
                      ? 'NEXT CARD'
                      : 'USE ACTION',
                ),
              ),
            ];
          case BonusPrompt():
            text = '${chooser.name}, take the bonus or take revenge?';
            trailing = [
              _choice('+$flip7Bonus FOR ME', () => controller.choosePlayer(chooser.id)),
              for (final id in prompt.options)
                if (id != chooser.id)
                  _choice(
                    '−$flip7Bonus ${nameOf(id)}',
                    () => controller.choosePlayer(id),
                    revenge: true,
                  ),
            ];
          case HitStayPrompt():
            text = '';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 11),
      constraints: const BoxConstraints(maxWidth: 560, minHeight: 43),
      padding: const EdgeInsets.fromLTRB(10, 6, 7, 6),
      decoration: BoxDecoration(
        color: highlighted ? lime.withValues(alpha: 0.05) : const Color(0x99060A11),
        border: Border.all(color: highlighted ? lime.withValues(alpha: 0.32) : line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 11,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 15, color: lime),
              const SizedBox(width: 5),
              Text(token, style: mono(9, color: lime, spacing: 0.7)),
              const SizedBox(width: 11),
              Flexible(
                child: Text(
                  text,
                  style: sans(
                    10,
                    color: highlighted ? const Color(0xFFC3CAD3) : const Color(0xFF7D8897),
                  ),
                ),
              ),
            ],
          ),
          if (trailing.isNotEmpty)
            Wrap(spacing: 5, runSpacing: 5, children: trailing),
        ],
      ),
    );
  }
}

// ---------- Dock ----------

class _Dock extends StatelessWidget {
  const _Dock({required this.controller, required this.narrow});
  final GameController controller;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final game = controller.game!;
    final focus = controller.focus;
    final risk = focus.status == Status.active
        ? (bustChance(game, focus) * 100).round()
        : 0;

    Widget deckCard(double left, double top, {Widget? child}) => Positioned(
      left: left,
      top: top,
      child: Container(
        width: 47,
        height: 63,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF10261F),
          border: Border.all(color: const Color(0xFF30483F), width: 2),
          borderRadius: BorderRadius.circular(7),
        ),
        child: child,
      ),
    );

    final deck = SizedBox(
      width: 65,
      height: 84,
      child: Stack(
        children: [
          deckCard(0, 0),
          deckCard(3, 2),
          deckCard(7, 4, child: const BrandMark(scale: 0.62)),
          Positioned(
            left: 8,
            bottom: 0,
            child: Text('${game.deck.length} LEFT', style: labelStyle(size: 8)),
          ),
        ],
      ),
    );

    final flip = AppButton.primary(
      onTap: controller.canHit ? controller.hit : null,
      // Phones have no keyboard, so the shortcut hints are dropped when narrow.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt),
            const SizedBox(width: 9),
            const Text('FLIP A CARD'),
            if (!narrow) const KeyHint('F'),
          ],
        ),
      ),
    );
    final stay = AppButton(
      onTap: controller.canStay ? controller.stay : null,
      height: 52,
      radius: 12,
      fontSize: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [const Text('STAY'), if (!narrow) const KeyHint('S')],
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 15 : 40, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xB8060A11),
        border: Border(top: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          deck,
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (narrow)
                  Expanded(child: flip)
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 198),
                    child: flip,
                  ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: narrow ? 78 : 103),
                  child: stay,
                ),
              ],
            ),
          ),
          if (!narrow) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BUST RISK', style: labelStyle(size: 9)),
                      Text('$risk%', style: mono(10, color: const Color(0xFFE6A65E))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Track(
                    value: risk / 100,
                    color: lime,
                    endColor: const Color(0xFFF0A255),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------- Table talk ----------

class _FeedPanel extends StatelessWidget {
  const _FeedPanel({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    // Longest names first so "Player 10" is not mistaken for "Player 1".
    final byName = [...game.players]
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    final lines = game.log.reversed.take(9);
    final leading = RegExp(r'^[^\p{L}\p{N}—]+', unicode: true);

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: const BoxDecoration(
        color: panel,
        border: Border(left: BorderSide(color: line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TABLE TALK', style: labelStyle()),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: coral,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: coral, blurRadius: 8)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final raw in lines)
                  () {
                    final text = raw.replaceFirst(leading, '');
                    final who = byName
                        .where((p) => text.startsWith(p.name))
                        .firstOrNull;
                    final rest = who == null
                        ? text
                        : text.substring(who.name.length).trim();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: who == null
                                  ? const Color(0x14FFFFFF)
                                  : avatarColor(who.id),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              who == null ? '·' : who.name[0].toUpperCase(),
                              style: mono(
                                10,
                                color: const Color(0xFF111722),
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (who != null)
                                  Text(
                                    who.name,
                                    style: sans(
                                      11,
                                      color: const Color(0xFFE8EBEE),
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                Text(
                                  rest,
                                  style: sans(11, color: const Color(0xFF6F7B8A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showRules(context),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.style_outlined,
                      size: 18,
                      color: Color(0xFF8A95A3),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How to play',
                            style: sans(
                              11,
                              color: const Color(0xFFCDD2D8),
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Rules & card guide',
                            style: sans(9, color: const Color(0xFF8A95A3)),
                          ),
                        ],
                      ),
                    ),
                    Text('↗', style: sans(13, color: const Color(0xFF8A95A3))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Round results / game over ----------

class _Summary extends StatelessWidget {
  const _Summary({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final game = controller.game!;
    final over = game.phase == Phase.gameOver;
    final ranked = [...game.players]..sort((a, b) => b.total.compareTo(a.total));
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB804070C),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0E141F),
              border: Border.all(color: const Color(0x1FFFFFFF)),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 80,
                  offset: Offset(0, 30),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  over ? 'GAME OVER' : 'ROUND ${game.round} RESULTS',
                  style: labelStyle(color: lime),
                ),
                const SizedBox(height: 10),
                Text(
                  over ? '${game.players[game.winner!].name} wins!' : 'Scores are in',
                  style: sans(24, weight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (i, p) in ranked.indexed)
                        _PlayerRow(
                          game: game,
                          player: p,
                          rank: i + 1,
                          highlighted: p.id == game.winner,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppButton.primary(
                  onTap: over ? controller.quit : controller.nextRound,
                  child: Text(over ? 'NEW GAME' : 'DEAL ROUND ${game.round + 1}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
