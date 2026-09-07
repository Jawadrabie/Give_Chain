import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_enums.dart';
import '../../../core/network/url_resolver.dart';
import '../../../core/state/async_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../media/ui/media_gallery_screen.dart';
import '../data/donation_models.dart';
import '../data/donation_repository.dart';
import '../logic/donation_cubit.dart';
import '../services/pdf_receipt_service.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class DonationHistoryScreen extends StatelessWidget {
  const DonationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        DonationHistoryCubit(context.read<DonationRepository>())..load(),
    child: const _DonationHistoryView(),
  );
}

class _DonationHistoryView extends StatefulWidget {
  const _DonationHistoryView();

  @override
  State<_DonationHistoryView> createState() => _DonationHistoryViewState();
}

class _DonationHistoryViewState extends State<_DonationHistoryView> {
  int _selectedFilter = 0; // 0: الكل, 1: قيد المراجعة, 2: في المركز, 3: موثّقة, 4: مرفوضة

  void _applyFilter(int filter) {
    setState(() => _selectedFilter = filter);
    final cubit = context.read<DonationHistoryCubit>();
    switch (filter) {
      case 1:
        cubit.load(status: 1);
        break;
      case 2:
        cubit.load(throughCenter: true);
        break;
      case 3:
        cubit.load(status: 3);
        break;
      case 4:
        cubit.load(status: 4);
        break;
      default:
        cubit.load();
        break;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DonationHistoryCubit, AsyncState<DonationHistorySnapshot>>(
        builder: (context, state) {
          final snapshot = state.data;
          final responses = snapshot?.responses ?? const <DonationResponse>[];
          final records = snapshot?.records ?? const <DonationRecord>[];
          return Scaffold(
            appBar: AppBackAppBar(
              title: const Text('تبرعاتي'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/donations/trace'),
                  tooltip: 'تتبع جميع التبرعات',
                  icon: const Icon(Icons.account_tree_outlined),
                ),
                IconButton(
                  onPressed: state.status == AsyncStatus.loading
                      ? null
                      : () => _applyFilter(_selectedFilter),
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: Column(
              children: [
                _filterBar(),
                Expanded(child: _body(context, state, responses, records)),
              ],
            ),
          );
        },
      );

  Widget _filterBar() {
    final filters = [
      (id: 0, label: 'الكل'),
      (id: 1, label: 'قيد المراجعة'),
      (id: 2, label: 'في المركز'),
      (id: 3, label: 'موثّقة'),
      (id: 4, label: 'مرفوضة'),
    ];
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];
          final isSelected = _selectedFilter == item.id;
          return FilterChip(
            selected: isSelected,
            label: Text(item.label),
            onSelected: (_) => _applyFilter(item.id),
            selectedColor: AppTheme.primary.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.primary,
            labelStyle: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppTheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AsyncState<DonationHistorySnapshot> state,
    List<DonationResponse> responses,
    List<DonationRecord> records,
  ) {
    if (state.status == AsyncStatus.loading && state.data == null) {
      return const SkeletonList();
    }
    if (state.status == AsyncStatus.failure && state.data == null) {
      return ErrorRetry(
        message: state.message ?? 'تعذر تحميل التبرعات',
        onRetry: context.read<DonationHistoryCubit>().load,
      );
    }
    if (responses.isEmpty && records.isEmpty) {
      return const EmptyView(message: 'لا توجد تبرعات حتى الآن.');
    }
    final warning = state.data?.warning ?? state.message;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 320) {
          context.read<DonationHistoryCubit>().loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: context.read<DonationHistoryCubit>().load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount:
              (responses.isNotEmpty ? responses.length : records.length) +
              (warning == null ? 0 : 1) +
              (state.data?.hasMore == true ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (warning != null && index == 0) {
              return Card(
                color: AppTheme.warningSurfaceOf(context),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    warning,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }
            final itemIndex = warning == null ? index : index - 1;
            final sourceLength = responses.isNotEmpty
                ? responses.length
                : records.length;
            if (itemIndex >= sourceLength) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (responses.isNotEmpty) {
              return _ResponseCard(item: responses[itemIndex]);
            }
            return _LocalRecordCard(item: records[itemIndex]);
          },
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.item});
  final DonationResponse item;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: item.id.isEmpty
          ? null
          : () => context.push('/donations/${item.id}/detail', extra: item),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.softOf(context),
                  child: Icon(
                    item.donationType == 1
                        ? Icons.payments_outlined
                        : item.donationType == 2
                        ? Icons.inventory_2_outlined
                        : Icons.handyman_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.targetName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (item.isTrusted) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: AppTheme.primary,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${item.typeLabel} • ${DateFormat('yyyy-MM-dd').format(item.donationDate.toLocal())}',
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    item.statusLabel,
                    style: TextStyle(
                      color: ApiEnums.statusColor(
                        item.status,
                        family: 'donation',
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: ApiEnums.statusColor(
                    item.status,
                    family: 'donation',
                  ).withValues(alpha: 0.12),
                  side: BorderSide(
                    color: ApiEnums.statusColor(
                      item.status,
                      family: 'donation',
                    ),
                  ),
                ),
              ],
            ),
            if (item.amount != null) ...[
              const SizedBox(height: 10),
              Text('المبلغ: ${NumberFormat('#,##0.##').format(item.amount)}'),
            ],
            if (item.itemName.isNotEmpty)
              Text('الصنف: ${item.itemName} • الكمية: ${item.quantity ?? 0}'),
            if (item.serviceDescription.isNotEmpty)
              Text('الخدمة: ${item.serviceDescription}'),
            if (item.verificationNotes.isNotEmpty)
              Text('ملاحظات التحقق: ${item.verificationNotes}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (item.paymentUrl?.isNotEmpty == true)
                  TextButton.icon(
                    onPressed: () => _open(item.paymentUrl!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('متابعة الدفع'),
                  ),
                if (item.needsProofUpload && item.id.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => context.push(
                      '/donations/${item.id}/detail',
                      extra: item,
                    ),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('أرفق الإثبات'),
                  ),
                if (item.id.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/donations/${item.id}/trace'),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('تتبع'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class DonationDetailScreen extends StatefulWidget {
  const DonationDetailScreen({super.key, required this.id, this.initial});
  final String id;
  final DonationResponse? initial;

  @override
  State<DonationDetailScreen> createState() => _DonationDetailScreenState();
}

class _DonationDetailScreenState extends State<DonationDetailScreen> {
  late Future<DonationResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.initial == null
        ? context.read<DonationRepository>().findInHistory(widget.id)
        : Future.value(widget.initial!);
  }

  void _reload() => setState(() {
    _future = context.read<DonationRepository>().findInHistory(widget.id);
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<DonationResponse>(
    future: _future,
    builder: (context, snapshot) {
      final item = snapshot.data;
      return Scaffold(
        appBar: AppBackAppBar(title: const Text('تفاصيل التبرع')),
        body: snapshot.connectionState != ConnectionState.done && item == null
            ? const Center(child: CircularProgressIndicator())
            : snapshot.hasError && item == null
            ? ErrorRetry(message: snapshot.error.toString(), onRetry: _reload)
            : item == null
            ? const EmptyView(message: 'تعذر العثور على التبرع.')
            : RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.softOf(context),
                          child: Icon(
                            item.donationType == 1
                                ? Icons.payments_outlined
                                : item.donationType == 2
                                ? Icons.inventory_2_outlined
                                : Icons.handyman_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.targetName,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(item.donationDate.toLocal()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(item.typeLabel)),
                        Chip(
                          label: Text(
                            item.statusLabel,
                            style: TextStyle(
                              color: ApiEnums.statusColor(
                                item.status,
                                family: 'donation',
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor: ApiEnums.statusColor(
                            item.status,
                            family: 'donation',
                          ).withValues(alpha: 0.12),
                          side: BorderSide(
                            color: ApiEnums.statusColor(
                              item.status,
                              family: 'donation',
                            ),
                          ),
                        ),
                        if (item.paymentMethod != null)
                          Chip(label: Text(item.paymentMethodLabel)),
                        if (item.paymentStatus != null)
                          Chip(
                            label: Text(
                              ApiEnums.paymentStatus[item.paymentStatus!] ??
                                  'حالة دفع غير معروفة',
                            ),
                          ),
                        if (item.isTrusted)
                          Chip(
                            avatar: const Icon(
                              Icons.verified,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                            label: const Text('حملة موثوقة'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Column(
                        children: [
                          if (item.amount != null)
                            _detailTile(
                              Icons.payments_outlined,
                              'المبلغ',
                              NumberFormat('#,##0.##').format(item.amount),
                            ),
                          if (item.acceptedAmount != null)
                            _detailTile(
                              Icons.verified_outlined,
                              'المبلغ المقبول',
                              NumberFormat(
                                '#,##0.##',
                              ).format(item.acceptedAmount),
                            ),
                          if (item.itemName.isNotEmpty)
                            _detailTile(
                              Icons.inventory_2_outlined,
                              'الصنف',
                              item.itemName,
                            ),
                          if (item.itemDescription.isNotEmpty)
                            _detailTile(
                              Icons.notes_outlined,
                              'وصف الصنف',
                              item.itemDescription,
                            ),
                          if (item.quantity != null)
                            _detailTile(
                              Icons.numbers,
                              'الكمية',
                              '${item.quantity} ${item.unit == null ? '' : ApiEnums.unit[item.unit] ?? ''}',
                            ),
                          if (item.acceptedQuantity != null)
                            _detailTile(
                              Icons.verified_outlined,
                              'الكمية المقبولة',
                              '${item.acceptedQuantity}',
                            ),
                          if (item.serviceDescription.isNotEmpty)
                            _detailTile(
                              Icons.handyman_outlined,
                              'الخدمة',
                              item.serviceDescription,
                            ),
                          if (item.scheduledAt != null)
                            _detailTile(
                              Icons.event_outlined,
                              'الموعد',
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(item.scheduledAt!.toLocal()),
                            ),
                          if (item.deliveryMethod != null)
                            _detailTile(
                              Icons.local_shipping_outlined,
                              'طريقة التسليم',
                              ApiEnums.deliveryMethod[item.deliveryMethod!] ??
                                  'غير معروفة',
                            ),
                          if (item.paymentReference?.isNotEmpty == true)
                            _detailTile(
                              Icons.receipt_long_outlined,
                              'مرجع الدفع',
                              item.paymentReference!,
                            ),
                          if (item.message.isNotEmpty)
                            _detailTile(
                              Icons.message_outlined,
                              'الرسالة',
                              item.message,
                            ),
                        ],
                      ),
                    ),
                    if (item.verificationNotes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Card(
                        color: item.status == 4
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppTheme.successSurfaceOf(context),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                item.status == 4 ? Icons.error_outline : Icons.verified_outlined,
                                color: item.status == 4 ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${item.status == 4 ? "سبب الرفض:" : "ملاحظات التحقق:"}\n${item.verificationNotes}',
                                  style: TextStyle(
                                    color: item.status == 4 ? Colors.red.shade900 : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: item.status == 4 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (item.mediaUrls.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'المرفقات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: item.mediaUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => InkWell(
                            onTap: () => context.push(
                              '/media-gallery',
                              extra: MediaGalleryArgs(
                                urls: item.mediaUrls,
                                initialIndex: index,
                                title: 'مرفقات التبرع',
                              ),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                UrlResolver.resolve(item.mediaUrls[index]),
                                width: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  width: 180,
                                  child: Icon(Icons.insert_drive_file_outlined),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (item.needsProofUpload) ...[
                      Card(
                        color: Colors.amber.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                                  SizedBox(width: 8),
                                  Text('إشعار التحويل البنكي مطلوب', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text('هذا التبرع بحاجة لإرفاق صورة إشعار التحويل لتتمكن إدارة المنصة من التوثيق.', style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _uploadProof(context, item.id),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('أرفق إشعار التحويل الآن'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 16),
                    if (item.status == 3 || item.status == 1)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.teal.shade700,
                        ),
                        onPressed: () => PdfReceiptService.exportAndPrintReceipt(item),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('تحميل / طباعة الإيصال الرسمي (PDF)'),
                      ),
                  ],
                ),
              ),
      );
    },
  );

  Future<void> _uploadProof(BuildContext context, String donationId) async {
    final repository = context.read<DonationRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    try {
      await repository.uploadProof(donationId, [path]);
      messenger.showSnackBar(
        const SnackBar(content: Text('تم رفع إشعار التحويل بنجاح، التبرع قيد المراجعة.')),
      );
      _reload();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر رفع الإشعار: $e')),
      );
    }
  }

  Widget _detailTile(IconData icon, String title, String value) => ListTile(
    leading: Icon(icon, color: AppTheme.primary),
    title: Text(title),
    subtitle: SelectableText(value),
  );
}

class _LocalRecordCard extends StatelessWidget {
  const _LocalRecordCard({required this.item});
  final DonationRecord item;
  @override
  Widget build(BuildContext context) {
    final status = int.tryParse(item.status) ?? 0;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(item.targetTitle),
        subtitle: Text(
          '${DateFormat('yyyy-MM-dd').format(item.createdAt.toLocal())} • ${ApiEnums.donationStatus[status] ?? item.status}',
        ),
        trailing: item.remoteId == null
            ? null
            : IconButton(
                onPressed: () =>
                    context.push('/donations/${item.remoteId}/trace'),
                icon: const Icon(Icons.account_tree_outlined),
              ),
      ),
    );
  }
}
