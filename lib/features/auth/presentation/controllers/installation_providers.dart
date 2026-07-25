import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../v2/presentation/controllers/v2_providers.dart';
import '../../data/remote/remote_installation_repository.dart';
import '../../domain/repositories/installation_repository.dart';

/// Live installation repository over the shared V2 REST client. Used to send the
/// FCM token to the backend (`/installations/push/*`) and attach/detach the
/// installation on login/logout.
final installationRepositoryProvider = Provider<InstallationRepository>(
  (ref) => RemoteInstallationRepository(ref.watch(v2ApiClientProvider)),
);
