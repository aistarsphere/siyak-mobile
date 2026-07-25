import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/domain/entities/weekly.dart';
import '../../../v2/presentation/controllers/weekly_controller.dart';
import '../siyag_route.dart';
import 'siyag_topbar.dart';
import 'siyag_weekly_game_screen.dart';

/// Weekly hero overview (weekly.tsx): centered trophy hero + countdown boxes,
/// meta row, start action. Wired to the live weekly challenge.
class SiyagWeeklyScreen extends ConsumerWidget {
  const SiyagWeeklyScreen({super.key});

  List<(String, String)> _countdown(Duration? d) {
    if (d == null) return [('--', 'أيام'), ('--', 'ساعة'), ('--', 'دقيقة')];
    return [
      (d.inDays.toString().padLeft(2, '0'), 'أيام'),
      ((d.inHours % 24).toString().padLeft(2, '0'), 'ساعة'),
      ((d.inMinutes % 60).toString().padLeft(2, '0'), 'دقيقة'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang);
    final async = ref.watch(weeklyChallengeProvider(lang));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: async.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: SC.coral)),
              error: (e, _) => _Error(
                onRetry: () => ref.invalidate(weeklyChallengeProvider(lang)),
              ),
              data: (c) => Column(
                children: [
                  SiyagTopBar(kicker: 'Hero Mode', kickerColor: SC.coral),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _Hero(countdown: _countdown(c.timeRemaining)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _meta(
                              Icons.category_rounded,
                              c.categoryLabel(true),
                              'التصنيف',
                            ),
                            const SizedBox(width: 10),
                            _meta(
                              Icons.emoji_events_rounded,
                              c.placement != null ? '#${c.placement}' : '—',
                              'مركزك',
                            ),
                            const SizedBox(width: 10),
                            _meta(
                              Icons.schedule_rounded,
                              _state(c.state),
                              'الحالة',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: SiyagPrimaryButton(
                      label: c.participated
                          ? 'متابعة التحدي'
                          : 'ابدأ التحدي الأسبوعي',
                      icon: Icons.play_arrow_rounded,
                      onTap: () async {
                        await ref
                            .read(weeklyRunControllerProvider.notifier)
                            .start(lang);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            siyagRoute(const SiyagWeeklyGameScreen()),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _state(WeeklyState s) => switch (s) {
    WeeklyState.active => 'نشط',
    WeeklyState.completed => 'مكتمل',
    WeeklyState.notStarted => 'لم يبدأ',
  };

  Widget _meta(IconData icon, String v, String l) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: SC.cyan),
          const SizedBox(height: 8),
          Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ST.mono(18),
          ),
          const SizedBox(height: 6),
          Text(l, style: ST.ar(10, color: SC.textMute)),
        ],
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.countdown});
  final List<(String, String)> countdown;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: SC.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SC.coral.withValues(alpha: 0.27)),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -64,
              end: -40,
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SC.coral.withValues(alpha: 0.14),
                  boxShadow: [
                    BoxShadow(
                      color: SC.coral.withValues(alpha: 0.14),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SC.coral,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      size: 26,
                      color: SC.onGold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'التحدي الأسبوعي',
                    style: ST.ar(28, weight: FontWeight.w700, height: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'كلمة واحدة · أسبوع كامل · مجد للأفضل',
                    style: ST.ar(14, color: SC.textMute),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final t in countdown) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: SC.surfaceHi,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(t.$1, style: ST.mono(24)),
                              const SizedBox(height: 4),
                              Text(t.$2, style: ST.ar(10, color: SC.textMute)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: SC.textMute),
          const SizedBox(height: 16),
          Text('تعذّر تحميل التحدي', style: ST.ar(16, color: SC.textDim)),
          const SizedBox(height: 16),
          SiyagPrimaryButton(
            label: 'إعادة المحاولة',
            icon: Icons.refresh_rounded,
            onTap: onRetry,
          ),
        ],
      ),
    ),
  );
}
