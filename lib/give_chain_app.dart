import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/registration_lookup_repository.dart';
import 'features/benefits/data/benefit_repository.dart';
import 'features/benefits/data/benefit_request_store.dart';
import 'features/catalog/data/catalog_repository.dart';
import 'features/centers/data/center_repository.dart';
import 'features/complaints/data/complaint_repository.dart';
import 'features/donations/data/donation_history_store.dart';
import 'features/donations/data/donation_repository.dart';
import 'features/home/data/home_repository.dart';
import 'features/media/data/media_repository.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/system/data/system_repository.dart';

class GiveChainApp extends StatefulWidget {
  const GiveChainApp({
    super.key,
    required this.donationHistoryStore,
    required this.benefitRequestStore,
  });

  final DonationHistoryStore donationHistoryStore;
  final BenefitRequestStore benefitRequestStore;

  @override
  State<GiveChainApp> createState() => _GiveChainAppState();
}

class _GiveChainAppState extends State<GiveChainApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    ThemeController.applySystemBars(ThemeController.mode.value);
  }

  @override
  Widget build(BuildContext context) {
    final client = ApiClient.instance;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository(client)),
        RepositoryProvider(create: (_) => RegistrationLookupRepository(client)),
        RepositoryProvider(create: (_) => HomeRepository(client)),
        RepositoryProvider(create: (_) => MediaRepository(client)),
        RepositoryProvider(create: (_) => CatalogRepository(client)),
        RepositoryProvider(create: (_) => CenterRepository(client)),
        RepositoryProvider(
          create: (_) =>
              DonationRepository(client, widget.donationHistoryStore),
        ),
        RepositoryProvider(
          create: (_) => BenefitRepository(client, widget.benefitRequestStore),
        ),
        RepositoryProvider(create: (_) => ComplaintRepository(client)),
        RepositoryProvider(create: (_) => NotificationRepository(client)),
        RepositoryProvider(create: (_) => ProfileRepository(client)),
        RepositoryProvider(create: (_) => SystemRepository(client)),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.mode,
          builder: (_, mode, _) {
            ThemeController.applySystemBars(mode);
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'GiveChain',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: AppRouter.router,
            );
          },
        ),
      ),
    );
  }
}
