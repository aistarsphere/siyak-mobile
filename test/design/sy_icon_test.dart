import 'package:context_game/core/design/organic/sy_icon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the icon seam: RTL mirroring, semantics, and the fact that the app
/// depends on [SyIcon] rather than on Lucide directly.
Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    Directionality(
      textDirection: direction,
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF201E1D)),
        child: child,
      ),
    );

void main() {
  group('RTL mirroring', () {
    test('directional icons mirror, meaning-bearing ones do not', () {
      const back = SyIcon(icon: SyIcons.back);
      expect(back.mirrorsIn(TextDirection.rtl), isTrue);
      expect(back.mirrorsIn(TextDirection.ltr), isFalse);

      // A tick and a lamp must never flip — that is the classic mirroring bug.
      for (final icon in [SyIcons.solved, SyIcons.hint, SyIcons.home]) {
        expect(
          SyIcon(icon: icon).mirrorsIn(TextDirection.rtl),
          isFalse,
          reason: 'non-directional icon must not flip',
        );
      }
    });

    test('submit shares the forward glyph, so it mirrors too', () {
      expect(SyIcons.submit, SyIcons.forward);
      expect(
        const SyIcon(icon: SyIcons.submit).mirrorsIn(TextDirection.rtl),
        isTrue,
      );
    });

    test('an explicit override beats the default classification', () {
      expect(
        const SyIcon(
          icon: SyIcons.back,
          mirror: false,
        ).mirrorsIn(TextDirection.rtl),
        isFalse,
      );
      expect(
        const SyIcon(
          icon: SyIcons.solved,
          mirror: true,
        ).mirrorsIn(TextDirection.rtl),
        isTrue,
      );
    });

    testWidgets('mirroring applies a flip in the tree only under RTL', (
      t,
    ) async {
      await t.pumpWidget(_host(const SyIcon(icon: SyIcons.back)));
      expect(find.byType(Transform), findsNothing);

      await t.pumpWidget(
        _host(const SyIcon(icon: SyIcons.back), direction: TextDirection.rtl),
      );
      expect(find.byType(Transform), findsOneWidget);
    });

    testWidgets('a non-directional icon is not flipped even in RTL', (t) async {
      await t.pumpWidget(
        _host(const SyIcon(icon: SyIcons.hint), direction: TextDirection.rtl),
      );
      expect(find.byType(Transform), findsNothing);
    });
  });

  group('semantics', () {
    testWidgets('a labelled icon announces; a decorative one is excluded', (
      t,
    ) async {
      await t.pumpWidget(
        _host(const SyIcon(icon: SyIcons.hint, semanticLabel: 'Hints')),
      );
      expect(find.bySemanticsLabel('Hints'), findsOneWidget);

      await t.pumpWidget(_host(const SyIcon.decorative(icon: SyIcons.hint)));
      expect(find.bySemanticsLabel('Hints'), findsNothing);
      // `Icon` adds its own ExcludeSemantics when unlabelled, so there are two;
      // what matters is that nothing is announced.
      expect(find.byType(ExcludeSemantics), findsAtLeastNWidgets(1));
    });

    testWidgets('the label survives mirroring', (t) async {
      await t.pumpWidget(
        _host(
          const SyIcon(icon: SyIcons.back, semanticLabel: 'Back'),
          direction: TextDirection.rtl,
        ),
      );
      expect(find.byType(Transform), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });

    testWidgets('the default constructor is decorative unless told otherwise', (
      t,
    ) async {
      await t.pumpWidget(_host(const SyIcon(icon: SyIcons.home)));
      expect(find.byType(ExcludeSemantics), findsAtLeastNWidgets(1));
      expect(
        t.getSemantics(find.byType(SyIcon)).label,
        isEmpty,
        reason: 'an unlabelled icon must announce nothing',
      );
    });
  });

  group('stroke width — the documented deviation', () {
    test('defaults to the design value', () {
      expect(SyIcon.designStrokeWidth, 2.75);
      expect(const SyIcon(icon: SyIcons.home).strokeWidth, 2.75);
    });

    test('the backend is known not to honour it', () {
      // Pins the deviation so it is a recorded fact rather than a forgotten one.
      // Flip this to true only when the backend renders SVG.
      expect(SyIcon.backendHonoursStrokeWidth, isFalse);
    });
  });

  group('the seam holds', () {
    test('the vocabulary is named by meaning, and every entry resolves', () {
      final icons = <String, IconData>{
        'back': SyIcons.back,
        'forward': SyIcons.forward,
        'close': SyIcons.close,
        'chevronDown': SyIcons.chevronDown,
        'chevronUp': SyIcons.chevronUp,
        'home': SyIcons.home,
        'leaderboard': SyIcons.leaderboard,
        'profile': SyIcons.profile,
        'settings': SyIcons.settings,
        'hint': SyIcons.hint,
        'submit': SyIcons.submit,
        'language': SyIcons.language,
        'solved': SyIcons.solved,
        'thread': SyIcons.thread,
      };
      for (final e in icons.entries) {
        expect(e.value.fontFamily, 'Lucide', reason: e.key);
        expect(
          e.value.fontPackage,
          'lucide_icons_flutter',
          reason: '${e.key} must come from Lucide, not a Material substitute',
        );
      }
    });

    testWidgets('the themed variant inherits the surrounding text colour', (
      t,
    ) async {
      const expected = Color(0xFF8C491A);
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(color: expected),
            child: const SyThemedIcon(icon: SyIcons.hint),
          ),
        ),
      );
      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.color, expected);
    });

    test('sizes come from the prototype', () {
      expect(SyIconSize.md, 19.0);
      expect(SyIconSize.tapTarget, 38.0);
      expect(SyIconSize.sm, lessThan(SyIconSize.md));
      expect(SyIconSize.lg, greaterThan(SyIconSize.md));
      // The tap target must clear the 44dp guidance once padding is added by the
      // pressable that hosts it; 38 is the visual circle, not the hit area.
      expect(SyIconSize.tapTarget, greaterThan(SyIconSize.lg));
    });
  });
}
