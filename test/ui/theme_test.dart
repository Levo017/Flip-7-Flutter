import 'package:flip7_flutter/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_helpers.dart';

void main() {
  group('initials', () {
    test('uses the first letters of two words', () {
      expect(initials('Player 1'), 'P1');
      expect(initials('  leo   yang '), 'LY');
    });

    test('uses the first two letters of a single word', () {
      expect(initials('Ash'), 'AS');
      expect(initials('x'), 'X');
    });
  });

  test('avatarColor cycles through the palette', () {
    expect(avatarColor(0), avatarColors[0]);
    expect(avatarColor(avatarColors.length + 2), avatarColors[2]);
  });

  group('text styles', () {
    test('mono carries size, colour, weight and spacing', () {
      final style = mono(12, color: lime, weight: FontWeight.w700, spacing: 2);
      expect(style.fontSize, 12);
      expect(style.color, lime);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, 2);
      expect(style.fontFamily, 'monospace');
    });

    test('sans carries size, colour and weight', () {
      final style = sans(14, color: coral, weight: FontWeight.w600);
      expect(style.fontSize, 14);
      expect(style.color, coral);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('labelStyle spaces letters in proportion to size', () {
      expect(labelStyle().color, muted);
      expect(labelStyle(size: 10).letterSpacing, closeTo(1.6, 0.001));
      expect(labelStyle(color: lime, size: 8).color, lime);
    });
  });

  test('buildTheme is dark with the lime accent', () {
    final theme = buildTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, background);
    expect(theme.colorScheme.primary, lime);
  });

  group('AppButton', () {
    testWidgets('calls onTap when pressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(onTap: () => taps++, child: const Text('GO'))),
      );
      await tester.tap(find.text('GO'));
      expect(taps, 1);
    });

    testWidgets('is inert and dimmed when onTap is null', (tester) async {
      await tester.pumpWidget(
        host(const AppButton(onTap: null, child: Text('GO'))),
      );
      await tester.tap(find.text('GO'));
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
      final style = DefaultTextStyle.of(tester.element(find.text('GO'))).style;
      expect(style.color, dim);
    });

    testWidgets('the primary variant is lime with dark text', (tester) async {
      await tester.pumpWidget(
        host(AppButton.primary(onTap: () {}, child: const Text('GO'))),
      );
      expect(tester.widget<Material>(find.byType(Material).last).color, lime);
      final style = DefaultTextStyle.of(tester.element(find.text('GO'))).style;
      expect(style.color, onLime);
      expect(tester.getSize(find.byType(InkWell)).height, 52);
    });

    testWidgets('shrinks to its label unless given a width', (tester) async {
      await tester.pumpWidget(
        host(AppButton(onTap: () {}, child: const Text('GO'))),
      );
      final natural = tester.getSize(find.byType(InkWell)).width;
      expect(natural, lessThan(120));

      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: AppButton(onTap: () {}, child: const Text('GO')),
          ),
        ),
      );
      expect(tester.getSize(find.byType(InkWell)).width, 300);
    });

    testWidgets('shows a tooltip when given one', (tester) async {
      await tester.pumpWidget(
        host(AppButton(onTap: () {}, tooltip: 'Rules', child: const Text('?'))),
      );
      expect(find.byTooltip('Rules'), findsOneWidget);
    });
  });

  testWidgets('KeyHint shows its letter', (tester) async {
    await tester.pumpWidget(host(const KeyHint('F')));
    expect(find.text('F'), findsOneWidget);
  });

  group('Avatar', () {
    testWidgets('shows initials', (tester) async {
      await tester.pumpWidget(host(const Avatar(name: 'Leo Yang', color: mint)));
      expect(find.text('LY'), findsOneWidget);
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('marks human players with a dot', (tester) async {
      await tester.pumpWidget(
        host(const Avatar(name: 'Leo', color: mint, human: true, size: 34)),
      );
      expect(find.byType(Positioned), findsOneWidget);
      expect(tester.getSize(find.byType(Avatar)).width, 34);
    });
  });

  testWidgets('Brand shows the logo and the edition', (tester) async {
    await tester.pumpWidget(host(const Brand(scale: 1.5)));
    expect(find.text('FLIP'), findsOneWidget);
    expect(find.text('SEVEN'), findsOneWidget);
    expect(find.text('WITH A VENGEANCE'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(tester.getSize(find.byType(BrandMark)).width, closeTo(55.5, 0.01));
  });

  testWidgets('AppBackground draws its grid behind the child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AppBackground(child: const Text('hello'))),
    );
    expect(find.text('hello'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBackground),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });
}
