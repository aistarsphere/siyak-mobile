import 'package:context_game/features/v2/data/installation_id_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory FlutterSecureStorage stand-in (no platform channels in tests).
class _MemStorage implements FlutterSecureStorage {
  final Map<String, String> _m = {};

  @override
  Future<String?> read({
    required String key,
    /* ignored */ dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async => _m[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    if (value == null) {
      _m.remove(key);
    } else {
      _m[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async => _m.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('InstallationIdStore', () {
    test('generates a UUID v4 on first launch and persists it', () async {
      final store = InstallationIdStore(storage: _MemStorage());
      final id = await store.getOrCreate();
      expect(
        _uuidV4.hasMatch(id),
        isTrue,
        reason: 'must be a random UUID v4, not a hardware identifier',
      );
      // Idempotent: same id on subsequent calls.
      expect(await store.getOrCreate(), id);
      expect(await store.peek(), id);
    });

    test('regenerates after clear (honest reinstall behaviour)', () async {
      final store = InstallationIdStore(storage: _MemStorage());
      final first = await store.getOrCreate();
      await store.clear();
      final second = await store.getOrCreate();
      expect(second, isNot(first));
      expect(_uuidV4.hasMatch(second), isTrue);
    });
  });
}
