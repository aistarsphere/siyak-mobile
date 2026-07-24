// Barrel for the TEST-ONLY in-memory V2 mock layer. The shipped app is
// remote-only (no mock data path); tests import these classes and override the
// repository providers directly (the abstract interfaces are the swap seam).
export 'mock_fixtures.dart';
export 'mock_realtime_gateway.dart';
export 'mock_repositories.dart';
export 'mock_room_repository.dart';
