import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_enums.dart';
import '../../../core/network/url_resolver.dart';
import '../../../core/state/async_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../../media/ui/media_gallery_screen.dart';
import '../logic/catalog_cubits.dart';
import 'catalog_list_screen.dart';
import 'catalog_widgets.dart';

class CatalogDetailScreen extends StatelessWidget {
  const CatalogDetailScreen({
    super.key,
    required this.id,
    required this.kind,
    this.fallback,
  });

  final String id;
  final CatalogKind kind;
  final CatalogItem? fallback;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CatalogRepository>();
    return BlocProvider(
      create: (_) => DetailCubit<CatalogItem>(
        () => kind == CatalogKind.campaigns
            ? repository.campaign(id)
            : repository.caseById(id),
        refreshLoader: () => kind == CatalogKind.campaigns
            ? repository.campaign(id, forceRefresh: true)
            : repository.caseById(id, forceRefresh: true),
      )..load(),
      child: _DetailView(kind: kind, fallback: fallback),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.kind, this.fallback});

  final CatalogKind kind;
  final CatalogItem? fallback;

  @override
  Widget build(BuildContext context) {
    final isCampaign = kind == CatalogKind.campaigns;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF8F9FB),
      body: BlocBuilder<DetailCubit<CatalogItem>, AsyncState<CatalogItem>>(
        builder: (context, state) {
          if (state.status == AsyncStatus.loading && fallback == null) {
            return const SafeArea(child: SkeletonList(count: 5));
          }
          if (state.status == AsyncStatus.failure && fallback == null) {
            return Scaffold(
              appBar: AppBar(),
              body: ErrorRetry(
                message: state.message ?? 'تعذر تحميل التفاصيل',
                onRetry: context.read<DetailCubit<CatalogItem>>().load,
              ),
            );
          }

          final item = state.data ?? fallback;
          if (item == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const EmptyView(message: 'تعذر العثور على العنصر'),
            );
          }

          // A case with no media used to reserve the full image height for a
          // grey placeholder, pushing the needs and updates below the fold.
          // Only a real image earns the tall header.
          final hasImage = _MediaGallery.urlsOf(item).isNotEmpty;

          return RefreshIndicator(
                onRefresh: () => context.read<DetailCubit<CatalogItem>>().load(
                  forceRefresh: true,
                ),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      expandedHeight: hasImage
                          ? CatalogLook.detailHeaderHeight
                          : CatalogLook.detailHeaderHeightNoImage,
                      pinned: true,
                      backgroundColor: isDark
                          ? AppTheme.darkSurface
                          : Colors.white,
                      leading: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircleAvatar(
                          backgroundColor: Colors.black38,
                          child: const BackButton(color: Colors.white),
                        ),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            _MediaGallery(item: item),
                            // The scrim only earns its keep over a photo;
                            // on the placeholder it reads as a dark smear.
                            if (hasImage)
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black26,
                                      Colors.black87,
                                    ],
                                    stops: [0.6, 0.8, 1.0],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context).colorScheme.surface
                              : const Color(0xFFF8F9FB),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        transform: Matrix4.translationValues(0, -32, 0),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _StatusBadges(item: item, isCampaign: isCampaign),

                              // A locked status is the charity telling donors
                              // the state will not change yet — surfaced
                              // before anything else it might explain.
                              if (item.isStatusLocked) ...[
                                const SizedBox(height: 14),
                                _NoticeBox(
                                  icon: Icons.lock_outline,
                                  color: Colors.blueGrey,
                                  title: 'الحالة مثبّتة',
                                  body: item.statusLockNote.isEmpty
                                      ? 'لن تتغيّر حالة هذا الطلب حالياً.'
                                      : item.statusLockNote,
                                ),
                              ],

                              const SizedBox(height: 20),
                              _ProgressBlock(item: item),

                              if (item.charityName.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.section),
                                _CharityCard(item: item),
                              ],

                              if (item.description.trim().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.section),
                                AppSection(
                                  title: isCampaign
                                      ? 'حول الحملة'
                                      : 'حول الحالة',
                                  icon: Icons.article_outlined,
                                  child: Text(
                                    item.description,
                                    style: TextStyle(
                                      height: 1.8,
                                      fontSize: 15,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ),
                              ],

                              if (item.caseNeeds.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.section),
                                _CaseNeedsSection(item: item),
                              ],

                              if (item.caseUpdates.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.section),
                                _CaseUpdatesSection(updates: item.caseUpdates),
                              ],

                              // Everything the API happens to carry about
                              // this item. Rows appear only once filled, so
                              // the block grows on its own as the backend
                              // starts populating these fields.
                              if (_DetailsSection.hasAnything(
                                item,
                                isCampaign,
                              )) ...[
                                const SizedBox(height: AppSpacing.section),
                                _DetailsSection(
                                  item: item,
                                  isCampaign: isCampaign,
                                ),
                              ],

                              if (item.closedNotes.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.section),
                                _NoticeBox(
                                  icon: Icons.info_outline,
                                  color: Colors.orange,
                                  title: 'ملاحظات الإغلاق',
                                  body: item.closedNotes,
                                ),
                              ],

                              if (state.status == AsyncStatus.failure) ...[
                                const SizedBox(height: AppSpacing.section),
                                _NoticeBox(
                                  icon: Icons.cloud_off_outlined,
                                  color: Colors.red,
                                  title: 'تعذّر تحديث البيانات',
                                  body:
                                      'يتم عرض آخر نسخة متاحة. '
                                              '${state.message ?? ''}'
                                          .trim(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
        },
      ),
      bottomNavigationBar:
          BlocBuilder<DetailCubit<CatalogItem>, AsyncState<CatalogItem>>(
            builder: (context, state) {
              final item = state.data ?? fallback;
              if (item == null) return const SizedBox.shrink();
              return StickyActionButton(
                label: item.canDonate ? 'تبرّع الآن' : 'التبرع غير متاح',
                onPressed: item.canDonate
                    ? () => context.push(
                        isCampaign
                            ? '/campaigns/${item.id}/donate'
                            : '/cases/${item.id}/donate',
                      )
                    : null,
              );
            },
          ),
    );
  }
}

class _MediaGallery extends StatelessWidget {
  const _MediaGallery({required this.item});

  final CatalogItem item;

  /// The gallery's images, de-duplicated. Also drives the header height, so
  /// both agree on whether there is anything to show.
  static List<String> urlsOf(CatalogItem item) => <String>{
    if (item.imageUrl.isNotEmpty) item.imageUrl,
    ...item.mediaUrls.where((value) => value.isNotEmpty),
  }.toList();

  @override
  Widget build(BuildContext context) {
    final urls = urlsOf(item);
    if (urls.length <= 1) {
      return InkWell(
        onTap: urls.isEmpty
            ? null
            : () => context.push(
                '/media-gallery',
                extra: MediaGalleryArgs(urls: urls, title: item.title),
              ),
        child: NetworkOrPlaceholder(
          url: urls.isEmpty ? '' : urls.first,
          height: double.infinity,
        ),
      );
    }
    return PageView.builder(
      itemCount: urls.length,
      itemBuilder: (context, index) => InkWell(
        onTap: () => context.push(
          '/media-gallery',
          extra: MediaGalleryArgs(
            urls: urls,
            initialIndex: index,
            title: item.title,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkOrPlaceholder(url: urls[index], height: double.infinity),
            PositionedDirectional(
              end: 16,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${index + 1} / ${urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadges extends StatelessWidget {
  const _StatusBadges({required this.item, required this.isCampaign});

  final CatalogItem item;
  final bool isCampaign;

  @override
  Widget build(BuildContext context) {
    final statusCode = item.statusCode;
    final chips = <Widget>[
      // The status carries its own colour so a closed or cancelled item does
      // not read as encouragingly as an active one.
      if (item.displayStatus.isNotEmpty)
        AppInfoChip(
          icon: Icons.info_outline,
          label: item.displayStatus,
          color: statusCode == null
              ? AppTheme.primary
              : ApiEnums.statusColor(
                  statusCode,
                  family: isCampaign ? 'campaign' : 'case',
                ),
        ),
      if (!isCampaign && (item.priority ?? 0) >= 2)
        AppInfoChip(
          icon: Icons.priority_high,
          label: item.priorityLabel.isEmpty
              ? 'حالة عاجلة'
              : 'أولوية ${item.priorityLabel}',
          color: ApiEnums.statusColor(item.priority!, family: 'casePriority'),
        ),
      if (item.isTrusted)
        AppInfoChip(
          icon: Icons.verified,
          label: 'جهة موثقة',
          color: Colors.blue.shade600,
        ),
      if (item.typeName.isNotEmpty)
        AppInfoChip(icon: Icons.category_outlined, label: item.typeName),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _CharityCard extends StatelessWidget {
  const _CharityCard({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: item.charityId.isEmpty
          ? null
          : () => context.push('/charities/${item.charityId}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainer : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.softOf(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الجهة المنفذة',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    item.charityName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (item.charityId.isNotEmpty)
              const Icon(Icons.chevron_right, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

/// The case's donatable needs. Tapping one starts a donation, which is the
/// only way the server accepts a case donation at all.
class _CaseNeedsSection extends StatelessWidget {
  const _CaseNeedsSection({required this.item});

  final CatalogItem item;

  static String _number(double value) => value == value.roundToDouble()
      ? NumberFormat('#,##0').format(value)
      : NumberFormat('#,##0.##').format(value);

  String _target(CaseNeed need) {
    final amount = need.amount ?? 0;
    if (amount > 0) return _number(amount);
    final quantity = need.quantity ?? 0;
    if (quantity > 0) {
      final unit = need.unitLabel;
      return '${_number(quantity)}${unit.isEmpty ? '' : ' $unit'}';
    }
    return '';
  }

  String _done(CaseNeed need) {
    final amount = need.amount ?? 0;
    if (amount > 0) return _number(need.fulfilledAmount ?? 0);
    final quantity = need.quantity ?? 0;
    if (quantity > 0) return _number(need.fulfilledQuantity ?? 0);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = item.caseNeeds.where((need) => !need.isFulfilled).length;
    return AppSection(
      title: 'الاحتياجات',
      icon: Icons.checklist_outlined,
      count: item.caseNeeds.length,
      padded: false,
      subtitle: remaining == 0
          ? 'اكتملت جميع الاحتياجات'
          : 'ما زال $remaining منها بحاجة إلى دعم',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final need in item.caseNeeds) ...[
            _NeedCard(
              need: need,
              target: _target(need),
              done: _done(need),
              canDonate: item.canDonate,
              onDonate: () => context.push('/cases/${item.id}/donate'),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _NeedCard extends StatelessWidget {
  const _NeedCard({
    required this.need,
    required this.target,
    required this.done,
    required this.canDonate,
    required this.onDonate,
  });

  final CaseNeed need;
  final String target;
  final String done;
  final bool canDonate;
  final VoidCallback onDonate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = need.progress;
    final fulfilled = need.isFulfilled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: fulfilled
              ? Colors.green.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                fulfilled ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: fulfilled ? Colors.green : AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  need.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (need.typeLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    need.typeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          if (need.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              need.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
          if (target.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'المطلوب: $target',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (done.isNotEmpty)
                  Text(
                    'تم: $done',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fulfilled ? Colors.green : AppTheme.primary,
                    ),
                  ),
              ],
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  fulfilled ? Colors.green : AppTheme.primary,
                ),
              ),
            ),
          ],
          if (canDonate && !fulfilled) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onDonate,
                icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                label: const Text('تبرّع لهذا الاحتياج'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Progress posts published on the case by the owning charity.
class _CaseUpdatesSection extends StatelessWidget {
  const _CaseUpdatesSection({required this.updates});

  final List<CaseUpdate> updates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppSection(
      title: 'آخر المستجدات',
      icon: Icons.campaign_outlined,
      count: updates.length,
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final update in updates) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? scheme.surfaceContainerHighest : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      if (update.postedAt != null)
                        Text(
                          DateFormat(
                            'yyyy-MM-dd',
                          ).format(update.postedAt!.toLocal()),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    update.content,
                    style: const TextStyle(fontSize: 14, height: 1.7),
                  ),
                  if (update.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: update.mediaUrls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => InkWell(
                          onTap: () => context.push(
                            '/media-gallery',
                            extra: MediaGalleryArgs(
                              urls: update.mediaUrls,
                              initialIndex: index,
                              title: 'صور التحديث',
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              UrlResolver.resolve(update.mediaUrls[index]),
                              width: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 140,
                                color: scheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// The funding headline: a money bar, a quantity bar, or an honest
/// "open collection" state.
///
/// Every campaign and case in production leaves `targetAmount`/`achievedAmount`
/// null — the real money sits on `caseNeeds` — so [CatalogItem] aggregates the
/// needs and this reads the aggregate. When there is genuinely no target,
/// showing a 0% bar would imply the item had raised nothing against a known
/// goal, so the block says "تجميع مفتوح" instead of drawing an empty bar.
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.item});

  final CatalogItem item;

  static final _number = NumberFormat('#,##0.##');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasMoney = item.hasMonetaryGoal;
    final quantityProgress = item.quantityProgress;
    final hasQuantity = !hasMoney && quantityProgress != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: hasMoney
          ? _money(context, scheme)
          : hasQuantity
          ? _quantity(context, scheme, quantityProgress)
          : _open(context, scheme),
    );
  }

  Widget _money(BuildContext context, ColorScheme scheme) {
    final progress = item.progress;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم جمع',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _number.format(item.effectiveCollectedAmount),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            AppInfoChip(
              label:
                  '${(progress * 100).toStringAsFixed(progress < 0.1 ? 1 : 0)}%',
              color: AppTheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _bar(scheme, progress),
        const SizedBox(height: 16),
        _footer(
          scheme,
          leftLabel: 'الهدف',
          leftValue: _number.format(item.effectiveGoalAmount),
          rightLabel: 'المتبقي',
          rightValue: _number.format(item.remainingAmount),
        ),
      ],
    );
  }

  Widget _quantity(BuildContext context, ColorScheme scheme, double progress) {
    final unit = item.goalUnit.isEmpty ? '' : ' ${item.goalUnit}';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم تأمين',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_number.format(item.effectiveAchievedQuantity)}$unit',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            AppInfoChip(
              label: '${(progress * 100).toStringAsFixed(0)}%',
              color: AppTheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _bar(scheme, progress),
        const SizedBox(height: 16),
        _footer(
          scheme,
          leftLabel: 'المطلوب',
          leftValue: '${_number.format(item.effectiveTargetQuantity)}$unit',
          rightLabel: 'المتبقي',
          rightValue:
              '${_number.format((item.effectiveTargetQuantity - item.effectiveAchievedQuantity).clamp(0, double.infinity))}$unit',
        ),
      ],
    );
  }

  /// No target was ever set, so there is no percentage to be honest about.
  Widget _open(BuildContext context, ColorScheme scheme) => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.all_inclusive,
          color: AppTheme.primary,
          size: 22,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تجميع مفتوح',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'لم تُحدَّد الجهة مبلغاً مستهدفاً، وكل تبرع يصل بالكامل.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _bar(ColorScheme scheme, double value) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 12,
      backgroundColor: scheme.surfaceContainerHighest,
      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
    ),
  );

  Widget _footer(
    ColorScheme scheme, {
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) => Row(
    children: [
      Expanded(
        child: AppStat(
          label: leftLabel,
          value: leftValue,
          icon: Icons.flag_outlined,
        ),
      ),
      Container(width: 1, height: 32, color: scheme.outlineVariant),
      const SizedBox(width: 12),
      Expanded(
        child: AppStat(
          label: rightLabel,
          value: rightValue,
          icon: Icons.trending_up,
        ),
      ),
    ],
  );
}

/// A coloured callout: closure notes, a locked status, a stale-data warning.
class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSection.radius),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(height: 1.6, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Everything else the API returns about this item.
///
/// Each row is conditional, so the block shows only what the backend actually
/// filled in — most of these fields are empty across production today, and
/// they will start appearing on their own once they are populated.
class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.item, required this.isCampaign});

  final CatalogItem item;
  final bool isCampaign;

  static final _date = DateFormat('yyyy/MM/dd');

  /// Rows, built once so the caller can ask whether any exist before
  /// reserving space for the section.
  static List<({IconData icon, String label, String value})> _rows(
    CatalogItem item,
    bool isCampaign,
  ) => [
    if (item.referenceNumber.isNotEmpty)
      (
        icon: Icons.tag,
        label: isCampaign ? 'رقم الحملة' : 'رقم الحالة',
        value: item.referenceNumber,
      ),
    if (item.typeName.isNotEmpty)
      (
        icon: Icons.category_outlined,
        label: isCampaign ? 'نوع الحملة' : 'تصنيف الحالة',
        value: item.typeName,
      ),
    if (!isCampaign && item.priorityLabel.isNotEmpty)
      (icon: Icons.flag_outlined, label: 'الأولوية', value: item.priorityLabel),
    if (item.location.isNotEmpty)
      (icon: Icons.location_on_outlined, label: 'الموقع', value: item.location),
    if (item.beneficiaryName.isNotEmpty)
      (
        icon: Icons.person_outline,
        label: 'المستفيد',
        value: item.beneficiaryName,
      ),
    if (item.goalTypeLabel.isNotEmpty)
      (
        icon: Icons.category_outlined,
        label: 'نوع الهدف',
        value: item.goalTypeLabel,
      ),
    if (isCampaign && item.startDate != null)
      (
        icon: Icons.play_circle_outline,
        label: 'تاريخ البدء',
        value: _date.format(item.startDate!.toLocal()),
      ),
    if (isCampaign && item.endDate != null)
      (
        icon: Icons.event_busy_outlined,
        label: 'تاريخ الانتهاء',
        value: _date.format(item.endDate!.toLocal()),
      ),
    if (!isCampaign && item.publishedAt != null)
      (
        icon: Icons.publish_outlined,
        label: 'تاريخ النشر',
        value: _date.format(item.publishedAt!.toLocal()),
      ),
    if (item.closedAt != null)
      (
        icon: Icons.event_available_outlined,
        label: 'تاريخ الإغلاق',
        value: _date.format(item.closedAt!.toLocal()),
      ),
    if (item.createdByUserName.isNotEmpty)
      (
        icon: Icons.badge_outlined,
        label: 'المسؤول',
        value: item.createdByUserName,
      ),
  ];

  static bool hasAnything(CatalogItem item, bool isCampaign) =>
      _rows(item, isCampaign).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final rows = _rows(item, isCampaign);
    final scheme = Theme.of(context).colorScheme;
    return AppSection(
      title: 'معلومات إضافية',
      icon: Icons.info_outline,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            AppDetailRow(
              icon: rows[i].icon,
              label: rows[i].label,
              value: rows[i].value,
            ),
          ],
        ],
      ),
    );
  }
}
