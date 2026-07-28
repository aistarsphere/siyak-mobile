import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/presentation/controllers/capabilities_controller.dart';
import '../../domain/translation/translation_service.dart';

/// The active translation backend, or null when the feature is unavailable.
///
/// Release builds require the backend `translation` capability — which no
/// backend ships yet, so in production this is null and the assistant simply
/// does not exist. Debug builds fall back to the deterministic
/// [DevTranslationAdapter] so the UX can be exercised end-to-end.
final translationServiceProvider = Provider<TranslationService?>((ref) {
  final caps = ref.watch(capabilitiesProvider).value;
  if (caps?.translationEnabled ?? false) {
    // The remote adapter plugs in here once the backend ships the contract in
    // docs/TRANSLATION_CONTRACT.md. Until then the flag cannot be true in
    // production (fail-closed mapper), so this branch is unreachable — but a
    // debug backend that sets it still gets the dev adapter rather than a lie.
    return const DevTranslationAdapter();
  }
  if (kDebugMode) return const DevTranslationAdapter();
  return null;
});

/// Compact, dismissible translation assist above the gameplay composer.
///
/// Appears only when the typed input is written in the *other* supported
/// script from the game language (script detection is local and
/// deterministic). It shows the original input, visibly distinct, and
/// candidate words in the gameplay language as chips. Tapping a candidate
/// **fills the composer** — it never submits; the pick then flows through the
/// normal guess path where the server validates it against the vocabulary.
///
/// The panel is stateless about gameplay: it only knows the current text and
/// the game language, so any mode with a composer can host it.
class TranslationAssist extends ConsumerStatefulWidget {
  const TranslationAssist({
    super.key,
    required this.text,
    required this.gameLanguage,
    required this.noCandidatesLabel,
    required this.onPick,
  });

  /// Current composer text, as typed.
  final String text;

  final GameplayLanguage gameLanguage;

  /// Localized "no suggestions" copy — supplied by the host so the panel stays
  /// free of localization plumbing, like the rest of the gameplay components.
  final String noCandidatesLabel;

  /// Called with the chosen gameplay-language word. The host fills its
  /// composer with it — nothing is submitted here.
  final ValueChanged<String> onPick;

  @override
  ConsumerState<TranslationAssist> createState() => _TranslationAssistState();
}

class _TranslationAssistState extends ConsumerState<TranslationAssist> {
  List<TranslationCandidate> _candidates = const [];

  /// The input the current candidates belong to — stale results are dropped.
  String _resolvedFor = '';

  /// The input the player dismissed the panel for. Typing something new
  /// re-arms the assist; re-showing for the same word would nag.
  String? _dismissedFor;

  @override
  void didUpdateWidget(TranslationAssist old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.gameLanguage != widget.gameLanguage) {
      _resolve();
    }
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final text = widget.text.trim();
    final service = ref.read(translationServiceProvider);
    if (service == null ||
        !isLikelyOtherLanguage(text, widget.gameLanguage) ||
        text == _dismissedFor) {
      if (_candidates.isNotEmpty || _resolvedFor != text) {
        setState(() {
          _candidates = const [];
          _resolvedFor = text;
        });
      }
      return;
    }

    final from = widget.gameLanguage.isArabic
        ? GameplayLanguage.english
        : GameplayLanguage.arabic;
    final result = await service.suggest(
      text: text,
      from: from,
      to: widget.gameLanguage,
    );
    if (!mounted || widget.text.trim() != text) return; // stale
    setState(() {
      _candidates = result;
      _resolvedFor = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = widget.text.trim();
    final service = ref.watch(translationServiceProvider);

    final active =
        service != null &&
        isLikelyOtherLanguage(text, widget.gameLanguage) &&
        text != _dismissedFor &&
        _resolvedFor == text;

    return AnimatedSize(
      duration: context.motion.quick,
      curve: SiyaqMotion.easeOut,
      alignment: Alignment.bottomCenter,
      child: !active
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: SiyaqSpacing.sm),
              child: SiyaqTintedSurface(
                tone: SiyaqTone.info,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SiyaqIcon.decorative(
                          SiyaqIcons.language,
                          size: SiyaqIconSize.sm,
                          color: c.info,
                        ),
                        const SizedBox(width: SiyaqSpacing.sm),
                        Expanded(
                          child: SiyaqText(
                            // The original input, visibly distinct from the
                            // gameplay-language candidates below: muted, quoted,
                            // rendered in its own script.
                            '"$text"',
                            role: SiyaqTextRole.bodySmall,
                            script: widget.gameLanguage.isArabic
                                ? SiyaqScript.latin
                                : SiyaqScript.arabic,
                            color: c.textMuted,
                            maxLines: 1,
                          ),
                        ),
                        SiyaqIconButton(
                          icon: SiyaqIcons.close,
                          semanticLabel: MaterialLocalizations.of(
                            context,
                          ).closeButtonLabel,
                          size: SiyaqIconButtonSize.small,
                          onPressed: () => setState(() => _dismissedFor = text),
                        ),
                      ],
                    ),
                    const SizedBox(height: SiyaqSpacing.xs),
                    if (_candidates.isEmpty)
                      SiyaqText(
                        widget.noCandidatesLabel,
                        role: SiyaqTextRole.bodySmall,
                        color: c.textMuted,
                      )
                    else
                      Wrap(
                        spacing: SiyaqSpacing.sm,
                        runSpacing: SiyaqSpacing.sm,
                        children: [
                          for (final cand in _candidates)
                            Directionality(
                              textDirection: widget.gameLanguage.direction,
                              child: SiyaqChip(
                                label: cand.word,
                                variant: SiyaqChipVariant.accent,
                                accent: c.info,
                                onTap: () => widget.onPick(cand.word),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
