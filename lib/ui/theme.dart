import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const lime = Color(0xFFD8FF5F);
const mint = Color(0xFF6CD8A7);
const coral = Color(0xFFEF655D);
const coralSoft = Color(0xFFEF817B);
const amber = Color(0xFFF2B965);
const violet = Color(0xFF98A1FF);
const background = Color(0xFF080D16);
const panel = Color(0xCC101622);
const line = Color(0x14FFFFFF);
const textColor = Color(0xFFF4F6F2);
const muted = Color(0xFF737E8E);
const dim = Color(0xFF596475);
const cream = Color(0xFFE9EBDF);
const ink = Color(0xFF121820);
const onLime = Color(0xFF11170E);

const avatarColors = [
  mint,
  coral,
  Color(0xFFF5B84F),
  violet,
  Color(0xFF5FC8F0),
  Color(0xFFF08FD0),
  lime,
  Color(0xFFC9A5FF),
];

Color avatarColor(int playerId) => avatarColors[playerId % avatarColors.length];

String initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  final text = words.length > 1
      ? words[0][0] + words[1][0]
      : name.substring(0, name.length < 2 ? name.length : 2);
  return text.toUpperCase();
}

/// Whether to fetch DM Mono and Space Grotesk at runtime. Tests turn this off
/// so that building a widget never starts a network request.
bool downloadFonts = true;

TextStyle mono(
  double size, {
  Color color = textColor,
  FontWeight weight = FontWeight.w500,
  double spacing = 0,
}) {
  final style = TextStyle(
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: spacing,
    height: 1.1,
  );
  return downloadFonts
      ? GoogleFonts.dmMono(textStyle: style)
      : style.copyWith(fontFamily: 'monospace');
}

TextStyle sans(
  double size, {
  Color color = textColor,
  FontWeight weight = FontWeight.w400,
}) {
  final style = TextStyle(fontSize: size, color: color, fontWeight: weight);
  return downloadFonts ? GoogleFonts.spaceGrotesk(textStyle: style) : style;
}

/// Small all-caps label used for panel titles and eyebrows.
TextStyle labelStyle({Color color = muted, double size = 10}) =>
    mono(size, color: color, spacing: size * 0.16);

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    fontFamily: downloadFonts ? GoogleFonts.spaceGrotesk().fontFamily : null,
    colorScheme: const ColorScheme.dark(primary: lime, surface: background),
  );
}

/// The grid-and-glow backdrop behind every screen.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.16),
          radius: 0.7,
          colors: [Color(0x33256348), Color(0x00256348)],
        ),
      ),
      child: CustomPaint(painter: _GridPainter(), child: child),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x04FFFFFF);
    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The lime "7" tile from the logo; also sits on the deck.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.scale = 1});
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.087,
      child: Container(
        width: 37 * scale,
        height: 43 * scale,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lime,
          border: Border.all(color: const Color(0x99FFFFFF), width: 2 * scale),
          borderRadius: BorderRadius.circular(6 * scale),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF29471D),
              offset: Offset(3 * scale, 3 * scale),
            ),
          ],
        ),
        child: Text('7', style: mono(23 * scale, color: const Color(0xFF0B1018))),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.scale = 1});
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(scale: scale),
        SizedBox(width: 12 * scale),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FLIP',
              style: sans(
                13 * scale,
                color: const Color(0xFFB2BAC4),
                weight: FontWeight.w500,
              ).copyWith(letterSpacing: 3.6 * scale, height: 1),
            ),
            Text(
              'SEVEN',
              style: sans(
                23 * scale,
                color: lime,
                weight: FontWeight.w700,
              ).copyWith(letterSpacing: -0.9 * scale, height: 1),
            ),
            SizedBox(height: 3 * scale),
            Text(
              'WITH A VENGEANCE',
              style: mono(7 * scale, color: coral, spacing: 1.4 * scale),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rounded rectangular button used throughout; pass a null [onTap] to disable.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = const Color(0x0DFFFFFF),
    this.foreground = const Color(0xFFD6DBE1),
    this.border = const Color(0x21FFFFFF),
    this.height = 40,
    this.radius = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.fontSize = 10,
    this.tooltip,
  });

  /// The lime call-to-action variant.
  const AppButton.primary({
    super.key,
    required this.child,
    required this.onTap,
    this.height = 52,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.fontSize = 12,
    this.tooltip,
  }) : color = lime,
       foreground = onLime,
       border = lime;

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color foreground;
  final Color border;
  final double height;
  final double radius;
  final EdgeInsets padding;
  final double fontSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? foreground : dim;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: enabled ? border : line),
    );
    Widget button = Material(
      color: enabled ? color : const Color(0x0AFFFFFF),
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Container(
          height: height,
          padding: padding,
          // Shrink-wraps the label unless the parent gives the button a width.
          child: Center(
            widthFactor: 1,
            child: IconTheme(
            data: IconThemeData(color: fg, size: fontSize + 8),
            child: DefaultTextStyle(
              style: mono(
                fontSize,
                color: fg,
                weight: FontWeight.w600,
                spacing: fontSize * 0.06,
              ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}

/// Keyboard hint chip shown inside the Flip and Stay buttons.
class KeyHint extends StatelessWidget {
  const KeyHint(this.letter, {super.key});
  final String letter;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? dim;
    return Container(
      margin: const EdgeInsets.only(left: 9),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(letter, style: mono(8, color: color)),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 38,
    this.human = false,
  });
  final String name;
  final Color color;
  final double size;
  final bool human;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFF111722), color, 0.24),
            border: Border.all(color: color.withValues(alpha: 0.46)),
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Text(initials(name), style: mono(size * 0.29, color: color)),
        ),
        if (human)
          Positioned(
            right: -3,
            bottom: -2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: mint,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF14201E), width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
