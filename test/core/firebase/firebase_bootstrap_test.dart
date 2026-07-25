import 'dart:async';

import 'package:context_game/core/firebase/firebase_bootstrap.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFirebaseApp implements FirebaseApp {
  @override
  String get name => 'fake';

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'key',
    appId: 'app',
    messagingSenderId: 'sender',
    projectId: 'project',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    resetFirebaseBootstrapForTest();
  });

  test('Firebase bootstrap is single-flight', () async {
    final completer = Completer<FirebaseApp>();
    var calls = 0;
    resetFirebaseBootstrapForTest(
      initializerOverride: () {
        calls++;
        return completer.future;
      },
    );

    final first = ensureFirebaseBootstrapped();
    final second = ensureFirebaseBootstrapped();
    expect(identical(first, second), isTrue);
    expect(calls, 1);

    completer.complete(_FakeFirebaseApp());
    final result = await first;
    expect(result, isA<FirebaseAvailable>());
    expect(calls, 1);
  });
}
