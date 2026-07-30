/// Arabic → English guess assistance, shown above the composer.
///
/// Renders [TranslationSuggestionController] and nothing more: fetching,
/// debouncing, cancellation and caching all live in the controller, which is what
/// lets those be tested without a widget tree.
///
/// The panel never submits. Tapping a chip fills the composer with the English
/// word and hands control back to the player, who submits with the normal action
/// — so the backend only ever receives a word the player chose.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../domain/translation/translation_suggestion.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/translation_suggestion_controller.dart';

/// Compact suggestion panel for an English game receiving Arabic input.
class TranslationAssist extends ConsumerStatefulWidget {
  const TranslationAssist({
    super.key,
    required this.text,
    required this.gameLanguage,
    required this.onPick,
    this.controllerOverride,
  });

  /// Current composer text, as typed.
  final String text;

  final GameplayLanguage gameLanguage;

  /// Called with the chosen English word. The host fills its composer; nothing
  /// is submitted here.
  final ValueChanged<String> onPick;

  /// Injected by tests so the panel can be driven without Riverpod.
  final TranslationSuggestionController? controllerOverride;

  @override
  ConsumerState<TranslationAssist> createState() => _TranslationAssistState();
}

class _TranslationAssistState extends ConsumerState<TranslationAssist> {
  TranslationSuggestionController? _controller;
  bool _ownsController = false;
  int _announcedFor = -1;

  @override
  void didUpdateWidget(TranslationAssist old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _controller?.onInputChanged(widget.text);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _announceIfNeeded();
  }

  /// Announces arrivals to a screen reader.
  ///
  /// The panel appears without focus moving, so nothing would otherwise tell a
  /// screen-reader user that options exist. Announced once per result set.
  void _announceIfNeeded() {
    final state = _controller!.state;
    if (state.phase != TranslationPhase.success) return;
    if (_announcedFor == state.suggestions.length) return;
    _announcedFor = state.suggestions.length;
    final loc = ref.read(localizationsProvider);
    // `sendAnnouncement` is not available across the Flutter versions this
    // project builds on, so the deprecated call stays until the floor moves.
    // ignore: deprecated_member_use
    SemanticsService.announce(
      loc.fill('translationAnnounce', {'n': '${state.suggestions.length}'}),
      loc.direction,
    );
  }

  void _ensureController() {
    if (_controller != null) return;
    final injected = widget.controllerOverride;
    if (injected != null) {
      _controller = injected;
      _ownsController = false;
    } else {
      final repo = ref.read(
        translationSuggestionRepositoryProvider(widget.gameLanguage),
      );
      // Feature unavailable for this language: render nothing, ever.
      if (repo == null) return;
      _controller = TranslationSuggestionController(
        repository: repo,
        gameLanguage: widget.gameLanguage,
      );
      _ownsController = true;
    }
    _controller!.addListener(_onChanged);
    _controller!.onInputChanged(widget.text);
  }

  @override
  Widget build(BuildContext context) {
    _ensureController();
    final controller = _controller;
    if (controller == null) return const SizedBox(width: double.infinity);

    final state = controller.state;
    if (!state.isVisible) return const SizedBox(width: double.infinity);

    final loc = ref.watch(localizationsProvider);
    final c = context.colors;

    return AnimatedSize(
      duration: context.motion.quick,
      curve: SiyaqMotion.easeOut,
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: SiyaqSpacing.sm),
        child: SiyaqTintedSurface(
          tone: SiyaqTone.info,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(c, state, controller),
              const SizedBox(height: SiyaqSpacing.xs),
              _body(loc, c, state, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    SiyaqColors c,
    TranslationSuggestionState state,
    TranslationSuggestionController controller,
  ) => Row(
    children: [
      SiyaqIcon.decorative(
        SiyaqIcons.language,
        size: SiyaqIconSize.sm,
        color: c.info,
      ),
      const SizedBox(width: SiyaqSpacing.sm),
      Expanded(
        // The Arabic source in its own script and direction, so it reads as the
        // *input* rather than as one of the English candidates.
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SiyaqText(
            '"${state.sourceText}"',
            role: SiyaqTextRole.bodySmall,
            script: SiyaqScript.arabic,
            color: c.textMuted,
            maxLines: 1,
          ),
        ),
      ),
      SiyaqIconButton(
        icon: SiyaqIcons.close,
        semanticLabel: MaterialLocalizations.of(context).closeButtonLabel,
        size: SiyaqIconButtonSize.small,
        onPressed: controller.dismiss,
      ),
    ],
  );

  Widget _body(
    AppLocalizations loc,
    SiyaqColors c,
    TranslationSuggestionState state,
    TranslationSuggestionController controller,
  ) => switch (state.phase) {
    TranslationPhase.loading => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.info),
        ),
        const SizedBox(width: SiyaqSpacing.sm),
        SiyaqText(
          loc('translationLoading'),
          role: SiyaqTextRole.bodySmall,
          color: c.textMuted,
        ),
      ],
    ),
    TranslationPhase.empty => SiyaqText(
      loc('noTranslations'),
      role: SiyaqTextRole.bodySmall,
      color: c.textMuted,
    ),
    TranslationPhase.error => Row(
      children: [
        Expanded(
          child: SiyaqText(
            loc('translationError'),
            role: SiyaqTextRole.bodySmall,
            color: c.textMuted,
          ),
        ),
        SiyaqButton(
          label: loc('translationRetry'),
          type: SiyaqButtonType.ghost,
          onPressed: controller.retry,
        ),
      ],
    ),
    _ => _chips(loc, c, state, controller),
  };

  Widget _chips(
    AppLocalizations loc,
    SiyaqColors c,
    TranslationSuggestionState state,
    TranslationSuggestionController controller,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        spacing: SiyaqSpacing.sm,
        runSpacing: SiyaqSpacing.sm,
        children: [
          for (final s in state.visible)
            _SuggestionChip(
              suggestion: s,
              accent: c.info,
              onTap: () {
                controller.select(s);
                widget.onPick(s.text);
              },
            ),
        ],
      ),
      if (state.hasMore) ...[
        const SizedBox(height: SiyaqSpacing.xs),
        SiyaqButton(
          label: loc('translationMore'),
          type: SiyaqButtonType.ghost,
          onPressed: controller.expand,
        ),
      ],
    ],
  );
}

/// One candidate: the English word, plus its Arabic sense gloss when the backend
/// supplied one.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.suggestion,
    required this.accent,
    required this.onTap,
  });

  final TranslationSuggestion suggestion;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = suggestion.label;

    return SiyaqPressable(
      onTap: onTap,
      // Announced as one node — the word plus its sense — so a screen reader
      // does not read two disconnected fragments.
      semanticLabel: [suggestion.text, ?suggestion.sense, ?label].join(', '),
      focusRadius: SiyaqRadius.full,
      builder: (context, state) => Container(
        constraints: const BoxConstraints(
          minHeight: SiyaqSpacing.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SiyaqSpacing.md,
          vertical: SiyaqSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: state.pressed ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(SiyaqRadius.full),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The English word always reads LTR, whatever the surrounding UI.
            Directionality(
              textDirection: TextDirection.ltr,
              child: SiyaqText(
                suggestion.text,
                role: SiyaqTextRole.bodyMedium,
                script: SiyaqScript.latin,
                weight: FontWeight.w600,
                color: c.textPrimary,
                maxLines: 1,
              ),
            ),
            if (label != null)
              Directionality(
                textDirection: TextDirection.rtl,
                child: SiyaqText(
                  label,
                  role: SiyaqTextRole.labelSmall,
                  script: SiyaqScript.arabic,
                  color: c.textMuted,
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
