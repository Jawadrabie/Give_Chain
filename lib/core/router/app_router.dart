import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// The original Login form fields and layout are preserved.
import '../../features/login/ui/login_screen.dart';
import '../../features/auth/ui/forgot_password_screen.dart';
import '../../features/auth/ui/reset_password_screen.dart';
import '../../features/auth/ui/signup_screen.dart';
import '../../features/benefits/data/benefit_models.dart';
import '../../features/benefits/ui/benefit_apply_screen.dart';
import '../../features/benefits/ui/benefit_screens.dart';
import '../../features/benefits/ui/benefit_detail_screen.dart';
import '../../features/catalog/data/catalog_models.dart';
import '../../features/catalog/ui/catalog_detail_screen.dart';
import '../../features/catalog/ui/catalog_list_screen.dart';
import '../../features/charities/ui/charities_screen.dart';
import '../../features/charities/ui/charity_catalog_screen.dart';
import '../../features/charities/ui/charity_detail_screen.dart';
import '../../features/complaints/data/complaint_models.dart';
import '../../features/complaints/ui/complaint_screens.dart';
import '../../features/donations/data/donation_models.dart';
import '../../features/donations/ui/donation_history_screen.dart';
import '../../features/donations/ui/donation_screen.dart';
import '../../features/donations/ui/qr_scanner_screen.dart';
import '../../features/help_request/ui/benefit_charity_picker_screen.dart';
import '../../features/help_request/ui/request_help_screen.dart';

import '../../features/diagnostics/backend_diagnostics_screen.dart';
import '../../features/home/ui/home_shell.dart';
import '../../features/media/ui/media_gallery_screen.dart';
import '../../features/media/ui/media_manager_screen.dart';
import '../../features/notifications/data/notification_models.dart';
import '../../features/notifications/ui/notification_detail_screen.dart';
import '../../features/notifications/ui/notifications_screen.dart';
import '../../features/onboarding/ui/start_screens.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/ui/edit_profile_screen.dart';
import '../../features/profile/ui/info_answers_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/system/ui/about_screen.dart';
import '../../features/system/ui/charity_subdomain_screen.dart';
import '../session/session_controller.dart';
import '../storage/pending_route_storage.dart';
import '../storage/token_storage.dart';
import '../widgets/app_back_app_bar.dart';

abstract final class AppRouter {
  static const _authRoutes = <String>{
    '/login',
    '/loginScreen',
    '/signup',
    '/signUpScreen',
    '/signupScreen',
    '/welcome',
    '/welcomeScreen',
    '/onBoardingScreen',
  };

  static bool _requiresAuthentication(String path) {
    if (path.startsWith('/notifications') || path.startsWith('/profile')) {
      return true;
    }
    if (path == '/donate' || path.contains('/donate')) return true;
    if (path.startsWith('/donations')) return true;
    if (path.startsWith('/benefits')) return true;
    if (path.contains('/benefits/') && path.endsWith('/apply')) return true;
    // The help flow ends in a benefit application, so it needs a session for
    // the same reason — asked for at the entrance rather than after the user
    // has already picked a benefit and a charity.
    if (path == '/request-help' || path.startsWith('/help/')) return true;
    if (path.startsWith('/complaints') || path.endsWith('/complaint')) {
      return true;
    }
    if (path.startsWith('/media/manage')) return true;
    if (path.startsWith('/developer/')) return true;
    return false;
  }

  static final router = GoRouter(
    initialLocation: TokenStorage.hasSession ? '/home' : '/welcome',
    refreshListenable: SessionController.instance,
    redirect: (context, state) async {
      final path = state.uri.path;
      if (_requiresAuthentication(path) && !TokenStorage.hasSession) {
        await TokenStorage.synchronize();
        if (!TokenStorage.hasSession) {
          await PendingRouteStorage.save(state.uri.toString());
          return '/login';
        }
      }
      if (TokenStorage.hasSession && _authRoutes.contains(path)) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) => TokenStorage.hasSession ? '/home' : '/welcome',
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcomeScreen',
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(path: '/welcomeScreen', redirect: (_, _) => '/welcome'),
      GoRoute(path: '/onBoardingScreen', redirect: (_, _) => '/welcome'),
      GoRoute(
        path: '/login',
        name: 'loginScreen',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(path: '/loginScreen', redirect: (_, _) => '/login'),
      GoRoute(
        path: '/signup',
        name: 'signUpScreen',
        builder: (_, _) => const SignUpScreen(),
      ),
      GoRoute(path: '/signUpScreen', redirect: (_, _) => '/signup'),
      GoRoute(path: '/signupScreen', redirect: (_, _) => '/signup'),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPasswordScreen',
        builder: (_, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'] ?? '',
          initialToken: state.uri.queryParameters['code'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'resetPasswordScreen',
        builder: (_, state) => ResetPasswordScreen(
          initialEmail: state.uri.queryParameters['email'] ?? '',
          initialCode: state.uri.queryParameters['code'] ?? '',
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'homeScreen',
        builder: (_, _) => const HomeShell(),
      ),
      GoRoute(path: '/homeScreen', redirect: (_, _) => '/home'),
      GoRoute(
        path: '/request-help',
        builder: (_, _) => const RequestHelpScreen(),
      ),
      // Step 2 of the need-first flow. The offering carries its charities and
      // their questions, so it travels as `extra` rather than being refetched;
      // reaching this route directly (a deep link, say) has nothing to show
      // and is sent back to the start of the flow.
      GoRoute(
        path: '/help/offering',
        builder: (_, state) => state.extra is BenefitOffering
            ? BenefitCharityPickerScreen(
                offering: state.extra as BenefitOffering,
              )
            : const _RouteErrorScreen(
                message: 'اختر نوع المساعدة أولاً.',
              ),
      ),
      GoRoute(
        path: '/campaigns',
        name: 'campaignsScreen',
        builder: (_, _) =>
            const CatalogListScreen(kind: CatalogKind.campaigns),
      ),
      GoRoute(path: '/campaignsScreen', redirect: (_, _) => '/campaigns'),
      GoRoute(
        path: '/cases',
        name: 'casesScreen',
        builder: (_, _) => const CatalogListScreen(kind: CatalogKind.cases),
      ),
      GoRoute(path: '/casesScreen', redirect: (_, _) => '/cases'),
      GoRoute(
        path: '/charities',
        name: 'charitiesScreen',
        builder: (_, _) => const CharitiesScreen(),
      ),
      GoRoute(path: '/charitiesScreen', redirect: (_, _) => '/charities'),
      GoRoute(
        path: '/campaigns/:id',
        name: 'campaignDetailsScreen',
        builder: (_, state) => CatalogDetailScreen(
          id: state.pathParameters['id']!,
          kind: CatalogKind.campaigns,
          fallback: state.extra is CatalogItem
              ? state.extra as CatalogItem
              : null,
        ),
      ),
      GoRoute(
        path: '/cases/:id',
        name: 'caseDetailsScreen',
        builder: (_, state) => CatalogDetailScreen(
          id: state.pathParameters['id']!,
          kind: CatalogKind.cases,
          fallback: state.extra is CatalogItem
              ? state.extra as CatalogItem
              : null,
        ),
      ),
      GoRoute(
        path: '/charities/:id',
        name: 'charityDetailsScreen',
        builder: (_, state) => CharityDetailScreen(
          id: state.pathParameters['id']!,
          fallback: state.extra is Charity ? state.extra as Charity : null,
        ),
      ),
      GoRoute(
        path: '/charities/:id/campaigns',
        builder: (_, state) => CharityCatalogScreen(
          charityId: state.pathParameters['id']!,
          campaigns: true,
          charityName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/charities/:id/cases',
        builder: (_, state) => CharityCatalogScreen(
          charityId: state.pathParameters['id']!,
          campaigns: false,
          charityName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/charities/:id/benefits',
        builder: (_, state) => CharityBenefitTypesScreen(
          charityId: state.pathParameters['id']!,
          charityName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/charities/:charityId/benefits/:benefitTypeId',
        builder: (_, state) => BenefitDetailScreen(
          charityId: state.pathParameters['charityId']!,
          benefitType: state.extra as BenefitType,
        ),
      ),
      GoRoute(
        path: '/charities/:charityId/benefits/:benefitTypeId/apply',
        builder: (_, state) => BenefitApplyScreen(
          initialCharityId: state.pathParameters['charityId']!,
          charityName: state.uri.queryParameters['name'] ?? '',
          initialBenefitType: state.extra is BenefitType
              ? state.extra as BenefitType
              : null,
        ),
      ),
      GoRoute(
        path: '/charities/:id/complaint',
        builder: (_, state) => CreateComplaintScreen(
          charityId: state.pathParameters['id']!,
          charityName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/campaigns/:id/donate',
        builder: (_, state) => DonationEntryScreen(
          id: state.pathParameters['id']!,
          isCampaign: true,
        ),
      ),
      GoRoute(
        path: '/cases/:id/donate',
        builder: (_, state) => DonationEntryScreen(
          id: state.pathParameters['id']!,
          isCampaign: false,
        ),
      ),
      GoRoute(path: '/donate/direct', redirect: (_, _) => '/home'),
      GoRoute(
        path: '/donate',
        builder: (_, state) {
          final data = state.extra;
          return data is DonationRouteData
              ? DonationScreen(data: data)
              : const _RouteErrorScreen(
                  message: 'اختر حملة أو حالة قبل بدء التبرع.',
                );
        },
      ),
      GoRoute(
        path: '/donation-result',
        builder: (_, state) {
          final extra = state.extra;
          final response = extra is DonationResponse
              ? extra
              : state.uri.queryParameters.isEmpty
              ? null
              : DonationResponse.fromQuery(state.uri.queryParameters);
          return DonationResultScreen(response: response);
        },
      ),
      GoRoute(
        path: '/donations/history',
        builder: (_, _) => const DonationHistoryScreen(),
      ),
      GoRoute(
        path: '/donations/trace',
        builder: (_, _) => const FundTraceScreen(),
      ),
      GoRoute(
        path: '/donations/:id/detail',
        builder: (_, state) => DonationDetailScreen(
          id: state.pathParameters['id']!,
          initial: state.extra is DonationResponse
              ? state.extra as DonationResponse
              : null,
        ),
      ),
      GoRoute(
        path: '/donations/:id/trace',
        builder: (_, state) =>
            FundTraceScreen(donationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (_, _) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/benefits/my',
        builder: (_, _) => const MyBenefitsScreen(),
      ),
      // Declared before '/benefits/:id' so the literal segment wins; the
      // parameterised route would otherwise swallow "apply" as an id.
      GoRoute(
        path: '/benefits/apply',
        builder: (_, state) => BenefitApplyScreen(
          initialCharityId: state.uri.queryParameters['charityId'] ?? '',
          charityName: state.uri.queryParameters['name'] ?? '',
          initialBenefitType: state.extra is BenefitType
              ? state.extra as BenefitType
              : null,
        ),
      ),
      GoRoute(
        path: '/benefits/:id',
        builder: (_, state) => BenefitRequestDetailScreen(
          id: state.pathParameters['id']!,
          initial: state.extra is BenefitRequest
              ? state.extra as BenefitRequest
              : null,
        ),
      ),
      GoRoute(
        path: '/complaints/my',
        builder: (_, _) => const MyComplaintsScreen(),
      ),
      // No charity in the path: files the complaint against the platform.
      GoRoute(
        path: '/complaints/new',
        builder: (_, _) => const CreateComplaintScreen(),
      ),
      GoRoute(
        path: '/complaints/:id',
        builder: (_, state) => ComplaintDetailScreen(
          id: state.pathParameters['id']!,
          initial: state.extra is Complaint ? state.extra as Complaint : null,
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => Scaffold(
          appBar: const AppBackAppBar(title: Text('حسابي')),
          body: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, state) => EditProfileScreen(
          profile: state.extra is UserProfile
              ? state.extra as UserProfile
              : null,
        ),
      ),
      GoRoute(
        path: '/profile/info-answers',
        builder: (_, _) => const InfoAnswersScreen(),
      ),
      GoRoute(
        path: '/notifications/detail',
        builder: (_, state) => state.extra is AppNotification
            ? NotificationDetailScreen(
                notification: state.extra! as AppNotification,
              )
            : const _RouteErrorScreen(message: 'بيانات الإشعار غير متاحة.'),
      ),
      GoRoute(
        path: '/media-gallery',
        builder: (_, state) => state.extra is MediaGalleryArgs
            ? MediaGalleryScreen(args: state.extra! as MediaGalleryArgs)
            : const _RouteErrorScreen(message: 'لا توجد وسائط للعرض.'),
      ),
      GoRoute(
        path: '/media/manage',
        builder: (_, state) => state.extra is MediaManagerArgs
            ? MediaManagerScreen(args: state.extra! as MediaManagerArgs)
            : const _RouteErrorScreen(
                message: 'بيانات مالك الوسائط غير متاحة.',
              ),
      ),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(
        path: '/c/:subdomain',
        builder: (_, state) => CharitySubdomainScreen(
          subdomain: state.pathParameters['subdomain']!,
        ),
      ),
      GoRoute(
        path: '/developer/backend-diagnostics',
        builder: (_, _) => const BackendDiagnosticsScreen(),
      ),
    ],
    errorBuilder: (_, state) =>
        _RouteErrorScreen(message: state.error.toString()),
  );
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBackAppBar(title: Text('خطأ في المسار')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
