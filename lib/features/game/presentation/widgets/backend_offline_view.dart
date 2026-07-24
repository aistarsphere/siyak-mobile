import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/app_settings_controller.dart';
import 'glow_button.dart';

/// Friendly "backend offline" state shown when a request can't reach the
/// server (502 / timeout / DNS / connection refused). Never shows a raw
/// technical error. Offers Retry, and — for developers only — a shortcut to
/// change the server URL in Settings.
class BackendOfflineView extends ConsumerWidget {
  const BackendOfflineView({
    super.key,
    required this.onRetry,
    this.onChangeServer,
  });

  final VoidCallback onRetry;

  /// Navigates to the developer server-URL field. When null, that button is
  /// hidden (e.g. contexts without a route to Settings).
  final VoidCallback? onChangeServer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainer.withValues(alpha: 0.5),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc('offlineTitle'),
              textAlign: TextAlign.center,
              style: AppTypography.headlineMobile.copyWith(
                color: AppColors.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc('offlineSubtitle'),
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            GlowButton(
              label: loc('retry'),
              icon: Icons.refresh,
              onTap: onRetry,
            ),
            if (onChangeServer != null) ...[
              const SizedBox(height: 8),
              GlassButton(
                label: loc('changeServer'),
                icon: Icons.dns_outlined,
                onTap: onChangeServer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
