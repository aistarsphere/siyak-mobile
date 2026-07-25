import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../v2/presentation/controllers/v2_providers.dart';
import '../../data/google_auth_gateway_impl.dart';
import '../../data/remote/remote_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';

/// Platform Google gateway (mints an ID token for the backend audience).
final googleAuthGatewayProvider = Provider<GoogleAuthGateway>(
  (ref) => RealGoogleAuthGateway(),
);

/// Live account-auth repository over the shared V2 REST client.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => RemoteAuthRepository(ref.watch(v2ApiClientProvider)),
);
