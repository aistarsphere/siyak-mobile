import 'package:flutter/material.dart';

import '../../components/foundation/siyaq_button.dart';
import '../../components/foundation/siyaq_surface.dart';
import '../../components/foundation/siyaq_text.dart';
import '../../components/shared/siyaq_avatar.dart';
import '../../components/shared/siyaq_chip.dart';
import '../../components/shared/siyaq_icon_tile.dart';
import '../../components/shared/siyaq_leaderboard.dart';
import '../../components/shared/siyaq_list_row.dart';
import '../../components/shared/siyaq_progress_bar.dart';
import '../../components/shared/siyaq_modals.dart';
import '../../components/shared/siyaq_screen_header.dart';
import '../../components/shared/siyaq_segmented_control.dart';
import '../../components/shared/siyaq_states.dart';
import '../../components/shared/siyaq_stat_card.dart';
import '../../components/shared/siyaq_text_field.dart';
import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import 'token_pages.dart';

String _t(BuildContext context, String ar, String en) =>
    context.isRtl ? ar : en;

/// Gallery coverage for the shared components introduced by the Profile pilot.
class SharedComponentsPage extends StatefulWidget {
  const SharedComponentsPage({super.key});

  @override
  State<SharedComponentsPage> createState() => _SharedComponentsPageState();
}

class _SharedComponentsPageState extends State<SharedComponentsPage> {
  ThemeMode _mode = ThemeMode.system;
  String _lang = 'ar';
  final _nameController = TextEditingController(text: 'كاظم');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'AVATAR · 4 sizes × presence',
          children: [
            Wrap(
              spacing: SiyaqSpacing.lg,
              runSpacing: SiyaqSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final size in SiyaqAvatarSize.values)
                  SiyaqAvatar(name: 'كاظم', size: size),
                for (final p in SiyaqPresence.values)
                  SiyaqAvatar(
                    name: 'Sam',
                    size: SiyaqAvatarSize.large,
                    presence: p,
                  ),
                const SiyaqAvatar(
                  name: 'Guest',
                  size: SiyaqAvatarSize.large,
                  emphasised: false,
                ),
                // No name at all — must never render an empty circle.
                const SiyaqAvatar(name: '', size: SiyaqAvatarSize.large),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'CHIP · 3 variants · numeric · tappable',
          children: [
            Wrap(
              spacing: SiyaqSpacing.sm,
              runSpacing: SiyaqSpacing.sm,
              children: [
                for (final v in SiyaqChipVariant.values)
                  SiyaqChip(label: v.name, variant: v),
                SiyaqChip(
                  label: 'SYG-4F2A9',
                  numeric: true,
                  icon: SiyaqIcons.playerId,
                  trailingIcon: SiyaqIcons.copy,
                  onTap: () {},
                ),
                SiyaqChip(
                  label: _t(context, 'الحيوانات', 'Animals'),
                  icon: SiyaqIcons.catAnimals,
                  variant: SiyaqChipVariant.accent,
                  accent: c.gameMultiplayer,
                ),
                SiyaqChip(
                  label: _t(context, 'مصنّفة', 'Ranked'),
                  variant: SiyaqChipVariant.selected,
                  accent: c.gameRanked,
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'STAT GRID · reflows 4 → 2 → 1 instead of overflowing',
          children: [
            SiyaqStatGrid(
              children: [
                SiyaqStatCard(
                  value: '128',
                  label: _t(context, 'ألعاب', 'Games'),
                ),
                SiyaqStatCard(
                  value: '96',
                  label: _t(context, 'حلول', 'Solved'),
                ),
                SiyaqStatCard(value: '17', label: _t(context, 'غرف', 'Rooms')),
                SiyaqStatCard(
                  value: '#3',
                  label: _t(context, 'الأفضل', 'Best'),
                  accent: c.primary,
                ),
              ],
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqStatGrid(
              columns: 3,
              children: [
                SiyaqStatCard(
                  value: null,
                  label: _t(context, 'لا بيانات', 'No data'),
                ),
                SiyaqStatCard(
                  value: '—',
                  label: _t(context, 'تحميل', 'Loading'),
                  loading: true,
                ),
                SiyaqStatCard(
                  value: '999999',
                  label: _t(
                    context,
                    'عنوان طويل جدًا للاختبار',
                    'A very long caption for testing',
                  ),
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'SEGMENTED CONTROL · icons drop before labels truncate',
          children: [
            SiyaqSegmentedControl<ThemeMode>(
              value: _mode,
              onChanged: (v) => setState(() => _mode = v),
              segments: [
                SiyaqSegment(
                  value: ThemeMode.system,
                  label: _t(context, 'النظام', 'System'),
                  icon: SiyaqIcons.themeSystem,
                ),
                SiyaqSegment(
                  value: ThemeMode.light,
                  label: _t(context, 'فاتح', 'Light'),
                  icon: SiyaqIcons.themeLight,
                ),
                SiyaqSegment(
                  value: ThemeMode.dark,
                  label: _t(context, 'داكن', 'Dark'),
                  icon: SiyaqIcons.themeDark,
                ),
              ],
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqSegmentedControl<String>(
              value: _lang,
              onChanged: (v) => setState(() => _lang = v),
              segments: [
                SiyaqSegment(
                  value: 'ar',
                  label: _t(context, 'العربية', 'Arabic'),
                ),
                SiyaqSegment(
                  value: 'en',
                  label: _t(context, 'الإنجليزية', 'English'),
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'LIST ROW · icon / title / subtitle / trailing / chevron',
          children: [
            SiyaqListRow(
              leadingIcon: SiyaqIcons.verified,
              leadingColor: c.success,
              title: _t(context, 'مرتبط بحساب Google', 'Linked with Google'),
              trailing: SiyaqButton(
                label: _t(context, 'تسجيل الخروج', 'Sign out'),
                type: SiyaqButtonType.secondary,
                size: SiyaqButtonSize.medium,
                onPressed: () {},
              ),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqListRow(
              leadingIcon: SiyaqIcons.settings,
              title: _t(context, 'الإعدادات', 'Settings'),
              subtitle: _t(
                context,
                'الصوت والإشعارات',
                'Sound & notifications',
              ),
              showChevron: true,
              onTap: () {},
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqListRow(
              leadingIcon: SiyaqIcons.error,
              title: _t(context, 'حذف الحساب', 'Delete account'),
              tone: SiyaqTone.error,
              showChevron: true,
              onTap: () {},
            ),
          ],
        ),
        GallerySection(
          title: 'TEXT FIELD · empty / filled / error / disabled',
          children: [
            SiyaqTextField(
              label: _t(context, 'الاسم', 'Name'),
              hint: _t(context, 'اكتب اسمك', 'Enter your name'),
              maxLength: 24,
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqTextField(
              controller: _nameController,
              label: _t(context, 'الاسم', 'Name'),
              helper: _t(context, 'يظهر للاعبين', 'Visible to players'),
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqTextField(
              label: _t(context, 'الاسم', 'Name'),
              hint: 'x',
              errorText: _t(context, 'الاسم قصير جدًا', 'Name is too short'),
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqTextField(
              label: _t(context, 'الاسم', 'Name'),
              hint: _t(context, 'غير متاح', 'Unavailable'),
              enabled: false,
            ),
          ],
        ),
        GallerySection(
          title: 'MODALS · launch to verify direction and keyboard inset',
          children: [
            Row(
              children: [
                Expanded(
                  child: SiyaqButton(
                    label: _t(context, 'ورقة', 'Sheet'),
                    type: SiyaqButtonType.secondary,
                    size: SiyaqButtonSize.medium,
                    onPressed: () => SiyaqSheet.show<void>(
                      context: context,
                      direction: Directionality.of(context),
                      builder: (ctx) => SiyaqSheet(
                        title: _t(context, 'تعديل الاسم', 'Edit name'),
                        body: _t(
                          context,
                          'يظهر هذا الاسم للاعبين الآخرين.',
                          'This name is visible to other players.',
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SiyaqTextField(
                              hint: _t(context, 'اكتب اسمك', 'Enter your name'),
                              maxLength: 24,
                            ),
                            const SizedBox(height: SiyaqSpacing.md),
                            SiyaqButton(
                              label: _t(context, 'حفظ', 'Save'),
                              fullWidth: true,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SiyaqSpacing.sm),
                Expanded(
                  child: SiyaqButton(
                    label: _t(context, 'حوار', 'Dialog'),
                    type: SiyaqButtonType.destructive,
                    size: SiyaqButtonSize.medium,
                    onPressed: () => showSiyaqConfirm(
                      context,
                      direction: Directionality.of(context),
                      title: _t(context, 'تسجيل الخروج؟', 'Sign out?'),
                      body: _t(
                        context,
                        'سيتوقف تزامن تقدمك على هذا الجهاز.',
                        'Your progress will stop syncing on this device.',
                      ),
                      confirmLabel: _t(context, 'تسجيل الخروج', 'Sign out'),
                      cancelLabel: _t(context, 'إلغاء', 'Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'SCREEN HEADER · kicker + title, optional back',
          children: [
            SiyaqScreenHeader(
              kicker: _t(context, 'لوحة الصدارة', 'Leaderboard'),
              title: _t(context, 'الترتيب', 'Placement'),
              padding: EdgeInsets.zero,
            ),
            SiyaqScreenHeader(
              title: _t(context, 'إنشاء غرفة', 'Create room'),
              onBack: () {},
              backLabel: _t(context, 'رجوع', 'Back'),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        GallerySection(
          title: 'LEADERBOARD · podium 2·1·3 + rows (Top3 / Regular / Self)',
          children: [
            const SiyaqPodium(
              animate: false,
              places: [
                SiyaqPodiumPlace(placement: 1, label: 'كاظم العكبي'),
                SiyaqPodiumPlace(placement: 2, label: 'Sara'),
                SiyaqPodiumPlace(placement: 3, label: 'مصطفى'),
              ],
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            for (final (placement, name, self, solved)
                in <(int, String, bool, bool)>[
                  (1, 'كاظم العكبي', false, true),
                  (2, 'Sara', false, true),
                  (3, 'مصطفى', false, true),
                  (4, 'Abdulrahman Al-Hashimi', false, true),
                  (5, 'Yusuf', true, true),
                  (6, 'Omar', false, false),
                ])
              SiyaqLeaderboardRow(
                placement: placement,
                label: name,
                isSelf: self,
                solved: solved,
                solvedLabel: _t(context, 'أحسنت', 'Solved'),
                trailing: [
                  SiyaqMetaStat(
                    value: '${10 + placement}',
                    icon: SiyaqIcons.attempts,
                    semanticLabel: 'Guesses: ${10 + placement}',
                  ),
                  SiyaqMetaStat(
                    value: '2:${(placement * 7).toString().padLeft(2, '0')}',
                    icon: SiyaqIcons.timer,
                    semanticLabel: 'Time',
                  ),
                ],
              ),
          ],
        ),
        GallerySection(
          title: 'ICON TILE · 3 sizes · solid / tinted / glow',
          children: [
            Wrap(
              spacing: SiyaqSpacing.md,
              runSpacing: SiyaqSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in SiyaqIconTileSize.values)
                  SiyaqIconTile(icon: SiyaqIcons.ranked, size: s),
                const SiyaqIconTile(icon: SiyaqIcons.ranked, glow: true),
                SiyaqIconTile(
                  icon: SiyaqIcons.social,
                  tinted: true,
                  accent: c.gameMultiplayer,
                ),
                SiyaqIconTile(
                  icon: SiyaqIcons.hint,
                  tinted: true,
                  accent: c.gameWeekly,
                ),
                SiyaqIconTile(icon: SiyaqIcons.hot, accent: c.gameRanked),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'PROGRESS BAR · 0 / 33 / 66 / 100% · with labels',
          children: [
            for (final v in <double>[0, 0.33, 0.66, 1])
              Padding(
                padding: const EdgeInsets.only(bottom: SiyaqSpacing.md),
                child: SiyaqProgressBar(value: v, animate: false),
              ),
            SiyaqProgressBar(
              value: 0.66,
              animate: false,
              label: _t(context, 'الوقت المتبقّي', 'Time remaining'),
              trailingLabel: '2:07',
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqProgressBar(
              value: 0.42,
              animate: false,
              accent: c.gameWeekly,
              label: _t(context, 'التقدّم', 'Progress'),
            ),
          ],
        ),
        GallerySection(
          title: 'HEADER · kicker only (no large title)',
          children: [
            SiyaqScreenHeader(
              kicker: _t(context, 'التحدي الأسبوعي', 'Weekly challenge'),
              accent: c.primary,
              onBack: () {},
              backLabel: _t(context, 'رجوع', 'Back'),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        GallerySection(
          title: 'STAT CARD · numeric vs word values',
          children: [
            SiyaqStatGrid(
              columns: 3,
              minCellWidth: 88,
              children: [
                SiyaqStatCard(
                  value: '#12',
                  label: _t(context, 'ترتيبك', 'Your placement'),
                  accent: c.primary,
                ),
                SiyaqStatCard(
                  value: _t(context, 'أدب', 'Literature'),
                  label: _t(context, 'الفئة', 'Category'),
                  numeric: false,
                ),
                SiyaqStatCard(
                  value: _t(context, 'قيد التقدّم', 'In progress'),
                  label: _t(context, 'مشاركتك', 'Your participation'),
                  numeric: false,
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'STATES · loader / empty / error',
          children: [
            SiyaqSurface(
              padding: EdgeInsets.zero,
              child: SizedBox(height: 120, child: SiyaqLoader()),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqSurface(
              padding: EdgeInsets.zero,
              child: SizedBox(height: 120, child: SiyaqLoader.inline()),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqSurface(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 240,
                child: SiyaqEmptyState(
                  title: _t(context, 'لا شيء هنا بعد', 'Nothing here yet'),
                  icon: SiyaqIcons.leaderboard,
                ),
              ),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqSurface(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 300,
                child: SiyaqEmptyState.error(
                  title: _t(context, 'تعذّر التحميل', "Couldn't load"),
                  body: _t(
                    context,
                    'تحقّق من اتصالك وحاول مرة أخرى.',
                    'Check your connection and try again.',
                  ),
                  actionLabel: _t(context, 'إعادة المحاولة', 'Retry'),
                  onAction: () {},
                ),
              ),
            ),
          ],
        ),
        GallerySection(
          title: 'COMPOSED · a Profile-shaped block',
          children: [
            SiyaqSurface(
              child: Column(
                children: [
                  SiyaqAvatar(name: 'كاظم', size: SiyaqAvatarSize.xlarge),
                  const SizedBox(height: SiyaqSpacing.md),
                  SiyaqText(
                    _t(context, 'كاظم العكبي', 'Kadhim Al-Ekabi'),
                    role: SiyaqTextRole.headingLarge,
                  ),
                  const SizedBox(height: SiyaqSpacing.xs),
                  SiyaqChip(
                    label: 'SYG-4F2A9',
                    numeric: true,
                    icon: SiyaqIcons.playerId,
                    trailingIcon: SiyaqIcons.copy,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
