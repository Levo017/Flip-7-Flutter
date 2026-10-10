import 'package:flutter/material.dart';

import '../game/cards.dart';
import 'theme.dart';

const _rotations = [-5.0, 2.0, -1.0, 4.0, -3.0, 3.0];

/// Colours and text for a card face.
class _Face {
  const _Face(this.value, {this.caption, this.color = cream, this.fg = ink, this.border});
  final String value;
  final String? caption;
  final Color color;
  final Color fg;
  final Color? border;

  factory _Face.of(GameCard card) {
    switch (card.kind) {
      case CardKind.action:
        return _Face(
          '⚡',
          caption: card.label,
          color: violet,
          fg: const Color(0xFF111830),
          border: const Color(0xFFDFE2FF),
        );
      case CardKind.modifier:
        return _Face(
          card.label,
          caption: 'MODIFIER',
          color: const Color(0xFFB93A33),
          fg: const Color(0xFFFFF1EA),
          border: const Color(0xFFF6A59F),
        );
      case CardKind.number:
        return switch (card.special) {
          Special.zero => const _Face(
            '0',
            caption: 'THE ZERO',
            color: Color(0xFF0D121B),
            fg: textColor,
            border: Color(0xFFDFE3D8),
          ),
          Special.unlucky7 => const _Face(
            '7',
            caption: 'UNLUCKY',
            color: Color(0xFF0D121B),
            fg: coral,
            border: coral,
          ),
          Special.lucky13 => const _Face('13', caption: 'LUCKY', color: lime),
          null => _Face('${card.value}'),
        };
    }
  }
}

/// A large card in the focused hand.
class PlayingCard extends StatelessWidget {
  const PlayingCard({
    super.key,
    required this.card,
    required this.width,
    this.index = 0,
    this.pickable = false,
    this.selected = false,
    this.onTap,
  });

  final GameCard card;
  final double width;

  /// Position in the row; gives the card its slight tilt.
  final int index;
  final bool pickable;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final face = _Face.of(card);
    final plain = face.caption == null;
    final borderColor = selected
        ? Colors.white
        : pickable
        ? lime
        : face.border ?? const Color(0xFFFBFCF4);
    final corner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          face.value,
          style: mono(width * 0.12, color: face.fg, weight: FontWeight.w600),
        ),
        if (plain)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: face.fg, shape: BoxShape.circle),
          ),
      ],
    );

    Widget body = Container(
      width: width,
      height: width / 0.69,
      decoration: BoxDecoration(
        color: face.color,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (selected)
            const BoxShadow(color: lime, spreadRadius: 4)
          else if (pickable)
            BoxShadow(color: lime.withValues(alpha: 0.3), spreadRadius: 3),
          const BoxShadow(
            color: Color(0x61000000),
            blurRadius: 25,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (plain)
              Transform.rotate(
                angle: -0.66,
                child: OverflowBox(
                  maxWidth: width * 1.6,
                  child: Container(
                    width: width * 1.6,
                    height: width * 0.3,
                    color: lime.withValues(alpha: 0.65),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: CustomPaint(painter: _StripePainter(face.fg)),
              ),
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: face.fg.withValues(alpha: 0.14)),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            Positioned(top: width * 0.09, left: width * 0.1, child: corner),
            Positioned(
              bottom: width * 0.09,
              right: width * 0.1,
              child: RotatedBox(quarterTurns: 2, child: corner),
            ),
            Text(
              face.value,
              style: mono(
                width * (card.kind == CardKind.modifier ? 0.36 : 0.44),
                color: face.fg,
                weight: FontWeight.w700,
                spacing: -width * 0.03,
              ),
            ),
            if (!plain)
              Positioned(
                bottom: width * 0.3,
                left: width * 0.1,
                right: width * 0.1,
                child: Text(
                  face.caption!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: mono(
                    width * 0.075,
                    color: face.fg,
                    weight: FontWeight.w600,
                    spacing: width * 0.008,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    body = AnimatedSlide(
      duration: const Duration(milliseconds: 150),
      offset: Offset(0, selected ? -0.08 : 0),
      child: Transform.rotate(
        angle: selected ? 0 : _rotations[index % _rotations.length] * 0.01745,
        child: body,
      ),
    );

    if (pickable) {
      body = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: body),
      );
    }
    return _DealIn(child: body);
  }
}

/// A small card in an opponent's row or the action bar.
class MiniCard extends StatelessWidget {
  const MiniCard({
    super.key,
    required this.card,
    this.pickable = false,
    this.selected = false,
    this.faded = false,
    this.onTap,
  });

  final GameCard card;
  final bool pickable;
  final bool selected;
  final bool faded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final face = _Face.of(card);
    Widget body = AnimatedSlide(
      duration: const Duration(milliseconds: 150),
      offset: Offset(0, selected ? -0.17 : 0),
      child: Container(
        width: 30,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: face.color,
          border: Border.all(
            color: selected
                ? Colors.white
                : pickable
                ? lime
                : face.border ?? const Color(0xFF617068),
          ),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            if (selected)
              const BoxShadow(color: lime, spreadRadius: 3)
            else if (pickable)
              BoxShadow(color: lime.withValues(alpha: 0.28), spreadRadius: 2),
            const BoxShadow(
              color: Color(0x47000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          face.value,
          style:
              mono(
                card.kind == CardKind.modifier ? 11 : 12,
                color: face.fg,
                weight: FontWeight.w600,
                spacing: -0.5,
              ).copyWith(
                decoration: faded ? TextDecoration.lineThrough : null,
                decorationColor: face.fg,
              ),
        ),
      ),
    );
    if (faded) body = Opacity(opacity: 0.52, child: body);
    if (pickable) {
      body = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: body),
      );
    }
    return Tooltip(message: card.label, child: body);
  }
}

/// Fades and drops a card in when it first appears.
class _DealIn extends StatelessWidget {
  const _DealIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, -22 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Faint diagonal stripes on every card that is not a plain number.
class _StripePainter extends CustomPainter {
  const _StripePainter(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.06)
      ..strokeWidth = 2;
    for (double x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * 0.84, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => oldDelegate.ink != ink;
}
