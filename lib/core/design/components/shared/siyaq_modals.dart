import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_button.dart';
import '../foundation/siyaq_text.dart';

/// Standard sheet chrome: drag handle, title, optional body, then content.
///
/// Covers Figma's `Siyaq/Bottom Sheet`. Handles the two things every ad-hoc sheet
/// in the app re-implemented: keyboard inset padding (so an input is not hidden
/// behind the keyboard) and a scroll fallback so tall content at large text
/// scales stays reachable instead of overflowing.
class SiyaqSheet extends StatelessWidget {
  const SiyaqSheet({
    super.key,
    required this.title,
    required this.child,
    this.body,
  });

  final String title;
  final String? body;
  final Widget child;

  /// Presents [builder] as a modal sheet with this chrome and the ambient theme.
  ///
  /// [direction] is passed explicitly because a modal route is a sibling of the
  /// screen's own [Directionality], not a descendant of it.
  static Future<T?> show<T>({
    required BuildContext context,
    required TextDirection direction,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: direction,
        child: Builder(builder: builder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SiyaqRadius.xxxl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              SiyaqSpacing.xl,
              SiyaqSpacing.lg,
              SiyaqSpacing.xl,
              SiyaqSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: SiyaqSpacing.lg),
                    decoration: BoxDecoration(
                      color: c.textDisabled,
                      borderRadius: BorderRadius.circular(SiyaqRadius.full),
                    ),
                  ),
                ),
                SiyaqText(title, role: SiyaqTextRole.headingSmall),
                if (body != null) ...[
                  const SizedBox(height: SiyaqSpacing.xs),
                  SiyaqText(
                    body!,
                    role: SiyaqTextRole.bodyMedium,
                    color: c.textSecondary,
                  ),
                ],
                const SizedBox(height: SiyaqSpacing.md),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirm/cancel dialog for a consequential action.
///
/// Covers Figma's `Siyaq/Dialog` (`Confirmation`). Replaces `showSiyagConfirm`,
/// preserving its contract exactly — returns `true` only on confirm — while
/// routing the confirm button through [SiyaqButton] so it gains the pressed,
/// focused and AA-contrast behaviour the old dialog lacked.
Future<bool> showSiyaqConfirm(
  BuildContext context, {
  required TextDirection direction,
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: context.colors.scrim,
    builder: (ctx) => Directionality(
      textDirection: direction,
      child: Builder(
        builder: (ctx) {
          final c = ctx.colors;
          return Dialog(
            backgroundColor: c.surface,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: SiyaqSpacing.xxxl,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SiyaqRadius.xxxl),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                SiyaqSpacing.xl,
                SiyaqSpacing.xxl,
                SiyaqSpacing.xl,
                SiyaqSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SiyaqText(
                    title,
                    role: SiyaqTextRole.headingSmall,
                    align: TextAlign.center,
                  ),
                  const SizedBox(height: SiyaqSpacing.smd),
                  SiyaqText(
                    body,
                    role: SiyaqTextRole.bodyMedium,
                    color: c.textMuted,
                    align: TextAlign.center,
                  ),
                  const SizedBox(height: SiyaqSpacing.xl),
                  SiyaqButton(
                    label: confirmLabel,
                    type: destructive
                        ? SiyaqButtonType.destructive
                        : SiyaqButtonType.primary,
                    fullWidth: true,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                  const SizedBox(height: SiyaqSpacing.sm),
                  SiyaqButton(
                    label: cancelLabel,
                    type: SiyaqButtonType.secondary,
                    fullWidth: true,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  return ok ?? false;
}
