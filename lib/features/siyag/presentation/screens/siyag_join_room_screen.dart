import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../siyag_route.dart';
import 'siyag_room_lobby_screen.dart';

/// Join Game by code (uppercase-normalized). Shows friendly loading and
/// not-found/full/expired states inline — never a raw API error.
///
/// Built from the Siyaq design system. The join call, error mapping and
/// navigation are unchanged from the pre-migration implementation.
class SiyagJoinRoomScreen extends ConsumerStatefulWidget {
  const SiyagJoinRoomScreen({super.key});

  @override
  ConsumerState<SiyagJoinRoomScreen> createState() => _S();
}

class _S extends ConsumerState<SiyagJoinRoomScreen> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _c.text.trim();
    if (code.isEmpty) return;
    setState(() => _error = null);
    final loc = ref.read(localizationsProvider);
    final room = await ref
        .read(roomLifecycleControllerProvider.notifier)
        .join(code);
    if (!mounted) return;
    if (room != null) {
      Navigator.of(
        context,
      ).pushReplacement(siyagRoute(const SiyagRoomLobbyScreen()));
    } else {
      final err = ref.read(roomLifecycleControllerProvider).error;
      setState(
        () => _error = err != null
            ? loc.errorMessage(err)
            : loc('gameNotFoundBody'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final busy = ref.watch(roomLifecycleControllerProvider).busy;
    final canJoin = _c.text.trim().isNotEmpty && !busy;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyaqScreenHeader(
                kicker: loc('joinRoom'),
                accent: c.info,
                onBack: () => Navigator.of(context).maybePop(),
                backLabel: loc('back'),
                padding: const EdgeInsets.fromLTRB(
                  SiyaqSpacing.xl,
                  SiyaqSpacing.md,
                  SiyaqSpacing.xl,
                  SiyaqSpacing.sm,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    SiyaqSpacing.xl,
                    SiyaqSpacing.xxl,
                    SiyaqSpacing.xl,
                    SiyaqSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SiyaqCodeField(
                        controller: _c,
                        label: loc('enterGameCode'),
                        semanticLabel: loc('enterGameCode'),
                        enabled: !busy,
                        accent: c.info,
                        errorText: busy ? null : _error,
                        onChanged: (_) {
                          // Clears the stale error and refreshes the Join
                          // enabled state — same contract as before.
                          setState(() => _error = null);
                        },
                        onSubmitted: (_) => _join(),
                      ),
                      if (busy) ...[
                        const SizedBox(height: SiyaqSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: SiyaqIconSize.sm,
                              height: SiyaqIconSize.sm,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.info,
                              ),
                            ),
                            const SizedBox(width: SiyaqSpacing.smd),
                            Flexible(
                              child: SiyaqText(
                                loc('searchingGame'),
                                role: SiyaqTextRole.bodySmall,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SiyaqSpacing.xl,
                  SiyaqSpacing.sm,
                  SiyaqSpacing.xl,
                  SiyaqSpacing.xxl,
                ),
                child: SiyaqButton(
                  label: loc('join'),
                  icon: SiyaqIcons.signIn,
                  accent: c.info,
                  fullWidth: true,
                  loading: busy,
                  onPressed: canJoin ? _join : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
