import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import 'v2_api_client.dart';

/// Live [WalletRepository] over the V2 REST client (contract §5).
class RemoteWalletRepository implements WalletRepository {
  RemoteWalletRepository(this._api);
  final V2ApiClient _api;

  @override
  Future<Wallet> getWallet() async => _wallet(await _api.get('/wallet'));

  @override
  Future<List<WalletTransaction>> getTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _api.get(
      '/wallet/transactions',
      query: {'limit': limit, 'offset': offset},
    );
    return _txns(res['transactions']);
  }

  static Wallet _wallet(Map<String, dynamic> j) => Wallet(
    availableBalance: (j['available_balance'] as num?)?.toInt() ?? 0,
    reservedBalance: (j['reserved_balance'] as num?)?.toInt() ?? 0,
    blocked: j['blocked'] == true,
    currency: (j['currency'] ?? 'COIN').toString(),
    recentTransactions: _txns(j['recent_transactions']),
  );

  static List<WalletTransaction> _txns(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => _txn(e.cast<String, dynamic>()))
        .toList();
  }

  static WalletTransaction _txn(Map<String, dynamic> j) => WalletTransaction(
    id: (j['txn_id'] ?? '').toString(),
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    type: (j['type'] ?? '').toString(),
    availableAfter: (j['available_after'] as num?)?.toInt(),
    description: j['description'] as String?,
    createdAt: DateTime.tryParse((j['created_at'] ?? '').toString())?.toUtc(),
  );
}
