import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/async_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/ui/catalog_widgets.dart';
import '../data/home_overview.dart';
import '../data/home_repository.dart';
import '../logic/home_overview_cubit.dart';


class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeOverviewCubit(context.read<HomeRepository>())..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return ColoredBox(
      color: bg,
      child: BlocBuilder<HomeOverviewCubit, AsyncState<HomeOverview>>(
        builder: (context, state) {
          final overview = state.data;
          if (state.status == AsyncStatus.loading && overview == null) {
            return const SkeletonList();
          }
          if (state.status == AsyncStatus.failure && overview == null) {
            return ErrorRetry(
              message: state.message ?? 'تعذر تحميل الصفحة الرئيسية',
              onRetry: () =>
                  context.read<HomeOverviewCubit>().load(forceRefresh: true),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () =>
                context.read<HomeOverviewCubit>().load(forceRefresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _HomeBanner(),
                ),
                const SizedBox(height: 12),
                if (state.status == AsyncStatus.failure) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _InlineErrorBanner(
                      message: state.message ?? 'تعذر تحديث بعض البيانات',
                      onRetry: () => context
                          .read<HomeOverviewCubit>()
                          .load(forceRefresh: true),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _RequestHelpBanner(),
                ),
                const SizedBox(height: 28),
                _FadeInSection(
                  child: _CampaignsSection(
                    items: (overview?.campaigns ?? const []).take(3).toList(),
                  ),
                ),
                const SizedBox(height: 28),
                _FadeInSection(
                  delay: const Duration(milliseconds: 60),
                  child: _CasesSection(
                    items: (overview?.cases ?? const []).take(3).toList(),
                  ),
                ),
                const SizedBox(height: 28),
                _FadeInSection(
                  delay: const Duration(milliseconds: 120),
                  child: _CharitiesPreview(
                    items: (overview?.charities ?? const []).take(3).toList(),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FadeInSection extends StatefulWidget {
  const _FadeInSection({
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_FadeInSection> createState() => _FadeInSectionState();
}

class _FadeInSectionState extends State<_FadeInSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.warningSurfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _HomeBanner extends StatelessWidget {
  const _HomeBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ColoredBox(
          color: isDark ? AppTheme.darkSurface : AppTheme.soft,
          child: Image.asset(
            'assets/images/Section - Main Banner.png',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 200,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'GiveChain',
                      style: TextStyle(
                        color: AppTheme.primaryForeground,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'عطاؤك يصنع فرقًا',
                      style: TextStyle(
                        color: AppTheme.primaryForeground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.push(route),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'عرض الكل',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignsSection extends StatelessWidget {
  const _CampaignsSection({required this.items});

  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'حملات مختارة لك', route: '/campaigns'),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: EmptyView(
              message: 'لا توجد حملات متاحة الآن',
              icon: Icons.campaign_outlined,
            ),
          )
        else
          SizedBox(
            height: CatalogLook.carouselHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final detailRoute = '/campaigns/${item.id}';
                return CatalogCard(
                  item: item,
                  width: CatalogLook.carouselWidth,
                  donateLabel: 'شارك الأن',
                  onTap: () => context.push(detailRoute, extra: item),
                  onDonate: () {
                    if (item.canDonate) {
                      context.push('$detailRoute/donate', extra: item);
                    } else {
                      context.push(detailRoute, extra: item);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CasesSection extends StatelessWidget {
  const _CasesSection({required this.items});

  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'حالات تحتاج دعمك', route: '/cases'),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: EmptyView(
              message: 'لا توجد حالات متاحة الآن',
              icon: Icons.volunteer_activism_outlined,
            ),
          )
        else
          SizedBox(
            height: CatalogLook.carouselHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final detailRoute = '/cases/${item.id}';
                return CatalogCard(
                  item: item,
                  width: CatalogLook.carouselWidth,
                  onTap: () => context.push(detailRoute, extra: item),
                  onDonate: () {
                    if (item.canDonate) {
                      context.push('$detailRoute/donate', extra: item);
                    } else {
                      context.push(detailRoute, extra: item);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CharitiesPreview extends StatelessWidget {
  const _CharitiesPreview({required this.items});

  final List<Charity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final show = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'جمعيات موثوقة', route: '/charities'),
        const SizedBox(height: 12),
        ...show.map(
          (charity) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _CharityRow(charity: charity),
          ),
        ),
      ],
    );
  }
}

class _CharityRow extends StatelessWidget {
  const _CharityRow({required this.charity});

  final Charity charity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/charities/${charity.id}', extra: charity),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? scheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: charity.logoUrl.trim().isEmpty
                    ? Icon(Icons.apartment, color: scheme.primary)
                    : NetworkOrPlaceholder(
                        url: charity.logoUrl,
                        height: 48,
                        icon: Icons.apartment,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    charity.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (charity.categoryName.isNotEmpty)
                    Text(
                      charity.categoryName,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            if (charity.isTrusted)
              const Icon(Icons.verified, color: AppTheme.success, size: 20),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestHelpBanner extends StatelessWidget {
  const _RequestHelpBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryLight],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/request-help'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.handshake,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'هل تحتاج إلى مساعدة؟',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'تصفح المساعدات المتاحة وقدّم طلبك',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
