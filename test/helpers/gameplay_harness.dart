import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/core/localization/app_localizations.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_game_view.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/v2_capabilities.dart';
import 'package:context_game/features/v2/presentation/controllers/capabilities_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Test harness for the core gameplay view.
///
/// [SiyagGameView] takes its data and callbacks as parameters, so nothing here
/// stubs a repository or a controller — the widget tree, theme, localization and
/// every design-system component under test are real.

SiyaqGuessData guess(
  String word,
  int rank, {
  required double heat,
  bool solved = false,
}) => SiyaqGuessData(word: word, rank: rank, heat: heat, solved: solved);

/// Builds gameplay inside a real MaterialApp.
///
/// [uiLang] is the app locale (chrome, labels); [gameLanguage] is the vocabulary
/// being played. They are deliberately independent — crossing them is the case
/// the language work exists for.
Widget buildGameplay({
  Brightness brightness = Brightness.dark,
  String uiLang = 'ar',
  GameplayLanguage gameLanguage = GameplayLanguage.arabic,
  String title = 'عام',
  List<SiyaqGuessData> guesses = const [],
  List<SiyaqHintData> hints = const [],
  int hintsRemaining = 3,
  bool hintLoading = false,
  bool submitting = false,
  bool solved = false,
  String? flash,
  String? inputError,
  String? lastWord,
  List<String> suggestions = const [],
  double textScale = 1.0,

  /// Simulates a raised soft keyboard, which the screen reads via
  /// `MediaQuery.viewInsetsOf` to shed chrome and park the hint panel.
  double viewInsetsBottom = 0,
  TextEditingController? controller,
  ValueChanged<String>? onSubmit,
  VoidCallback? onRequestHint,
  ValueChanged<String>? onSuggestionTap,
}) {
  final loc = AppLocalizations(uiLang);
  // The view hosts the translation assist (a Consumer), so the tree needs a
  // ProviderScope. Capabilities are pinned to `unavailable` so no test ever
  // reaches the network — the assist still works because tests run in debug
  // mode, where the dev fixture adapter is active.
  return ProviderScope(
    overrides: [
      capabilitiesProvider.overrideWith(
        (ref) async => V2Capabilities.unavailable,
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SiyaqThemeData.of(
        brightness,
        script: SiyaqTypography.scriptForLocale(uiLang),
      ),
      locale: Locale(uiLang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => MediaQuery(
          // viewInsets is only overridden when a caller asks for it: tests that
          // drive the *platform* inset (`tester.view.viewInsets`) would
          // otherwise have it silently reset to zero here.
          data: viewInsetsBottom == 0
              ? MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale))
              : MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
                ),
          child: SiyagGameView(
            loc: loc,
            title: title,
            gameLanguage: gameLanguage,
            guesses: guesses,
            controller: controller ?? TextEditingController(),
            onSubmit: onSubmit ?? (_) {},
            submitting: submitting,
            flash: flash,
            hints: hints,
            hintsRemaining: hintsRemaining,
            hintLoading: hintLoading,
            onRequestHint: onRequestHint ?? () {},
            solved: solved,
            unknownSuggestions: suggestions,
            onSuggestionTap: onSuggestionTap,
            inputError: inputError,
            lastWord: lastWord,
            onBack: () {},
          ),
        ),
      ),
    ),
  );
}
