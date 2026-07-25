import '../entities/wallet.dart';

/// Coin wallet (contract §5). Read-only from the client — coins are earned/spent
/// server-side by gameplay (hints, ranked entry/payout); the client displays the
/// balance and refreshes after those actions.
abstract class WalletRepository {
  /// Current wallet snapshot (balance + recent transactions).
  Future<Wallet> getWallet();

  /// Paged ledger history.
  Future<List<WalletTransaction>> getTransactions({int limit = 50, int offset = 0});
}
