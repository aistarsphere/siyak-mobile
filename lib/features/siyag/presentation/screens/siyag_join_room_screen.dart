import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/theme/context_tokens.dart';
import '../../../../core/design/theme/legacy_type_bridge.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../siyag_route.dart';
import 'siyag_room_lobby_screen.dart';
import 'siyag_topbar.dart';

/// Join Game by code (uppercase-normalized). Shows friendly loading + not-found/
/// full/expired states inline (never a raw API error). Localized, direction-aware.
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
    final busy = ref.watch(roomLifecycleControllerProvider).busy;
    final canJoin = _c.text.trim().isNotEmpty && !busy;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyagTopBar(
                kicker: loc('joinRoom'),
                kickerColor: context.colors.info,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          loc('enterGameCode'),
                          style: context.legacyType.ar(
                            13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _c,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        enabled: !busy,
                        inputFormatters: [
                          TextInputFormatter.withFunction(
                            (o, n) => n.copyWith(
                              text: n.text.toUpperCase().replaceAll(
                                RegExp(r'[^A-Z0-9]'),
                                '',
                              ),
                            ),
                          ),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        style: context.legacyType.mono(30, letterSpacing: 8),
                        decoration: InputDecoration(
                          hintText: 'ABCD',
                          hintStyle: context.legacyType.mono(
                            30,
                            color: context.colors.textDisabled,
                            letterSpacing: 8,
                          ),
                          filled: true,
                          fillColor: context.colors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: context.colors.info,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                          setState(() {}); // refresh Join enabled state
                        },
                        onSubmitted: (_) => _join(),
                      ),
                      const SizedBox(height: 16),
                      // Loading / error states — never a raw API error.
                      if (busy)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.info,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              loc('searchingGame'),
                              style: context.legacyType.ar(
                                13,
                                color: context.colors.textMuted,
                              ),
                            ),
                          ],
                        )
                      else if (_error != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: context.colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: context.legacyType.ar(
                                  13,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SiyagPrimaryButton(
                  label: loc('join'),
                  color: context.colors.info,
                  icon: Icons.login_rounded,
                  busy: busy,
                  onTap: canJoin ? _join : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
