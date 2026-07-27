import 'package:context_game/core/design/gallery/design_system_gallery.dart';
import 'package:context_game/core/design/gallery/gallery_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host() => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: const DesignSystemGallery(),
);

/// The States page hosts an indeterminate progress indicator, so the tree never
/// reaches quiescence. Pump a few fixed frames instead of `pumpAndSettle`.
Future<void> _frames(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 32));
  }
}

/// Any build/layout/paint failure is captured by the binding; draining it lets a
/// failure name the axis that broke.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

Future<void> _select(WidgetTester t, String label) async {
  await t.tap(find.text(label).first, warnIfMissed: false);
  await _frames(t);
  expect(_takeError(), isNull, reason: 'rendering failed after "$label"');
}

void main() {
  testWidgets('renders every page across every axis', (t) async {
    t.view.physicalSize = const Size(2600, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_host());
    await _frames(t);
    expect(_takeError(), isNull);

    // Default axes already render Light and Dark simultaneously.
    expect(find.text('LIGHT · AR · RTL'), findsOneWidget);
    expect(find.text('DARK · AR · RTL'), findsOneWidget);

    for (final page in ['Type', 'Layout', 'States', 'Colour']) {
      await _select(t, page);
    }
    for (final m in GalleryThemeMode.values) {
      await _select(t, m.label);
    }
    for (final l in GalleryLanguage.values) {
      await _select(t, l.label);
    }
    for (final s in kGalleryTextScales) {
      await _select(t, s.$1);
    }
    for (final v in GalleryViewport.values) {
      await _select(t, v.label);
    }
  });

  testWidgets('renders AR+EN × Light+Dark in ONE tree (4 panes)', (t) async {
    t.view.physicalSize = const Size(3200, 1800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_host());
    await _frames(t);
    await t.tap(find.text('AR + EN').first);
    await _frames(t);

    // The capability the context-token refactor unlocked: four independent
    // theme × direction combinations coexisting in a single widget tree.
    expect(find.text('LIGHT · AR · RTL'), findsOneWidget);
    expect(find.text('LIGHT · EN · LTR'), findsOneWidget);
    expect(find.text('DARK · AR · RTL'), findsOneWidget);
    expect(find.text('DARK · EN · LTR'), findsOneWidget);
    expect(_takeError(), isNull);
  });

  testWidgets('survives text scale 2.0 at the 320px viewport', (t) async {
    t.view.physicalSize = const Size(2000, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_host());
    await _frames(t);
    await _select(t, '2.0');
    await _select(t, '320');
    expect(
      _takeError(),
      isNull,
      reason: 'the worst-case layout must not throw',
    );
  });
}
