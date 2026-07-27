import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_button.dart';
import '../foundation/siyaq_text.dart';

/// Centred zero-data / failure state: icon, title, optional body, optional CTA.
///
/// Covers Figma's `Siyaq/Empty State` (`NoResults` / `NoHistory` / `NoFriends`)
/// and the `Dialog Type=Error` retry affordance. The audit found the app had no
/// shared empty state at all — only one ad-hoc `_Error` on the Weekly screen
/// (§6.5, §17), so most screens rendered a blank list instead.
class SiyaqEmptyState extends StatelessWidget {
  const SiyaqEmptyState({
    super.key,
    required this.title,
    this.body,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : _isError = false;

  /// Failure variant: an error-tinted icon and, usually, a retry action.
  const SiyaqEmptyState.error({
    super.key,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  }) : icon = SiyaqIcons.offline,
       _isError = true;

  final String title;
  final String? body;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool _isError;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconColor = _isError ? c.error : c.textDisabled;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SiyaqSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? SiyaqIcons.emptyBox,
              size: SiyaqIconSize.xxl,
              color: iconColor,
            ),
            const SizedBox(height: SiyaqSpacing.lg),
            SiyaqText(
              title,
              role: SiyaqTextRole.headingSmall,
              align: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: SiyaqSpacing.sm),
              SiyaqText(
                body!,
                role: SiyaqTextRole.bodyMedium,
                color: c.textMuted,
                align: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SiyaqSpacing.xl),
              SiyaqButton(
                label: actionLabel!,
                type: SiyaqButtonType.secondary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress indicator, centred for a first load or inline for pagination.
///
/// Replaces the 19 hand-rolled `CircularProgressIndicator` sites the audit found
/// (§17), each re-specifying its own size, stroke and colour.
class SiyaqLoader extends StatelessWidget {
  const SiyaqLoader({super.key, this.semanticLabel})
    : _inline = false,
      _size = 28,
      _stroke = 2.6;

  /// Small, for "loading more" at the end of a list.
  const SiyaqLoader.inline({super.key, this.semanticLabel})
    : _inline = true,
      _size = 20,
      _stroke = 2;

  final String? semanticLabel;
  final bool _inline;
  final double _size;
  final double _stroke;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: _size,
      height: _size,
      child: CircularProgressIndicator(
        strokeWidth: _stroke,
        color: context.colors.primary,
      ),
    );
    return Semantics(
      container: true,
      // Announced so a screen reader knows work is in progress rather than
      // reporting an empty screen.
      label: semanticLabel,
      liveRegion: semanticLabel != null,
      child: ExcludeSemantics(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(
              _inline ? SiyaqSpacing.lg : SiyaqSpacing.huge,
            ),
            child: spinner,
          ),
        ),
      ),
    );
  }
}
