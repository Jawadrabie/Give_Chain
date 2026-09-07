import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/cache/api_response_cache.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/theme_controller.dart';
import 'features/benefits/data/benefit_request_store.dart';
import 'features/donations/data/donation_history_store.dart';
import 'give_chain_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const GiveChainBlocObserver();

  await ThemeController.initialize();
  await TokenStorage.initialize();
  await ApiResponseCache.initialize();
  ApiClient.initialize();
  await NotificationService.initialize();
  final donationHistoryStore = await DonationHistoryStore.create();
  final benefitRequestStore = await BenefitRequestStore.create();

  runApp(
    GiveChainApp(
      donationHistoryStore: donationHistoryStore,
      benefitRequestStore: benefitRequestStore,
    ),
  );
}

class GiveChainBlocObserver extends BlocObserver {
  const GiveChainBlocObserver();

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    assert(() {
      debugPrint('${bloc.runtimeType}: $error');
      return true;
    }());
    super.onError(bloc, error, stackTrace);
  }
}
