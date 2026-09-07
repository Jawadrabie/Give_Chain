import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_enums.dart';
import '../../../core/network/url_resolver.dart';
import '../../../core/state/async_state.dart';
import '../../../core/state/paged_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../benefits/data/benefit_models.dart';
import '../../benefits/data/benefit_repository.dart';
import '../../benefits/ui/benefit_requests_list.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/logic/catalog_cubits.dart';
import '../../catalog/ui/catalog_widgets.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../donations/data/donation_models.dart';

class CharityDetailScreen extends StatelessWidget {
  const CharityDetailScreen({
    super.key,
    required this.id,
    this.fallback,
    this.initialTab = 0,
  });

  final String id;
  final Charity? fallback;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CatalogRepository>();
    return BlocProvider(
      create: (_) => DetailCubit<Charity>(() => repository.charity(id))..load(),
      child: _CharityView(
        id: id,
        fallback: fallback,
        initialTab: initialTab.clamp(0, 3).toInt(),
      ),
    );
  }
}

class _CharityView extends StatelessWidget {
  const _CharityView({
    required this.id,
    required this.initialTab,
    this.fallback,
  });

  final String id;
  final Charity? fallback;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DetailCubit<Charity>, AsyncState<Charity>>(
      builder: (context, state) {
        if (state.status == AsyncStatus.loading && fallback == null) {
          return const Scaffold(
            appBar: AppBackAppBar(),
            body: SkeletonList(count: 5),
          );
        }
        if (state.status == AsyncStatus.failure && fallback == null) {
          return Scaffold(
            appBar: const AppBackAppBar(),
            body: ErrorRetry(
              message: state.message ?? 'تعذر تحميل الجمعية',
              onRetry: context.read<DetailCubit<Charity>>().load,
            ),
          );
        }
        final charity = state.data ?? fallback;
        if (charity == null) {
          return const Scaffold(
            appBar: AppBackAppBar(),
            body: EmptyView(message: 'تعذر العثور على الجمعية.'),
          );
        }
        return DefaultTabController(
          length: 4,
          initialIndex: initialTab,
          child: Scaffold(
            appBar: AppBackAppBar(
              title: Text(charity.name),
              actions: [
                TextButton.icon(
                  onPressed: () => context.push(
                    '/charities/$id/complaint?name=${Uri.encodeComponent(charity.name)}',
                  ),
                  icon: const Icon(Icons.report_outlined),
                  label: const Text('تقديم شكوى'),
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'نبذة'),
                  Tab(text: 'الحملات'),
                  Tab(text: 'الحالات'),
                  Tab(text: 'طلب الاستفادة'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _AboutCharity(
                  charity: charity,
                  warning: state.status == AsyncStatus.failure
                      ? state.message
                      : null,
                  onRefresh: context.read<DetailCubit<Charity>>().load,
                ),
                _CharityCatalog(
                  charityId: id,
                  charityName: charity.name,
                  campaigns: true,
                ),
                _CharityCatalog(
                  charityId: id,
                  charityName: charity.name,
                  campaigns: false,
                ),
                _CharityBenefits(charityId: id, charityName: charity.name),
              ],
            ),
            bottomNavigationBar: _CharityDonateBar(charity: charity),
          ),
        );
      },
    );
  }
}

class _CharityDonateBar extends StatelessWidget {
  const _CharityDonateBar({required this.charity});
  final Charity charity;

  bool get _canDonate => charity.status == null || charity.status == 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -10),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.primaryForeground,
            disabledBackgroundColor: scheme.surfaceContainerHighest,
            minimumSize: const Size.fromHeight(56),
            elevation: _canDonate ? 4 : 0,
            shadowColor: AppTheme.primary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _canDonate
              ? () => context.push(
                  '/donate',
                  extra: DonationRouteData(
                    target: CatalogItem(
                      id: charity.id,
                      title: charity.name,
                      charityId: charity.id,
                      charityName: charity.name,
                    ),
                    targetType: 3,
                    useGeneralEndpoint: true,
                  ),
                )
              : null,
          icon: Icon(
            _canDonate ? Icons.volunteer_activism_outlined : Icons.block,
          ),
          label: Text(
            _canDonate ? 'تبرع مباشر لهذه الجمعية' : 'التبرع غير متاح حالياً',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutCharity extends StatelessWidget {
  const _AboutCharity({
    required this.charity,
    required this.onRefresh,
    this.warning,
  });

  final Charity charity;
  final Future<void> Function() onRefresh;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final categories = charity.categoryNames.isNotEmpty
        ? charity.categoryNames
        : charity.categoryName.isEmpty
        ? const <String>[]
        : <String>[charity.categoryName];
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (warning != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningSurfaceOf(context),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                warning!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: NetworkOrPlaceholder(
              url: charity.logoUrl,
              height: 210,
              icon: Icons.apartment,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  charity.name,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (charity.isTrusted)
                const Tooltip(
                  message: 'جمعية موثقة',
                  child: Icon(Icons.verified, color: Colors.green, size: 28),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  Icons.circle,
                  size: 11,
                  color: ApiEnums.statusColor(
                    charity.status ?? 0,
                    family: 'charity',
                  ),
                ),
                label: Text(ApiEnums.charityStatus[charity.status] ?? 'مسجلة'),
              ),
              if (charity.isTrusted)
                const Chip(
                  avatar: Icon(Icons.verified_outlined, size: 18),
                  label: Text('موثقة'),
                ),
            ],
          ),
          if (charity.status == 1 && charity.suspendedReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningSurfaceOf(context),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('سبب الإيقاف: ${charity.suspendedReason}'),
                  ),
                ],
              ),
            ),
          ],
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map((item) => Chip(label: Text(item)))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            charity.description.isEmpty
                ? 'لا يوجد وصف متاح.'
                : charity.description,
            style: const TextStyle(height: 1.7),
          ),
          if (charity.campaignsCount != null || charity.casesCount != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                if (charity.campaignsCount != null)
                  Expanded(
                    child: _counter(
                      context,
                      Icons.campaign_outlined,
                      '${charity.campaignsCount}',
                      'حملة',
                    ),
                  ),
                if (charity.campaignsCount != null &&
                    charity.casesCount != null)
                  const SizedBox(width: 12),
                if (charity.casesCount != null)
                  Expanded(
                    child: _counter(
                      context,
                      Icons.volunteer_activism_outlined,
                      '${charity.casesCount}',
                      'حالة',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                if (charity.cityName.isNotEmpty ||
                    charity.countryName.isNotEmpty)
                  _info(
                    Icons.public,
                    'الموقع',
                    [
                      charity.cityName,
                      charity.countryName,
                    ].where((value) => value.isNotEmpty).join('، '),
                  ),
                if (charity.address.isNotEmpty)
                  _info(Icons.location_on_outlined, 'العنوان', charity.address),
                if (charity.date != null)
                  _info(
                    Icons.calendar_today_outlined,
                    'تاريخ التسجيل',
                    DateFormat('yyyy-MM-dd').format(charity.date!),
                  ),
                if (charity.phone.isNotEmpty)
                  _info(
                    Icons.phone_outlined,
                    'الهاتف',
                    charity.phone,
                    onTap: () => _launch('tel:${charity.phone}'),
                  ),
                if (charity.email.isNotEmpty)
                  _info(
                    Icons.email_outlined,
                    'البريد الإلكتروني',
                    charity.email,
                    onTap: () => _launch('mailto:${charity.email}'),
                  ),
                if (charity.website.isNotEmpty)
                  _info(
                    Icons.language,
                    'الموقع الإلكتروني',
                    charity.website,
                    onTap: () => _launch(charity.website),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _counter(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.softOf(context),
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        Text(label),
      ],
    ),
  );

  Widget _info(
    IconData icon,
    String label,
    String text, {
    VoidCallback? onTap,
    Widget? trailing,
  }) => ListTile(
    leading: Icon(icon, color: AppTheme.primary),
    title: Text(label),
    subtitle: Text(text),
    trailing:
        trailing ??
        (onTap == null ? null : const Icon(Icons.open_in_new, size: 18)),
    onTap: onTap,
  );

  Future<void> _launch(String value) async {
    final candidate = value.trim();
    final uri = candidate.startsWith('tel:') || candidate.startsWith('mailto:')
        ? Uri.tryParse(candidate)
        : UrlResolver.external(candidate);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// The charity's Benefits tab — the charity-first way into an application.
///
/// Opens on what this charity offers, since that is what someone looking at a
/// charity came to find out; picking a type leads straight to its questions.
/// A second sub-tab holds the user's own requests to this charity.
class _CharityBenefits extends StatefulWidget {
  const _CharityBenefits({required this.charityId, required this.charityName});

  final String charityId;
  final String charityName;

  @override
  State<_CharityBenefits> createState() => _CharityBenefitsState();
}

class _CharityBenefitsState extends State<_CharityBenefits>
    with SingleTickerProviderStateMixin {
  final _listKey = GlobalKey<BenefitRequestsListState>();
  late Future<List<BenefitType>> _types;

  /// Owned outright rather than looked up: this state sits *above* its own
  /// DefaultTabController, so `DefaultTabController.of(context)` here would
  /// find the charity's outer 4-tab bar and switch away from Benefits.
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _types = _fetchTypes();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<List<BenefitType>> _fetchTypes({bool forceRefresh = false}) =>
      context.read<BenefitRepository>().benefitTypes(
        charityId: widget.charityId,
        forceRefresh: forceRefresh,
      );

  void _reloadTypes() =>
      setState(() => _types = _fetchTypes(forceRefresh: true));

  Future<void> _apply(BenefitType type) async {
    final submitted = await context.push<bool>('/benefits/apply', extra: type);
    // The new request belongs in the neighbouring sub-tab, so refresh it and
    // move the user there rather than leaving them on an unchanged list.
    if (submitted == true && mounted) {
      _listKey.currentState?.refresh();
      _tabs.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'أنواع الاستفادة'),
          Tab(text: 'طلباتي'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            _BenefitTypesTab(
              future: _types,
              onRetry: _reloadTypes,
              onApply: _apply,
            ),
            BenefitRequestsList(key: _listKey, charityId: widget.charityId),
          ],
        ),
      ),
    ],
  );
}

/// What the charity offers, each row leading into its own application form.
class _BenefitTypesTab extends StatelessWidget {
  const _BenefitTypesTab({
    required this.future,
    required this.onRetry,
    required this.onApply,
  });

  final Future<List<BenefitType>> future;
  final VoidCallback onRetry;
  final ValueChanged<BenefitType> onApply;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<BenefitType>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SkeletonList(count: 3);
      }
      if (snapshot.hasError) {
        return ErrorRetry(message: snapshot.error.toString(), onRetry: onRetry);
      }
      final items = snapshot.data ?? const <BenefitType>[];
      if (items.isEmpty) {
        return const EmptyView(
          message: 'لا تتوفر أنواع استفادة فعالة لدى هذه الجمعية حاليًا.',
          icon: Icons.redeem_outlined,
        );
      }

      final scheme = Theme.of(context).colorScheme;
      return RefreshIndicator(
        onRefresh: () async => onRetry(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final questionCount = item.questions.length;
            return Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onApply(item),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.redeem_outlined,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              questionCount == 0
                                  ? 'بدون أسئلة إضافية'
                                  : '$questionCount ${questionCount == 1 ? 'سؤال' : 'أسئلة'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                            if (item.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _CharityCatalog extends StatefulWidget {
  const _CharityCatalog({
    required this.charityId,
    required this.charityName,
    required this.campaigns,
  });

  final String charityId;
  final String charityName;
  final bool campaigns;

  @override
  State<_CharityCatalog> createState() => _CharityCatalogState();
}

class _CharityCatalogState extends State<_CharityCatalog> {
  final _search = TextEditingController();
  PagedCatalogCubit<CatalogItem>? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final repository = context.read<CatalogRepository>();
    _cubit = PagedCatalogCubit<CatalogItem>(
      widget.campaigns
          ? (page, size) => repository.charityCampaigns(
              widget.charityId,
              page: page,
              pageSize: size,
              filter: CatalogQuery(search: _search.text),
            )
          : (page, size) => repository.charityCases(
              widget.charityId,
              page: page,
              pageSize: size,
              filter: CatalogQuery(search: _search.text),
            ),
    )..load();
  }

  @override
  void dispose() {
    _search.dispose();
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SkeletonList(count: 3);
    return BlocProvider.value(
      value: cubit,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.campaigns
                        ? 'الحملات الفعالة لدى الجمعية'
                        : 'الحالات المفتوحة لدى الجمعية',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push(
                    '/charities/${widget.charityId}/${widget.campaigns ? 'campaigns' : 'cases'}?name=${Uri.encodeComponent(widget.charityName)}',
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('عرض الكل'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              controller: _search,
              hintText: widget.campaigns
                  ? 'ابحث ضمن الحملات المحمّلة'
                  : 'ابحث ضمن الحالات المحمّلة',
              leading: const Icon(Icons.search),
              onChanged: (_) => cubit.load(refresh: true),
              trailing: [
                IconButton(
                  onPressed: () {
                    _search.clear();
                    cubit.load(refresh: true);
                  },
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                BlocBuilder<
                  PagedCatalogCubit<CatalogItem>,
                  PagedState<CatalogItem>
                >(
                  builder: (context, state) {
                    if (state.isLoading && state.items.isEmpty) {
                      return const SkeletonList(count: 3);
                    }
                    if (state.error != null && state.items.isEmpty) {
                      return ErrorRetry(
                        message: state.error!,
                        onRetry: () => cubit.load(refresh: true),
                      );
                    }
                    if (state.items.isEmpty) {
                      return EmptyView(
                        message: widget.campaigns
                            ? 'لا توجد حملات لهذه الجمعية'
                            : 'لا توجد حالات لهذه الجمعية',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () => cubit.load(refresh: true),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.extentAfter < 320) {
                            cubit.loadMore();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              state.items.length +
                              (state.isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            if (index == state.items.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final item = state.items[index];
                            return CatalogCard(
                              item: item,
                              onTap: () => context.push(
                                widget.campaigns
                                    ? '/campaigns/${item.id}'
                                    : '/cases/${item.id}',
                                extra: item,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
