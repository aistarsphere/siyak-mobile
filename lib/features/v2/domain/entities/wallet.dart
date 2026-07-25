/// A single immutable ledger entry (contract §5).
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    this.availableAfter,
    this.description,
    this.createdAt,
  });

  final String id;

  /// Signed delta on the available balance (+earn / −spend).
  final int amount;

  /// e.g. `signup_bonus`, `hint_spend`, `ranked_entry`, `ranked_payout`.
  final String type;
  final int? availableAfter;
  final String? description;
  final DateTime? createdAt;
}

/// Coin wallet snapshot (contract §5). Balances are derived from the ledger.
class Wallet {
  const Wallet({
    required this.availableBalance,
    this.reservedBalance = 0,
    this.blocked = false,
    this.currency = 'COIN',
    this.recentTransactions = const [],
  });

  /// Spendable coins.
  final int availableBalance;

  /// Held for an in-flight ranked entry (not spendable).
  final int reservedBalance;
  final bool blocked;
  final String currency;
  final List<WalletTransaction> recentTransactions;

  int get totalBalance => availableBalance + reservedBalance;
}
