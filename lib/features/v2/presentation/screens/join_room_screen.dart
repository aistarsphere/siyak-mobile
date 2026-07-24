import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/glow_button.dart';
import '../controllers/room_controller.dart';
import '../widgets/v2_scaffold.dart';
import 'room_lobby_screen.dart';

/// Join by code — uppercase normalization, paste support, friendly invalid /
/// expired / full / started states (never a raw backend exception).
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final loc = ref.read(localizationsProvider);
    final room = await ref
        .read(roomLifecycleControllerProvider.notifier)
        .join(_controller.text);
    if (!mounted) return;
    if (room != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoomLobbyScreen()),
      );
    } else {
      final err = ref.read(roomLifecycleControllerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.errorMessage(err))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final busy = ref.watch(roomLifecycleControllerProvider).busy;

    return V2Scaffold(
      title: loc('joinRoom'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Text(
            loc('enterJoinCode'),
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            autofocus: true,
            style: AppTypography.displaySm.copyWith(
              color: AppColors.primary,
              letterSpacing: 6,
            ),
            inputFormatters: [
              // Uppercase normalization + alnum only.
              TextInputFormatter.withFunction(
                (oldV, newV) => newV.copyWith(
                  text: newV.text.toUpperCase().replaceAll(
                    RegExp(r'[^A-Z0-9]'),
                    '',
                  ),
                ),
              ),
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              hintText: 'ABCD12',
              hintStyle: AppTypography.displaySm.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                letterSpacing: 6,
              ),
              filled: true,
              fillColor: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.amber, width: 2),
              ),
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 24),
          GlowButton(
            label: loc('joinRoom'),
            icon: Icons.login,
            busy: busy,
            onTap: _join,
          ),
        ],
      ),
    );
  }
}
