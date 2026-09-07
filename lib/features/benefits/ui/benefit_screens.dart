import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_back_app_bar.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../data/benefit_models.dart';
import '../data/benefit_repository.dart';
import 'benefit_requests_list.dart';

/// The benefit types one charity offers, as a standalone screen.
///
/// Reached from the charity's Benefits tab via "تصفح المنافع المتاحة"; tapping
/// a type opens its details, which lead into the shared apply flow.
class CharityBenefitTypesScreen extends StatefulWidget {
  const CharityBenefitTypesScreen({
    super.key,
    required this.charityId,
    this.charityName = '',
  });
  final String charityId;
  final String charityName;

  @override
  State<CharityBenefitTypesScreen> createState() =>
      _CharityBenefitTypesScreenState();
}

class _CharityBenefitTypesScreenState extends State<CharityBenefitTypesScreen> {
  late Future<List<BenefitType>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<BenefitType>> _fetch() =>
      context.read<BenefitRepository>().benefitTypes(
        charityId: widget.charityId,
      );

  void _reload() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(
      title: Text(
        widget.charityName.isEmpty
            ? 'المنافع المتاحة'
            : 'منافع ${widget.charityName}',
      ),
    ),
    body: FutureBuilder<List<BenefitType>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SkeletonList(count: 4);
        }
        if (snapshot.hasError) {
          return ErrorRetry(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const EmptyView(
            message: 'لا توجد أنواع منافع فعالة حاليًا.',
            icon: Icons.redeem_outlined,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.redeem_outlined),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: item.description.isEmpty
                      ? null
                      : Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push(
                    '/charities/${widget.charityId}/benefits/${item.id}',
                    extra: item,
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

/// "منافعي" — every benefit application the signed-in user has submitted,
/// across all charities. Reached from the profile.
///
/// Read-only: applying happens from the charity's Benefits tab or from "هل
/// تحتاج إلى مساعدة؟" on the home screen, not from here.
class MyBenefitsScreen extends StatelessWidget {
  const MyBenefitsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('طلبات المنافع')),
    body: const BenefitRequestsList(),
  );
}

/// One application in full: its answers and, once reviewed, the outcome.
class BenefitRequestDetailScreen extends StatefulWidget {
  const BenefitRequestDetailScreen({super.key, required this.id, this.initial});
  final String id;
  final BenefitRequest? initial;

  @override
  State<BenefitRequestDetailScreen> createState() =>
      _BenefitRequestDetailScreenState();
}

class _BenefitRequestDetailScreenState
    extends State<BenefitRequestDetailScreen> {
  late Future<BenefitRequest> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.initial == null
        ? context.read<BenefitRepository>().findMine(widget.id)
        : Future.value(widget.initial!);
  }

  void _reload() => setState(() {
    _future = context.read<BenefitRepository>().findMine(widget.id);
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<BenefitRequest>(
    future: _future,
    builder: (context, snapshot) {
      final request = snapshot.data;
      return Scaffold(
        appBar: AppBackAppBar(
          title: Text(request?.requestNumber ?? 'تفاصيل الطلب'),
        ),
        body:
            snapshot.connectionState != ConnectionState.done && request == null
            ? const SkeletonList(count: 4)
            : snapshot.hasError && request == null
            ? ErrorRetry(message: snapshot.error.toString(), onRetry: _reload)
            : request == null
            ? const EmptyView(message: 'تعذر العثور على الطلب.')
            : _Details(request: request, onRefresh: _reload),
      );
    },
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.request, required this.onRefresh});
  final BenefitRequest request;
  final VoidCallback onRefresh;

  static final _dateTime = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = benefitStatusStyle(request.status);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            request.benefitTypeName.isEmpty
                ? 'طلب منفعة'
                : request.benefitTypeName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (request.charityName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              request.charityName,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BenefitStatusPill(status: request.status, style: style),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.tag,
            label: 'رقم الطلب',
            value: request.requestNumber,
          ),
          if (request.submittedAtOrNull != null)
            _InfoRow(
              icon: Icons.event_outlined,
              label: 'تاريخ التقديم',
              value: _dateTime.format(request.submittedAtOrNull!.toLocal()),
            ),
          // Review data is only meaningful once a reviewer has acted, so the
          // whole block stays hidden while the request is pending.
          if (request.isReviewed) ...[
            if (request.reviewedAt != null)
              _InfoRow(
                icon: Icons.fact_check_outlined,
                label: 'تاريخ المراجعة',
                value: _dateTime.format(request.reviewedAt!.toLocal()),
              ),
            if (request.reviewNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: style.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: style.textColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 18, color: style.textColor),
                        const SizedBox(width: 8),
                        Text(
                          'ملاحظات المراجعة',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: style.textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      request.reviewNotes,
                      style: TextStyle(height: 1.6, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          const Text(
            'الإجابات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (request.answers.isEmpty)
            Text(
              'لم تُسجل إجابات لهذا الطلب.',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          else
            for (final answer in request.answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        answer.questionText.isEmpty
                            ? 'سؤال'
                            : answer.questionText,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        answer.answer.isEmpty ? '—' : answer.answer,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
