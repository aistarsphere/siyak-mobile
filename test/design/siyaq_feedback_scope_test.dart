import 'package:context_game/core/design/siyaq_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the design system's feedback gate: DS widgets fire sound/haptics only
/// when the *player's* settings allow it, and degrade to the old behavior when
/// no scope is installed.
void main() {
  /// A control that has **opted in** to feedback.
  ///
  /// `SiyaqPressable` defaults to silent (beta feel pass — feedback on every
  /// pressable made a single guess fire twice and menus buzz constantly), so
  /// the scope-gating tests below opt in explicitly. The default itself is
  /// pinned by its own test at the end of this file.
  Widget host({
    SiyaqFeedback? feedback,
    required VoidCallback onTap,
    bool wants = true,
  }) {
    final button = SiyaqPressable(
      onTap: onTap,
      semanticLabel: 'go',
      haptics: wants,
      sound: wants,
      builder: (context, state) => const SizedBox(
        width: 60,
        height: 60,
        child: ColoredBox(color: Color(0xFF888888)),
      ),
    );
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: feedback == null
              ? button
              : SiyaqFeedbackScope(feedback: feedback, child: button),
        ),
      ),
    );
  }

  /// Counts haptic invocations through the platform channel.
  int hapticCalls = 0;
  setUp(() {
    hapticCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') hapticCalls++;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('tap plays the primaryTap sound when sound is enabled', (
    t,
  ) async {
    final played = <SiyaqSoundEvent>[];
    await t.pumpWidget(
      host(
        feedback: SiyaqFeedback(
          soundEnabled: true,
          hapticsEnabled: true,
          play: played.add,
        ),
        onTap: () {},
      ),
    );
    await t.tap(find.bySemanticsLabel('go'));
    await t.pumpAndSettle();

    expect(played, [SiyaqSoundEvent.primaryTap]);
    expect(hapticCalls, 1);
  });

  testWidgets('sound disabled → no sound, haptics still fire', (t) async {
    final played = <SiyaqSoundEvent>[];
    await t.pumpWidget(
      host(
        feedback: SiyaqFeedback(
          soundEnabled: false,
          hapticsEnabled: true,
          play: played.add,
        ),
        onTap: () {},
      ),
    );
    await t.tap(find.bySemanticsLabel('go'));
    await t.pumpAndSettle();

    expect(played, isEmpty);
    expect(hapticCalls, 1);
  });

  testWidgets('haptics disabled → silent press, tap still lands', (t) async {
    var taps = 0;
    await t.pumpWidget(
      host(
        feedback: const SiyaqFeedback(
          soundEnabled: false,
          hapticsEnabled: false,
        ),
        onTap: () => taps++,
      ),
    );
    await t.tap(find.bySemanticsLabel('go'));
    await t.pumpAndSettle();

    expect(taps, 1);
    expect(hapticCalls, 0);
  });

  testWidgets('no scope installed → haptics as before, sound a no-op', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(host(onTap: () => taps++));
    await t.tap(find.bySemanticsLabel('go'));
    await t.pumpAndSettle();

    // SiyaqFeedback.none: hapticsEnabled defaults true (pre-sound behavior),
    // play is null.
    expect(taps, 1);
    expect(hapticCalls, 1);
  });

  testWidgets('an ordinary pressable is silent by default', (t) async {
    // The beta feel pass inverted these defaults. A row, chip, tile or nav tab
    // must not buzz or click just for being tapped; only controls that commit
    // something opt in.
    final played = <SiyaqSoundEvent>[];
    var taps = 0;
    await t.pumpWidget(
      host(
        wants: false,
        feedback: SiyaqFeedback(
          soundEnabled: true,
          hapticsEnabled: true,
          play: played.add,
        ),
        onTap: () => taps++,
      ),
    );
    await t.tap(find.bySemanticsLabel('go'));
    await t.pumpAndSettle();

    expect(taps, 1, reason: 'the tap itself must still land');
    expect(played, isEmpty, reason: 'no sound for an ordinary control');
    expect(hapticCalls, 0, reason: 'no haptic for an ordinary control');
  });

  testWidgets('the primary button still ticks, a ghost button does not', (
    t,
  ) async {
    final played = <SiyaqSoundEvent>[];
    await t.pumpWidget(
      MaterialApp(
        home: SiyaqFeedbackScope(
          feedback: SiyaqFeedback(
            soundEnabled: true,
            hapticsEnabled: true,
            play: played.add,
          ),
          child: Scaffold(
            body: Column(
              children: [
                SiyaqButton(label: 'commit', onPressed: () {}),
                SiyaqButton(
                  label: 'browse',
                  type: SiyaqButtonType.ghost,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await t.tap(find.text('commit'));
    await t.pumpAndSettle();
    expect(played, [SiyaqSoundEvent.primaryTap]);
    expect(hapticCalls, 1);

    await t.tap(find.text('browse'));
    await t.pumpAndSettle();
    expect(played, [SiyaqSoundEvent.primaryTap], reason: 'ghost adds nothing');
    expect(hapticCalls, 1);
  });
}
