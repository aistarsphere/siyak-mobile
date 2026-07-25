import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

enum FirebaseBootstrapFailureCode {
  timeout,
  initializationFailed,
  unsupportedPlatform,
}

class FirebaseBootstrapFailure {
  const FirebaseBootstrapFailure({
    required this.code,
    required this.exceptionType,
  });

  final FirebaseBootstrapFailureCode code;
  final String exceptionType;
}

sealed class FirebaseBootstrapResult {
  const FirebaseBootstrapResult();

  bool get isAvailable => this is FirebaseAvailable;
}

class FirebaseAvailable extends FirebaseBootstrapResult {
  const FirebaseAvailable(this.app);

  final FirebaseApp app;
}

class FirebaseUnavailable extends FirebaseBootstrapResult {
  const FirebaseUnavailable(this.failure);

  final FirebaseBootstrapFailure failure;
}

Future<FirebaseApp> Function()? _firebaseInitializerOverride;
Future<FirebaseBootstrapResult>? _bootstrapFuture;

final firebaseBootstrapResultProvider = Provider<FirebaseBootstrapResult>(
  (ref) => const FirebaseUnavailable(
    FirebaseBootstrapFailure(
      code: FirebaseBootstrapFailureCode.initializationFailed,
      exceptionType: 'not_initialized',
    ),
  ),
);

Future<FirebaseBootstrapResult> ensureFirebaseBootstrapped() {
  final cached = _bootstrapFuture;
  if (cached != null) return cached;
  final future = _bootstrap().then<FirebaseBootstrapResult>((result) => result);
  _bootstrapFuture = future;
  return future;
}

Future<FirebaseBootstrapResult> _bootstrap() async {
  if (Firebase.apps.isNotEmpty) {
    return FirebaseAvailable(Firebase.app());
  }
  try {
    final app =
        await (_firebaseInitializerOverride?.call() ??
                Firebase.initializeApp(
                  options: DefaultFirebaseOptions.currentPlatform,
                ))
            .timeout(const Duration(seconds: 10));
    if (kDebugMode) {
      debugPrint('[Firebase] initialized');
    }
    return FirebaseAvailable(app);
  } on UnsupportedError catch (e, st) {
    _reportBootstrapError(e, st);
    return FirebaseUnavailable(
      FirebaseBootstrapFailure(
        code: FirebaseBootstrapFailureCode.unsupportedPlatform,
        exceptionType: e.runtimeType.toString(),
      ),
    );
  } on TimeoutException catch (e, st) {
    _reportBootstrapError(e, st);
    return FirebaseUnavailable(
      FirebaseBootstrapFailure(
        code: FirebaseBootstrapFailureCode.timeout,
        exceptionType: e.runtimeType.toString(),
      ),
    );
  } catch (e, st) {
    _reportBootstrapError(e, st);
    return FirebaseUnavailable(
      FirebaseBootstrapFailure(
        code: FirebaseBootstrapFailureCode.initializationFailed,
        exceptionType: e.runtimeType.toString(),
      ),
    );
  }
}

void _reportBootstrapError(Object error, StackTrace st) {
  if (!kDebugMode) return;
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: st,
      library: 'firebase_bootstrap',
      context: ErrorDescription('Firebase initialization failed'),
    ),
  );
}

@visibleForTesting
void resetFirebaseBootstrapForTest({
  Future<FirebaseApp> Function()? initializerOverride,
}) {
  _bootstrapFuture = null;
  _firebaseInitializerOverride = initializerOverride;
}
