import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../siyag_route.dart';
import 'siyag_room_lobby_screen.dart';
import 'siyag_topbar.dart';

/// Join by code (missing flow, in-grammar): uppercase-normalized code entry.
class SiyagJoinRoomScreen extends ConsumerStatefulWidget {
  const SiyagJoinRoomScreen({super.key});

  @override
  ConsumerState<SiyagJoinRoomScreen> createState() => _S();
}

class _S extends ConsumerState<SiyagJoinRoomScreen> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final room =
        await ref.read(roomLifecycleControllerProvider.notifier).join(_c.text);
    if (!mounted) return;
    if (room != null) {
      Navigator.of(context)
          .pushReplacement(siyagRoute(const SiyagRoomLobbyScreen()));
    } else {
      final err = ref.read(roomLifecycleControllerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(ref.read(localizationsProvider).errorMessage(err))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(roomLifecycleControllerProvider).busy;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyagTopBar(kicker: 'Join by code', kickerColor: SC.cyan),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text('أدخل رمز الغرفة',
                              style: ST.ar(13, color: SC.textDim))),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _c,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          TextInputFormatter.withFunction((o, n) => n.copyWith(
                              text: n.text
                                  .toUpperCase()
                                  .replaceAll(RegExp(r'[^A-Z0-9]'), ''))),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        style: ST.mono(30, letterSpacing: 8),
                        decoration: InputDecoration(
                          hintText: 'ABCD12',
                          hintStyle:
                              ST.mono(30, color: SC.textFaint, letterSpacing: 8),
                          filled: true,
                          fillColor: SC.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: SC.cyan, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _join(),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SiyagPrimaryButton(
                  label: 'انضمام',
                  color: SC.cyan,
                  icon: Icons.login_rounded,
                  busy: busy,
                  onTap: _join,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
