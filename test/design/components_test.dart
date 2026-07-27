import 'package:context_game/core/design/siyaq_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.dark,
  String lang = 'ar',
  double textScale = 1.0,
}) {
  final script = SiyaqTypography.scriptForLocale(lang);
  return MaterialApp(
    theme: SiyaqThemeData.of(brightness, script: script),
    locale: Locale(lang),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('SiyaqButton · behaviour', () {
    testWidgets('fires onPressed when enabled', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(SiyaqButton(label: 'Go', onPressed: () => taps++)),
      );
      await t.tap(find.byType(SiyaqButton));
      expect(taps, 1);
    });

    testWidgets('does not fire when disabled (null callback)', (t) async {
      await t.pumpWidget(_host(const SiyaqButton(label: 'Go')));
      await t.tap(find.byType(SiyaqButton), warnIfMissed: false);
      await t.pump();
      // No exception and no state change is the assertion; a disabled control
      // must simply absorb the tap.
      expect(_takeError(), isNull);
    });

    testWidgets('does not fire while loading', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(SiyaqButton(label: 'Go', loading: true, onPressed: () => taps++)),
      );
      await t.tap(find.byType(SiyaqButton), warnIfMissed: false);
      await t.pump();
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('activates via keyboard (Space)', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(SiyaqButton(label: 'Go', onPressed: () => taps++)),
      );
      // Move focus onto the button, then activate without a pointer.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(taps, 1, reason: 'must be operable without a pointer');
    });

    testWidgets('exposes button semantics with label and enabled state', (
      t,
    ) async {
      await t.pumpWidget(
        _host(SiyaqButton(label: 'Start Playing', onPressed: () {})),
      );
      checkSemantics(
        t,
        find.byType(SiyaqButton),
        isSemantics(
          label: 'Start Playing',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('semantics reports disabled', (t) async {
      await t.pumpWidget(_host(const SiyaqButton(label: 'Start')));
      checkSemantics(
        t,
        find.byType(SiyaqButton),
        isSemantics(
          label: 'Start',
          isButton: true,
          isEnabled: false,
          hasEnabledState: true,
        ),
      );
    });

    testWidgets('every type × size renders in both themes without overflow', (
      t,
    ) async {
      for (final brightness in Brightness.values) {
        for (final type in SiyaqButtonType.values) {
          for (final size in SiyaqButtonSize.values) {
            await t.pumpWidget(
              _host(
                SizedBox(
                  width: 300,
                  child: SiyaqButton(
                    label: 'اختبار Test',
                    type: type,
                    size: size,
                    icon: SiyaqIcons.hint,
                    onPressed: () {},
                  ),
                ),
                brightness: brightness,
              ),
            );
            await t.pump();
            expect(
              _takeError(),
              isNull,
              reason: '$brightness/$type/$size failed',
            );
          }
        }
      }
    });

    testWidgets('survives text scale 2.0 in a 320px-wide column', (t) async {
      await t.pumpWidget(
        _host(
          SizedBox(
            width: 320 - 32,
            child: SiyaqButton(
              label: 'زر بعنوان طويل جدًا للتحقق من الالتفاف',
              icon: SiyaqIcons.hint,
              trailingIcon: SiyaqIcons.trendUp,
              fullWidth: true,
              onPressed: () {},
            ),
          ),
          textScale: 2.0,
        ),
      );
      await t.pump();
      expect(_takeError(), isNull, reason: 'must wrap, not clip');
    });

    testWidgets('grows beyond its minimum height at large text scale', (
      t,
    ) async {
      Future<double> heightAt(double scale) async {
        await t.pumpWidget(
          _host(
            SizedBox(
              width: 260,
              child: SiyaqButton(
                label: 'A longer button label here',
                fullWidth: true,
                onPressed: () {},
              ),
            ),
            textScale: scale,
          ),
        );
        await t.pump();
        return t.getSize(find.byType(SiyaqButton)).height;
      }

      final base = await heightAt(1.0);
      final scaled = await heightAt(2.0);
      expect(base, greaterThanOrEqualTo(SiyaqButtonSize.large.minHeight));
      expect(
        scaled,
        greaterThan(base),
        reason: 'minHeight must be a floor, not a fixed height',
      );
    });

    testWidgets('foreground meets AA on its own fill for every type', (
      t,
    ) async {
      for (final brightness in Brightness.values) {
        final c = SiyaqColors.of(brightness);
        final pairs = <String, (Color, Color)>{
          'primary': (c.onAction, c.primary),
          'secondary': (c.onActionSecondary, c.actionSecondary),
          'destructive': (c.onActionDestructive, c.actionDestructive),
        };
        pairs.forEach((name, p) {
          expect(
            _contrast(p.$1, p.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness $name button label',
          );
        });
      }
    });

    testWidgets('accent override derives a contrast-safe label colour', (
      t,
    ) async {
      // Covers the old `SiyagPrimaryButton(color:)` migration path: 9 call sites
      // pass a semantic fill (success/info) or a brand colour. The label must be
      // AA-legible on whatever fill is supplied, without the caller choosing it.
      final c = SiyaqColors.dark;
      for (final fill in [
        c.success,
        c.info,
        c.warning,
        c.gameWeekly,
        const Color(0xFF1B1D22), // Apple sign-in black
      ]) {
        await t.pumpWidget(
          _host(SiyaqButton(label: 'Go', accent: fill, onPressed: () {})),
        );
        await t.pump();
        final style = t.widget<Text>(find.text('Go')).style!;
        expect(
          _contrast(style.color!, fill),
          greaterThanOrEqualTo(4.5),
          reason: 'accent fill $fill must get an AA-legible label',
        );
      }
    });
  });

  group('SiyaqIconButton', () {
    testWidgets('requires a semantic label and announces it', (t) async {
      await t.pumpWidget(
        _host(
          SiyaqIconButton(
            icon: SiyaqIcons.close,
            semanticLabel: 'Close dialog',
            onPressed: () {},
          ),
        ),
      );
      checkSemantics(
        t,
        find.byType(SiyaqIconButton),
        isSemantics(
          label: 'Close dialog',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('a 32px button still gets a 44px hit target', (t) async {
      await t.pumpWidget(
        _host(
          SiyaqIconButton(
            icon: SiyaqIcons.hint,
            semanticLabel: 'Hint',
            size: SiyaqIconButtonSize.small,
            onPressed: () {},
          ),
        ),
      );
      final size = t.getSize(find.byType(SiyaqIconButton));
      expect(size.width, greaterThanOrEqualTo(SiyaqSpacing.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(SiyaqSpacing.minTouchTarget));
    });
  });

  group('SiyaqSurface', () {
    testWidgets('is inert without onTap and interactive with it', (t) async {
      await t.pumpWidget(_host(const SiyaqSurface(child: Text('static'))));
      expect(find.byType(SiyaqPressable), findsNothing);

      var taps = 0;
      await t.pumpWidget(
        _host(
          SiyaqSurface(
            onTap: () => taps++,
            semanticLabel: 'Card',
            child: const Text('tappable'),
          ),
        ),
      );
      expect(find.byType(SiyaqPressable), findsOneWidget);
      await t.tap(find.byType(SiyaqSurface));
      expect(taps, 1);
    });

    testWidgets('disabled surface blocks taps', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(
          SiyaqSurface(
            disabled: true,
            onTap: () => taps++,
            child: const Text('x'),
          ),
        ),
      );
      await t.tap(find.byType(SiyaqSurface), warnIfMissed: false);
      await t.pump();
      expect(taps, 0);
    });

    testWidgets('every variant renders in both themes', (t) async {
      for (final brightness in Brightness.values) {
        for (final v in SiyaqSurfaceVariant.values) {
          await t.pumpWidget(
            _host(
              SiyaqSurface(variant: v, child: const Text('x')),
              brightness: brightness,
            ),
          );
          await t.pump();
          expect(_takeError(), isNull, reason: '$brightness/$v');
        }
      }
    });
  });

  group('SiyaqText', () {
    testWidgets('resolves the role metrics and theme colour', (t) async {
      await t.pumpWidget(
        _host(const SiyaqText('مرحبا', role: SiyaqTextRole.headingMedium)),
      );
      final style = t.widget<Text>(find.text('مرحبا')).style!;
      expect(style.fontSize, SiyaqTextRole.headingMedium.size);
      expect(style.fontFamily, SiyaqFonts.arabic);
      expect(style.color, SiyaqColors.dark.textPrimary);
      // Arabic: looser leading, no tracking.
      expect(style.height, SiyaqTextRole.headingMedium.arabicHeight);
      expect(style.letterSpacing, isNull);
    });

    testWidgets('English uses the Latin family and Figma tracking', (t) async {
      await t.pumpWidget(
        _host(
          const SiyaqText('Hello', role: SiyaqTextRole.labelSmall),
          lang: 'en',
        ),
      );
      final style = t.widget<Text>(find.text('Hello')).style!;
      expect(style.fontFamily, SiyaqFonts.latin);
      expect(style.letterSpacing, SiyaqTextRole.labelSmall.latinTracking);
    });

    testWidgets('declares fallbacks so mixed-script text never tofus', (
      t,
    ) async {
      await t.pumpWidget(_host(const SiyaqText('Siyaq سياق')));
      final style = t.widget<Text>(find.text('Siyaq سياق')).style!;
      expect(style.fontFamilyFallback, isNotEmpty);
      expect(style.fontFamilyFallback, contains(SiyaqFonts.latin));
    });

    testWidgets('numeric constructor uses the mono family', (t) async {
      await t.pumpWidget(_host(const SiyaqText.numeric('#14')));
      expect(
        t.widget<Text>(find.text('#14')).style!.fontFamily,
        SiyaqFonts.mono,
      );
    });
  });

  group('SiyaqIcon', () {
    testWidgets('meaningful icon is announced; decorative is hidden', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SiyaqIcon(SiyaqIcons.hot, semanticLabel: 'Hot'),
              SiyaqIcon.decorative(SiyaqIcons.trendUp),
            ],
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Hot'),
        findsOneWidget,
        reason: 'meaningful icons must be announced',
      );
      // The decorative one contributes no semantics node at all.
      expect(find.bySemanticsLabel('trendUp'), findsNothing);
    });
  });

  group('SiyaqDivider', () {
    testWidgets('renders plain and labelled forms in both directions', (
      t,
    ) async {
      for (final lang in ['ar', 'en']) {
        await t.pumpWidget(
          _host(
            const Column(
              children: [SiyaqDivider(), SiyaqDivider.labelled('OR')],
            ),
            lang: lang,
          ),
        );
        await t.pump();
        expect(_takeError(), isNull, reason: lang);
        expect(find.text('OR'), findsOneWidget);
      }
    });
  });
}

Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

/// Asserts against [f]'s semantics node, disposing the handle immediately —
/// leaving it open fails the test with "A SemanticsHandle was active".
void checkSemantics(WidgetTester t, Finder f, Matcher matcher) {
  final handle = t.ensureSemantics();
  try {
    expect(t.getSemantics(f), matcher);
  } finally {
    handle.dispose();
  }
}
