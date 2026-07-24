import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/providers.dart';
import '../widgets/app_logo.dart';
import '../widgets/atmospheric_background.dart';
import '../widgets/glow_button.dart';
import 'settings_screen.dart';
import 'shell_screen.dart';

/// Premium loading state in the Stitch design language: atmospheric glow,
/// glowing logo card, brand title, amber progress. Health-checks the backend
/// by loading `/api/modes` (initial app config) before entering the app.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final modes = ref.watch(modesProvider);

    ref.listen(modesProvider, (previous, next) {
      if (next.hasValue) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, animation, _) =>
                FadeTransition(opacity: animation, child: const ShellScreen()),
          ),
        );
      }
    });

    return Scaffold(
      body: AtmosphericBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(),
                  const SizedBox(height: 24),
                  Text(
                    loc('appTitle'),
                    style: AppTypography.displayLg.copyWith(
                      color: AppColors.primary,
                      shadows: AppTypography.amberTextGlow,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc('tagline'),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (modes.isLoading) ...[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc('connecting'),
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ] else if (modes.hasError) ...[
                    // Friendly backend-offline messaging (never a raw error).
                    if (ApiException.isOffline(modes.error)) ...[
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
                    ] else
                      Text(
                        loc.errorMessage(modes.error!),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    const SizedBox(height: 24),
                    GlowButton(
                      label: loc('retry'),
                      icon: Icons.refresh,
                      onTap: () => ref.invalidate(modesProvider),
                    ),
                    if (ApiException.isOffline(modes.error)) ...[
                      const SizedBox(height: 8),
                      GlassButton(
                        label: loc('changeServer'),
                        icon: Icons.dns_outlined,
                        onTap: () {
                          ref.read(openDevServerProvider.notifier).state = true;
                          ref.read(shellTabProvider.notifier).state = 2;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const ShellScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
