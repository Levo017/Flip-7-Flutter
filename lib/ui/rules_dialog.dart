import 'package:flutter/material.dart';

import 'theme.dart';

const _sections = <(String, List<String>)>[
  (
    'The basics',
    [
      'Race to 200 points. Each round everyone is dealt one face-up card, then players take turns choosing to Hit (flip another card) or Stay (lock in their cards).',
      'Flip a number you already have and you bust — zero for the round. Collect 7 number cards to Flip 7: the round ends on the spot and you score +15.',
    ],
  ),
  (
    'The deck (108 cards)',
    [
      'Twelve 13s, twelve 12s, eleven 11s, ten 10s, nine 9s, eight 8s, six 7s, six 6s, five 5s … down to one 1 — plus three special numbers, six modifiers and ten actions.',
    ],
  ),
  (
    'Special numbers',
    [
      '• The Zero — your round is worth 0 unless you Flip 7, and you must keep hitting. It counts as one of your seven.',
      "• Unlucky 7 — discard all your other number and modifier cards and keep just the 7. You can't bust when you flip it.",
      '• Lucky 13 — you may hold one more 13. Both score and both count toward Flip 7; a third 13 busts you.',
      'These effects only apply to whoever holds the card — they can be stolen or swapped away.',
    ],
  ),
  (
    'Modifiers (−2, −4, −6, −8, −10, ÷2)',
    [
      "Whoever flips one puts it on any player who hasn't busted (themself included, and they must keep it if nobody else is left). ÷2 halves the number total, rounded down, before minus cards are subtracted. A round score can't drop below 0.",
    ],
  ),
  (
    'Actions',
    [
      "Whoever flips one plays it on any player who hasn't busted, including players who stayed.",
      '• Just One More! — that player takes the next card, then must stay.',
      '• Flip Four! — that player takes four cards one at a time, stopping on a bust or Flip 7. Actions and modifiers among them resolve afterwards, in order.',
      '• Steal — that player takes any face-up card from another player.',
      '• Swap — that player exchanges any two face-up cards belonging to different players. Yes, this can bust people.',
      '• Discard — that player loses one card; whoever played the action picks which.',
      'An action with no valid target is discarded.',
    ],
  ),
  (
    'Scoring',
    [
      'Add your numbers → apply ÷2 → subtract minus cards → floor at 0 → add 15 for a Flip 7.',
    ],
  ),
  (
    'Brutal Mode',
    [
      'Round scores can go negative, modifiers can be dumped on busted players, and a Flip 7 lets you either take +15 or give another player −15.',
    ],
  ),
];

Future<void> showRules(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xB804070C),
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFF0E141F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x1FFFFFFF)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('RULES & CARD GUIDE', style: labelStyle(color: lime)),
              const SizedBox(height: 10),
              Text('How to play', style: sans(24, weight: FontWeight.w600)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (title, paragraphs) in _sections) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          title.toUpperCase(),
                          style: labelStyle(color: lime),
                        ),
                      ),
                      for (final paragraph in paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            paragraph,
                            style: sans(
                              13,
                              color: const Color(0xFFAAB3BF),
                            ).copyWith(height: 1.5),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppButton.primary(
                onTap: () => Navigator.of(context).pop(),
                child: const Text('GOT IT'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
