#!/usr/bin/env python3
"""Static navigation and user-journey audit for the full GiveChain app."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'
router_path = LIB / 'core/router/app_router.dart'
router = router_path.read_text(encoding='utf-8')
errors: list[str] = []

expected_routes = {
    # No '/splash': the router boots straight into '/home' or '/welcome'
    # (see GoRouter.initialLocation); there is no SplashScreen in the app.
    '/welcome': 'WelcomeScreen',
    '/login': 'LoginScreen',
    '/signup': 'SignUpScreen',
    '/forgot-password': 'ForgotPasswordScreen',
    '/reset-password': 'ResetPasswordScreen',
    '/home': 'HomeShell',
    '/campaigns': 'CatalogListScreen',
    '/cases': 'CatalogListScreen',
    '/charities': 'CharitiesScreen',
    '/campaigns/:id': 'CatalogDetailScreen',
    '/cases/:id': 'CatalogDetailScreen',
    '/charities/:id': 'CharityDetailScreen',
    '/charities/:id/campaigns': 'CharityCatalogScreen',
    '/charities/:id/cases': 'CharityCatalogScreen',
    '/charities/:id/benefits': 'CharityBenefitTypesScreen',
    '/charities/:charityId/benefits/:benefitTypeId/apply': 'BenefitApplicationScreen',
    '/charities/:id/complaint': 'CreateComplaintScreen',
    '/campaigns/:id/donate': 'DonationEntryScreen',
    '/cases/:id/donate': 'DonationEntryScreen',
    # '/donate/direct' is a legacy deep link kept only as a redirect to /home;
    # there is no DirectDonationScreen. Direct (general-endpoint) donations go
    # through '/donate' with DonationRouteData.useGeneralEndpoint.
    '/donate': 'DonationScreen',
    '/donation-result': 'DonationResultScreen',
    '/donations/history': 'DonationHistoryScreen',
    '/donations/trace': 'FundTraceScreen',
    '/donations/:id/detail': 'DonationDetailScreen',
    '/donations/:id/trace': 'FundTraceScreen',
    '/benefits/my': 'MyBenefitsScreen',
    '/benefits/:id': 'BenefitRequestDetailScreen',
    '/complaints/my': 'MyComplaintsScreen',
    '/complaints/:id': 'ComplaintDetailScreen',
    '/notifications': 'NotificationsScreen',
    '/notifications/detail': 'NotificationDetailScreen',
    '/profile': 'ProfileScreen',
    '/profile/edit': 'EditProfileScreen',
    '/profile/info-answers': 'InfoAnswersScreen',
    '/profile/change-password': 'ChangePasswordScreen',
    '/media-gallery': 'MediaGalleryScreen',
    '/media/manage': 'MediaManagerScreen',
    '/about': 'AboutScreen',
    '/c/:subdomain': 'CharitySubdomainScreen',
    '/developer/backend-diagnostics': 'BackendDiagnosticsScreen',
}

for route, widget in expected_routes.items():
    if f"path: '{route}'" not in router:
        errors.append(f'Missing route: {route}')
    if widget not in router:
        errors.append(f'Route widget not referenced: {widget}')

for pattern, key in {
    '/campaigns/:id': 'id',
    '/cases/:id': 'id',
    '/charities/:id': 'id',
    '/charities/:id/campaigns': 'id',
    '/charities/:id/cases': 'id',
    '/charities/:charityId/benefits/:benefitTypeId/apply': 'charityId',
    '/donations/:id/detail': 'id',
    '/donations/:id/trace': 'id',
    '/benefits/:id': 'id',
    '/complaints/:id': 'id',
    '/c/:subdomain': 'subdomain',
}.items():
    start = router.find(f"path: '{pattern}'")
    block = router[start:start + 1200]
    if f"state.pathParameters['{key}']" not in block:
        errors.append(f'Dynamic route does not read {key}: {pattern}')

# Public browse and protected actions must match the product guide.
public_paths = ('/home', '/campaigns', '/cases', '/charities', '/about', '/c/')
for public in public_paths:
    if public in ('/about', '/c/'):
        continue
    if re.search(rf"path\.startsWith\('{re.escape(public)}'\)", router):
        errors.append(f'Public route appears auth-gated: {public}')

required_auth_fragments = (
    "path.startsWith('/notifications')",
    "path.startsWith('/profile')",
    "path.contains('/donate')",
    "path.startsWith('/donations')",
    "path.startsWith('/benefits')",
    "path.startsWith('/complaints')",
    "path.startsWith('/media/manage')",
)
for fragment in required_auth_fragments:
    if fragment not in router:
        errors.append(f'Missing auth gate: {fragment}')

# All static literal navigation destinations must map to a declared path or a
# known parameterized family.
declared = set(re.findall(r"path:\s*'([^']+)'", router))
parameterized_prefixes = {
    route.split('/:')[0] for route in declared if '/:' in route
}
for path in LIB.rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    for target in re.findall(r"context\.(?:push|go)(?:<[^>]+>)?\(\s*'(/[^'$]*)'", text):
        if target in declared:
            continue
        if any(target == prefix or target.startswith(prefix + '/') for prefix in parameterized_prefixes):
            continue
        errors.append(f'Undeclared static navigation target {target} in {path.relative_to(LIB)}')

# Key end-to-end journey bindings.
journeys = {
    'guest browsing': ('features/onboarding/ui/start_screens.dart', "context.go('/home')"),
    'login continuation': ('features/login/ui/login_screen.dart', 'PendingRouteStorage.consume'),
    'campaign donation': ('features/catalog/ui/catalog_detail_screen.dart', '/donate'),
    'direct charity donation': ('features/charities/ui/charity_detail_screen.dart', 'targetType: 3'),
    'transfer proof upload': ('features/donations/ui/donation_history_screen.dart', '_uploadProof'),
    'single trace': ('features/donations/ui/donation_history_screen.dart', '/trace'),
    'benefit application': ('features/charities/ui/charity_detail_screen.dart', '/benefits/'),
    'complaint creation': ('features/charities/ui/charity_detail_screen.dart', '/complaint?name='),
    'notification detail': ('features/notifications/ui/notifications_screen.dart', '/notifications/detail'),
    'profile edit': ('features/profile/ui/profile_screen.dart', '/profile/edit'),
    'media management': ('features/donations/ui/donation_history_screen.dart', '/media/manage'),
    'charity short link': ('features/charities/ui/charity_detail_screen.dart', 'givechain://app/c/'),
}
for journey, (relative, needle) in journeys.items():
    path = LIB / relative
    if not path.exists() or needle not in path.read_text(encoding='utf-8'):
        errors.append(f'Missing journey binding: {journey} -> {relative} :: {needle}')

if errors:
    print('FAIL: route/UI audit')
    for error in sorted(set(errors)):
        print('-', error)
    sys.exit(1)

print(f'PASS: {len(expected_routes)} routes are declared and linked to screens.')
print(f'PASS: {len(journeys)} critical user journeys have navigation bindings.')
print('PASS: public browsing is separated from authenticated actions.')
print('PASS: dynamic routes read their identifiers from the URL.')
