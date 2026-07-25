import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/remote_wallet_repository.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import 'v2_providers.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => RemoteWalletRepository(ref.watch(v2ApiClientProvider)),
);

/// Current coin wallet. `null` when there is no registered profile yet or on a
/// transient error — the UI renders a dash rather than failing. Refreshed after
/// coin-affecting actions (hint spend, ranked entry/payout).
class WalletController extends AsyncNotifier<Wallet?> {
  @override
  Future<Wallet?> build() => _load();

  Future<Wallet?> _load() async {
    try {
      return await ref.read(walletRepositoryProvider).getWallet();
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }
}

final walletControllerProvider =
    AsyncNotifierProvider<WalletController, Wallet?>(WalletController.new);
