import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../benefits/data/benefit_models.dart';
import '../../benefits/data/benefit_repository.dart';

/// "هل تحتاج إلى مساعدة؟" — the need-first way into a benefit application.
///
/// The user says *what* they need before *who* provides it: this lists every
/// benefit on offer grouped by name, and picking one leads to the charities
/// providing it. That is the mirror image of the charity-first flow on a
/// charity's Benefits tab, and both end at the same questions and the same
/// `POST /api/mobile/benefits`.
class RequestHelpScreen extends StatefulWidget {
  const RequestHelpScreen({super.key});

  @override
  State<RequestHelpScreen> createState() => _RequestHelpScreenState();
}

class _RequestHelpScreenState extends State<RequestHelpScreen> {
  late Future<List<BenefitOffering>> _future;
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<BenefitOffering>> _fetch() =>
      context.read<BenefitRepository>().offerings();

  void _reload() => setState(() => _future = _fetch());

  /// Opens the charity step, or skips straight to the questions when only one
  /// charity offers this benefit — there would be nothing to choose.
  Future<void> _choose(BenefitOffering offering) async {
    final submitted = offering.isSingleCharity
        ? await context.push<bool>(
            '/benefits/apply',
            extra: offering.types.single,
          )
        : await context.push<bool>('/help/offering', extra: offering);
    // Applying leaves nothing to update on this screen, so send the user to
    // their applications where the new request is now visible.
    if (submitted == true && mounted) context.go('/benefits/my');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBackAppBar(title: Text('طلب مساعدة')),
    body: FutureBuilder<List<BenefitOffering>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SkeletonList(count: 5);
        }
        if (snapshot.hasError) {
          return ErrorRetry(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final all = snapshot.data ?? const <BenefitOffering>[];
        if (all.isEmpty) {
          return EmptyView(
            message: 'لا توجد مساعدات متاحة حاليًا. حاول لاحقًا.',
            icon: Icons.volunteer_activism_outlined,
            actionLabel: 'إعادة المحاولة',
            onAction: _reload,
          );
        }

        final query = _search.trim().toLowerCase();
        final visible = query.isEmpty
            ? all
            : all
                  .where(
                    (offering) =>
                        offering.name.toLowerCase().contains(query) ||
                        offering.types.any(
                          (type) =>
                              type.charityName.toLowerCase().contains(query),
                        ),
                  )
                  .toList();

        return Column(
          children: [
            const _Intro(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: 'ابحث عن نوع المساعدة...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const EmptyView(
                      message: 'لا توجد نتائج مطابقة لبحثك.',
                      icon: Icons.search_off,
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _OfferingCard(
                          offering: visible[index],
                          onTap: () => _choose(visible[index]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.handshake, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'اختر نوع المساعدة التي تحتاجها، ثم الجمعية التي ترغب بالتقديم لديها.',
            style: TextStyle(
              height: 1.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    ),
  );
}

class _OfferingCard extends StatelessWidget {
  const _OfferingCard({required this.offering, required this.onTap});

  final BenefitOffering offering;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = offering.types.length;

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
        onTap: onTap,
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
                      offering.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // Naming the single charity up front saves a tap's worth
                      // of uncertainty, since that flow skips the charity step.
                      offering.isSingleCharity
                          ? offering.types.single.charityName.isEmpty
                                ? 'جمعية واحدة'
                                : offering.types.single.charityName
                          : '$count جمعيات تقدم هذه المساعدة',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    if (offering.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        offering.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5),
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
  }
}
