import 'package:flutter/material.dart';

import '../game/game.dart';
import 'rules_dialog.dart';
import 'theme.dart';

const _minPlayers = 2;
const _maxPlayers = 8;

class _Seat {
  _Seat(String name, {required this.bot}) : name = TextEditingController(text: name);
  final TextEditingController name;
  bool bot;
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onStart});
  final void Function(List<PlayerConfig> players, bool brutal) onStart;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _seats = [
    _Seat('Player 1', bot: false),
    _Seat('Ash', bot: true),
    _Seat('Blaze', bot: true),
    _Seat('Cinder', bot: true),
  ];
  bool _brutal = false;

  @override
  void dispose() {
    for (final seat in _seats) {
      seat.name.dispose();
    }
    super.dispose();
  }

  void _start() {
    widget.onStart([
      for (final (i, seat) in _seats.indexed)
        PlayerConfig(
          seat.name.text.trim().isEmpty ? 'Player ${i + 1}' : seat.name.text.trim(),
          bot: seat.bot,
        ),
    ], _brutal);
  }

  Widget _seatRow(int i, _Seat seat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 16, child: Text('${i + 1}', style: mono(11, color: dim))),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: seat.name,
                maxLength: 14,
                style: sans(13, weight: FontWeight.w500),
                cursorColor: lime,
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0x99060A11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: lime),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: AppButton(
              onTap: () => setState(() => seat.bot = !seat.bot),
              padding: EdgeInsets.zero,
              fontSize: 9,
              color: seat.bot ? const Color(0x06FFFFFF) : mint.withValues(alpha: 0.1),
              border: seat.bot ? line : mint.withValues(alpha: 0.4),
              foreground: seat.bot ? const Color(0xFF8E98A4) : mint,
              child: Text(seat.bot ? 'CPU' : 'HUMAN'),
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            onTap: _seats.length <= _minPlayers
                ? null
                : () => setState(() => _seats.removeAt(i).name.dispose()),
            tooltip: 'Remove player',
            padding: EdgeInsets.zero,
            color: const Color(0x06FFFFFF),
            border: line,
            foreground: const Color(0xFF9CA6B4),
            child: const SizedBox(width: 40, child: Icon(Icons.close, size: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Brand(scale: 1.5),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Press your luck. Ruin theirs. First to $targetScore wins.',
                      style: sans(13, color: const Color(0xFF8B95A2)),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: panel,
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('PLAYERS', style: labelStyle()),
                              Text(
                                '${_seats.length} OF $_maxPlayers',
                                style: labelStyle(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          for (final (i, seat) in _seats.indexed) _seatRow(i, seat),
                          AppButton(
                            onTap: _seats.length >= _maxPlayers
                                ? null
                                : () => setState(
                                    () => _seats.add(
                                      _Seat('Player ${_seats.length + 1}', bot: true),
                                    ),
                                  ),
                            fontSize: 9,
                            color: const Color(0x06FFFFFF),
                            border: line,
                            foreground: const Color(0xFF8E98A4),
                            child: const Text('+ ADD PLAYER'),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _brutal = !_brutal),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _brutal ? coral.withValues(alpha: 0.07) : null,
                                border: Border.all(
                                  color: _brutal ? coral.withValues(alpha: 0.45) : line,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _brutal
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    size: 18,
                                    color: _brutal ? coral : dim,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'BRUTAL MODE',
                                          style: labelStyle(color: coral),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Scores can go negative, modifiers can hit busted players, and a Flip 7 can cost someone 15 instead.',
                                          style: sans(
                                            11,
                                            color: const Color(0xFF7D8897),
                                          ).copyWith(height: 1.45),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.primary(
                            onTap: _start,
                            child: const Text('START GAME'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AppButton(
                          onTap: () => showRules(context),
                          height: 52,
                          radius: 12,
                          fontSize: 12,
                          child: const Text('HOW TO PLAY'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
