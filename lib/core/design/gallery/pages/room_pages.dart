import 'package:flutter/material.dart';

import '../../components/foundation/siyaq_surface.dart';
import '../../components/foundation/siyaq_text.dart';
import '../../components/shared/siyaq_avatar.dart';
import '../../components/shared/siyaq_list_row.dart';
import '../../components/shared/siyaq_player_row.dart';
import '../../components/shared/siyaq_room_code.dart';
import '../../components/shared/siyaq_select_tile.dart';
import '../../components/shared/siyaq_states.dart';
import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import 'token_pages.dart';

String _t(BuildContext context, String ar, String en) =>
    context.isRtl ? ar : en;

/// Gallery coverage for the components introduced by the Room Lobby / Create /
/// Join migration.
///
/// The two axes worth watching here are **direction** — a room code must stay
/// LTR even under Arabic — and **text scale**, where the select tiles and the
/// selection rows are the first things to overflow.
class RoomComponentsPage extends StatefulWidget {
  const RoomComponentsPage({super.key});

  @override
  State<RoomComponentsPage> createState() => _RoomComponentsPageState();
}

class _RoomComponentsPageState extends State<RoomComponentsPage> {
  final _empty = TextEditingController();
  final _partial = TextEditingController(text: 'A7');
  final _complete = TextEditingController(text: 'A7X2');
  final _error = TextEditingController(text: 'ZZZZ');

  int _tile = 0;
  int _option = 1;
  final _step = 2;

  @override
  void dispose() {
    _empty.dispose();
    _partial.dispose();
    _complete.dispose();
    _error.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'ROOM CODE INPUT · empty / partial / complete / error',
          children: [
            SiyaqCodeField(
              controller: _empty,
              autofocus: false,
              label: _t(context, 'أدخل رمز اللعبة', 'Enter game code'),
            ),
            const SizedBox(height: SiyaqSpacing.lg),
            SiyaqCodeField(controller: _partial, autofocus: false),
            const SizedBox(height: SiyaqSpacing.lg),
            SiyaqCodeField(
              controller: _complete,
              autofocus: false,
              accent: c.info,
            ),
            const SizedBox(height: SiyaqSpacing.lg),
            SiyaqCodeField(
              controller: _error,
              autofocus: false,
              errorText: _t(
                context,
                'لم يتم العثور على اللعبة',
                'Game not found',
              ),
            ),
            const SizedBox(height: SiyaqSpacing.lg),
            SiyaqCodeField(
              controller: _complete,
              autofocus: false,
              enabled: false,
              label: _t(context, 'معطّل', 'Disabled'),
            ),
          ],
        ),
        GallerySection(
          title: 'ROOM CODE DISPLAY · stays LTR under Arabic',
          children: [
            SiyaqCodeDisplay(
              code: 'A7X2',
              label: _t(context, 'رمز الانضمام', 'Join code'),
              copyLabel: _t(context, 'نسخ', 'Copy'),
              shareLabel: _t(context, 'مشاركة', 'Share'),
              onCopy: () {},
              onShare: () {},
            ),
            const SizedBox(height: SiyaqSpacing.lg),
            SiyaqCodeDisplay(
              code: '9K4M',
              label: _t(context, 'رمز الانضمام', 'Join code'),
              accent: c.info,
            ),
          ],
        ),
        GallerySection(
          title: 'STATUS INDICATOR · solid = settled, hollow = in flight',
          children: [
            Wrap(
              spacing: SiyaqSpacing.xl,
              runSpacing: SiyaqSpacing.md,
              children: [
                SiyaqStatusIndicator(
                  label: _t(context, 'متصل', 'Connected'),
                  tone: SiyaqTone.success,
                ),
                SiyaqStatusIndicator(
                  label: _t(context, 'جارٍ الاتصال…', 'Connecting…'),
                  tone: SiyaqTone.info,
                  pulse: true,
                ),
                SiyaqStatusIndicator(
                  label: _t(context, 'إعادة الاتصال…', 'Reconnecting…'),
                  tone: SiyaqTone.warning,
                  pulse: true,
                ),
                SiyaqStatusIndicator(
                  label: _t(context, 'غير متصل', 'Offline'),
                  tone: SiyaqTone.error,
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'PLAYER ROW · self / host / guest / offline / invitable',
          children: [
            SiyaqPlayerRow(
              name: 'كاظم',
              isSelf: true,
              selfSuffix: _t(context, 'أنت', 'you'),
              subtitle: '#4821',
              presence: SiyaqPresence.online,
              roleLabel: _t(context, 'المضيف', 'Host'),
              statusLabel: _t(context, 'متصل', 'Connected'),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqPlayerRow(
              name: 'Sara',
              subtitle: '#1190',
              presence: SiyaqPresence.online,
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqPlayerRow(
              name: 'Abdulrahman Al-Mutairi',
              subtitle: '#7734',
              presence: SiyaqPresence.offline,
              statusLabel: _t(context, 'غير متصل', 'Offline'),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqPlayerRow(
              name: 'Yousef',
              subtitle: '#0042',
              accent: c.info,
              onTap: () {},
              statusLabel: _t(context, 'تمت الدعوة', 'Invited'),
              trailing: Icon(
                SiyaqIcons.checkCircle,
                size: SiyaqIconSize.sm,
                color: c.success,
              ),
            ),
          ],
        ),
        GallerySection(
          title: 'SELECT TILE · icons, not emoji — tintable and announced',
          children: [
            Wrap(
              spacing: SiyaqSpacing.md,
              runSpacing: SiyaqSpacing.md,
              children: [
                for (final (i, key) in const [
                  'animals',
                  'sports',
                  'technology',
                  'food',
                  'geography',
                ].indexed)
                  SiyaqSelectTile(
                    icon: SiyaqIcons.category(key),
                    label: key,
                    selected: _tile == i,
                    accent: c.success,
                    onTap: () => setState(() => _tile = i),
                  ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'STEP DOTS · announced "step N of M"',
          children: [
            for (var s = 0; s < 5; s++)
              Padding(
                padding: const EdgeInsets.only(bottom: SiyaqSpacing.sm),
                child: SiyaqStepDots(
                  step: s,
                  total: 5,
                  accent: c.success,
                  semanticLabel: 'Step ${s + 1} of 5',
                ),
              ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqStepDots(step: _step, total: 5, accent: c.info),
          ],
        ),
        GallerySection(
          title: 'SELECTION ROW · single choice, no bespoke option card',
          children: [
            for (final (i, label) in [
              _t(context, 'العربية', 'Arabic'),
              _t(context, 'الإنجليزية', 'English'),
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: SiyaqSpacing.md),
                child: SiyaqListRow(
                  title: label,
                  titleRole: SiyaqTextRole.bodyLarge,
                  selected: _option == i,
                  showSelectionIndicator: true,
                  selectionAccent: c.success,
                  radius: SiyaqRadius.xxl,
                  padding: const EdgeInsets.all(SiyaqSpacing.lg),
                  onTap: () => setState(() => _option = i),
                ),
              ),
            SiyaqListRow(
              title: _t(context, 'الوضع التنافسي', 'Competitive'),
              subtitle: _t(
                context,
                'تلميحات أقل، نقاط أعلى',
                'Fewer hints, higher stakes',
              ),
              titleRole: SiyaqTextRole.bodyLarge,
              leadingIcon: SiyaqIcons.social,
              leadingColor: c.primary,
              selected: true,
              showSelectionIndicator: true,
              selectionAccent: c.primary,
              radius: SiyaqRadius.xxl,
              padding: const EdgeInsets.all(SiyaqSpacing.lg),
              onTap: () {},
            ),
          ],
        ),
        GallerySection(
          title: 'LOBBY EMPTY · nobody has joined yet',
          children: [
            SiyaqSurface(
              child: SiyaqEmptyState(
                title: _t(
                  context,
                  'في انتظار انضمام اللاعبين',
                  'Waiting for players to join',
                ),
                icon: SiyaqIcons.social,
              ),
            ),
          ],
        ),
        const SizedBox(height: SiyaqSpacing.xxxl),
        SiyaqText(
          _t(
            context,
            'بدّل الاتجاه للتحقق من بقاء الرمز LTR',
            'Flip direction to confirm the code stays LTR',
          ),
          role: SiyaqTextRole.bodySmall,
          color: c.textMuted,
        ),
      ],
    );
  }
}
