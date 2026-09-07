import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../data/benefit_models.dart';
import '../data/benefit_repository.dart';

/// The signed-in user's benefit applications as a paged, refreshable list.
///
/// Shared by both entry points: the profile's "منافعي" screen shows every
/// application, while a charity's Benefits tab passes [charityId] to show only
/// the ones submitted to that charity.
class BenefitRequestsList extends StatefulWidget {
  const BenefitRequestsList({
    super.key,
    this.charityId = '',
    this.padding = const EdgeInsets.all(16),
    this.emptyMessage,
  });

  final String charityId;
  final EdgeInsets padding;
  final String? emptyMessage;

  @override
  State<BenefitRequestsList> createState() => BenefitRequestsListState();
}

class BenefitRequestsListState extends State<BenefitRequestsList> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  final _items = <BenefitRequest>[];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    refresh();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 320) _loadMore();
  }

  /// Reloads from page one. Public so a parent can refresh after a submit.
  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _hasMore = true;
    });
    try {
      final result = await context.read<BenefitRepository>().mine(
        page: 1,
        pageSize: _pageSize,
        charityId: widget.charityId,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = 1;
        _hasMore = result.hasMore;
      });
      // A charity-scoped page can legitimately come back empty while more
      // pages remain, because the charity filter is applied client-side.
      // Pull the next page so the tab is not left looking empty.
      if (_hasMore && _items.isEmpty && widget.charityId.isNotEmpty) {
        await _loadMore();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await context.read<BenefitRepository>().mine(
        page: next,
        pageSize: _pageSize,
        charityId: widget.charityId,
      );
      if (!mounted) return;
      final existing = _items.map((item) => item.id).toSet();
      setState(() {
        _items.addAll(result.items.where((item) => existing.add(item.id)));
        _page = next;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const SkeletonList(count: 4);
    if (_error != null && _items.isEmpty) {
      return ErrorRetry(message: _error!, onRetry: refresh);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: EmptyView(
                message:
                    widget.emptyMessage ??
                    (widget.charityId.isEmpty
                        ? 'لم تقدم طلبات منافع بعد.'
                        : 'لم تقدم أي طلب منفعة لهذه الجمعية بعد.'),
                icon: Icons.assignment_outlined,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return BenefitRequestCard(
            request: _items[index],
            onChanged: refresh,
          );
        },
      ),
    );
  }
}

/// One application, as shown in the list.
class BenefitRequestCard extends StatelessWidget {
  const BenefitRequestCard({
    super.key,
    required this.request,
    this.onChanged,
  });

  final BenefitRequest request;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = benefitStatusStyle(request.status);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await context.push('/benefits/${request.id}', extra: request);
          onChanged?.call();
        },
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
                  Icons.assignment_turned_in_outlined,
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
                      request.benefitTypeName.isEmpty
                          ? 'طلب منفعة'
                          : request.benefitTypeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'رقم الطلب: ${request.requestNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (request.submittedAtOrNull != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat(
                          'yyyy-MM-dd',
                        ).format(request.submittedAtOrNull!.toLocal()),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BenefitStatusPill(status: request.status, style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// High-contrast status badge, matching the app's donation/complaint pills.
class BenefitStatusPill extends StatelessWidget {
  const BenefitStatusPill({super.key, required this.status, this.style});

  final int status;
  final BenefitStatusStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? benefitStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: resolved.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: resolved.textColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(resolved.icon, size: 14, color: resolved.textColor),
          const SizedBox(width: 6),
          Text(
            resolved.label,
            style: TextStyle(
              color: resolved.textColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class BenefitStatusStyle {
  const BenefitStatusStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.label,
  });

  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final String label;
}

/// Visual treatment per `BenefitRequestStatus`.
///
/// The contract defines exactly three values — 0 Pending, 1 Accepted,
/// 2 Rejected — and the `default` arm keeps an unknown future value readable
/// rather than mislabelling it as one of the three.
BenefitStatusStyle benefitStatusStyle(int status) => switch (status) {
  0 => const BenefitStatusStyle(
    backgroundColor: Color(0xFFFEF3C7),
    textColor: Color(0xFFD97706),
    icon: Icons.access_time_rounded,
    label: 'قيد المراجعة',
  ),
  1 => const BenefitStatusStyle(
    backgroundColor: Color(0xFFD1FAE5),
    textColor: Color(0xFF059669),
    icon: Icons.check_circle_outline,
    label: 'مقبول',
  ),
  2 => const BenefitStatusStyle(
    backgroundColor: Color(0xFFFEE2E2),
    textColor: Color(0xFFDC2626),
    icon: Icons.cancel_outlined,
    label: 'مرفوض',
  ),
  _ => const BenefitStatusStyle(
    backgroundColor: Color(0xFFF3F4F6),
    textColor: Color(0xFF4B5563),
    icon: Icons.info_outline,
    label: 'غير معروف',
  ),
};
