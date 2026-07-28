import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/feedback/siyaq_feedback.dart';
import 'core/design/theme/siyaq_theme_data.dart';
import 'core/design/tokens/siyaq_typography.dart';
import 'core/sound/sound_service.dart';
import 'features/game/presentation/controllers/app_settings_controller.dart';
import 'features/siyag/presentation/siyag_shell.dart';

class SiyagApp extends ConsumerWidget {
  const SiyagApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider.select((s) => s.lang));
    final mode = ref.watch(appSettingsProvider.select((s) => s.themeMode));

    // Resolve the effective brightness (System follows the platform) purely to
    // drive the system UI overlay. Colours themselves are no longer pushed into
    // a global: every widget reads them from the enclosing Theme via
    // `context.colors`, so MaterialApp's own light/dark selection is the single
    // source of truth. Depending on platformBrightness keeps the overlay in sync
    // on OS light/dark changes.
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final effective = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
    SystemChrome.setSystemUIOverlayStyle(
      SiyaqThemeData.systemUiStyleFor(effective),
    );

    // Typography follows the selected language so Material widgets inherit the
    // right script family; custom widgets can still override per-string.
    final script = SiyaqTypography.scriptForLocale(lang);

    return MaterialApp(
      title: 'سياق',
      debugShowCheckedModeBanner: false,
      theme: SiyaqThemeData.light(script: script),
      darkTheme: SiyaqThemeData.dark(script: script),
      themeMode: mode,
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Above the Navigator, so pushed routes (gameplay, rooms, results) are
      // inside the scope too — a shell-level install would miss them.
      builder: (context, child) => _FeedbackScopeInstaller(child: child!),
      home: const SiyagShell(),
    );
  }
}

/// Bridges the player's Sound/Haptics settings and the sound backend into the
/// design system's [SiyaqFeedbackScope].
///
/// Also owns the audio lifecycle: preloads the hot-path clips once after the
/// first frame, and silences anything still sounding when the app leaves the
/// foreground.
class _FeedbackScopeInstaller extends ConsumerStatefulWidget {
  const _FeedbackScopeInstaller({required this.child});

  final Widget child;

  @override
  ConsumerState<_FeedbackScopeInstaller> createState() =>
      _FeedbackScopeInstallerState();
}

class _FeedbackScopeInstallerState
    extends ConsumerState<_FeedbackScopeInstaller>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(soundServiceProvider).preload();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(soundServiceProvider).stopAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sound = ref.watch(appSettingsProvider.select((s) => s.sound));
    final haptics = ref.watch(appSettingsProvider.select((s) => s.haptics));
    final service = ref.watch(soundServiceProvider);
    return SiyaqFeedbackScope(
      feedback: SiyaqFeedback(
        soundEnabled: sound,
        hapticsEnabled: haptics,
        play: service.play,
      ),
      child: widget.child,
    );
  }
}
