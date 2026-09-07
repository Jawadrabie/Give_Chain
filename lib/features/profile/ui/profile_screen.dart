import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/url_resolver.dart';
import '../../../core/state/async_state.dart';
import '../../../core/storage/pending_route_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../catalog/logic/catalog_cubits.dart';
import '../../donations/data/donation_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        DetailCubit<UserProfile>(context.read<ProfileRepository>().getProfile)
          ..load(),
    child: const _ProfileView(),
  );
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DetailCubit<UserProfile>, AsyncState<UserProfile>>(
        builder: (context, state) {
          if (state.status == AsyncStatus.loading && state.data == null) {
            return const SkeletonList(count: 4);
          }
          if (state.status == AsyncStatus.failure && state.data == null) {
            return ErrorRetry(
              message: state.message ?? 'تعذر تحميل الملف الشخصي',
              onRetry: context.read<DetailCubit<UserProfile>>().load,
            );
          }
          final profile = state.data;
          if (profile == null) return const EmptyView();
          return RefreshIndicator(
            onRefresh: context.read<DetailCubit<UserProfile>>().load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                _avatar(context, profile),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (profile.userName.isNotEmpty)
                  Text('@${profile.userName}', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                _recordsSection(context),
                const SizedBox(height: 14),
                _information(profile),
                const SizedBox(height: 14),
                _menu(context, profile),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          );
        },
      );

  Widget _avatar(BuildContext context, UserProfile profile) => Center(
    child: CircleAvatar(
      radius: 52,
      backgroundColor: AppTheme.softOf(context),
      child: profile.imageUrl.isEmpty
          ? Text(
              profile.name.trim().isEmpty
                  ? 'م'
                  : profile.name.trim().substring(0, 1),
              style: const TextStyle(
                fontSize: 35,
                color: AppTheme.primary,
                fontWeight: FontWeight.w900,
              ),
            )
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: UrlResolver.resolve(profile.imageUrl),
                width: 104,
                height: 104,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(Icons.person, size: 50),
              ),
            ),
    ),
  );

  Widget _recordsSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'سجلاتي',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.softOf(context),
                child: const Icon(Icons.receipt_long, color: AppTheme.primary),
              ),
              title: const Text(
                'تبرعاتي',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('عرض سجل تبرعاتي وحالتها'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/donations/history'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.softOf(context),
                child: const Icon(Icons.card_giftcard, color: AppTheme.primary),
              ),
              title: const Text(
                'طلب استفادة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('طلبات الاستفادة التي قدمتها'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/benefits/my'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.softOf(context),
                child: const Icon(Icons.support_agent, color: AppTheme.primary),
              ),
              title: const Text(
                'شكاوي',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('الشكاوى التي قدمتها'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/complaints/my'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.softOf(context),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.primary,
                ),
              ),
              title: const Text(
                'شكوى على المنصة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('تقديم شكوى على GiveChain نفسها'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/complaints/new'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _information(UserProfile profile) {
    final entries = <({IconData icon, String title, String value})>[
      if (profile.email.isNotEmpty)
        (icon: Icons.email_outlined, title: 'البريد', value: profile.email),
      if (profile.phoneNumber.isNotEmpty)
        (
          icon: Icons.phone_outlined,
          title: 'رقم الهاتف',
          value: profile.phoneNumber,
        ),
      if (profile.nationalNumber.isNotEmpty)
        (
          icon: Icons.badge_outlined,
          title: 'الرقم الوطني',
          value: profile.nationalNumber,
        ),
      (icon: Icons.person_outline, title: 'الجنس', value: profile.genderName),
      if (profile.userType != null)
        (
          icon: Icons.manage_accounts_outlined,
          title: 'نوع الحساب',
          value: profile.userTypeName,
        ),
      if (profile.userStatus != null)
        (
          icon: Icons.verified_user_outlined,
          title: 'حالة الحساب',
          value: profile.statusName,
        ),
      if (profile.birthDate != null)
        (
          icon: Icons.cake_outlined,
          title: 'تاريخ الميلاد',
          value: DateFormat('yyyy-MM-dd').format(profile.birthDate!),
        ),
      if (profile.countryName.isNotEmpty)
        (
          icon: Icons.public_outlined,
          title: 'الدولة',
          value: profile.countryName,
        ),
      if (profile.cityName.isNotEmpty)
        (
          icon: Icons.location_city_outlined,
          title: 'المدينة',
          value: profile.cityName,
        ),
    ];
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            ListTile(
              leading: Icon(entries[index].icon),
              title: Text(entries[index].title),
              subtitle: SelectableText(entries[index].value),
            ),
            if (index < entries.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, UserProfile profile) => Card(
    child: Column(
      children: [
        _tile(Icons.edit_outlined, 'تعديل بياناتي', () async {
          final changed = await context.push<bool>(
            '/profile/edit',
            extra: profile,
          );
          if (changed == true && context.mounted) {
            await context.read<DetailCubit<UserProfile>>().load();
          }
        }),
        _divider(),
        _tile(
          Icons.list_alt_outlined,
          'معلوماتي الإضافية',
          () => context.push('/profile/info-answers'),
        ),
        _divider(),
        _tile(
          Icons.account_tree_outlined,
          'أين ذهبت تبرعاتي؟',
          () => context.push('/donations/trace'),
        ),
        _divider(),
        _tile(Icons.info_outline, 'حول التطبيق', () => context.push('/about')),
      ],
    ),
  );

  Widget _tile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
  }) => ListTile(
    leading: Icon(icon, color: AppTheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    onTap: onTap,
  );
  Widget _divider() => const Divider(height: 1);

  Future<void> _logout(BuildContext context) async {
    final donationRepository = context.read<DonationRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await donationRepository.clearLocalHistory();
      await PendingRouteStorage.clear();
      await TokenStorage.clear();
      if (context.mounted) context.go('/login');
    }
  }
}
