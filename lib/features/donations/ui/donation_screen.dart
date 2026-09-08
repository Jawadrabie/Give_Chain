import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_enums.dart';
import '../../../core/state/async_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../centers/data/center_repository.dart';
import '../../centers/ui/center_picker_widget.dart';
import '../data/donation_models.dart';
import '../data/donation_repository.dart';
import '../logic/donation_cubit.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../../core/widgets/app_dropdown_form_field.dart';
import '../../../core/widgets/sticky_action_button.dart';

class DonationEntryScreen extends StatefulWidget {
  const DonationEntryScreen({
    super.key,
    required this.id,
    required this.isCampaign,
  });
  final String id;
  final bool isCampaign;

  @override
  State<DonationEntryScreen> createState() => _DonationEntryScreenState();
}

class _DonationEntryScreenState extends State<DonationEntryScreen> {
  late Future<CatalogItem> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Always hits the network: a cached case can be missing needs that now
  /// exist (or list ones already fulfilled), and the donation form is the one
  /// place where acting on stale data means a rejected submission.
  Future<CatalogItem> _load() => widget.isCampaign
      ? context.read<CatalogRepository>().campaign(
          widget.id,
          forceRefresh: true,
        )
      : context.read<CatalogRepository>().caseById(
          widget.id,
          forceRefresh: true,
        );

  @override
  Widget build(BuildContext context) => FutureBuilder<CatalogItem>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          appBar: AppBackAppBar(),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Scaffold(
          appBar: const AppBackAppBar(),
          body: ErrorRetry(
            message: snapshot.error?.toString() ?? 'تعذر تحميل الهدف',
            onRetry: () => setState(() => _future = _load()),
          ),
        );
      }
      return DonationScreen(
        data: DonationRouteData(
          target: snapshot.data!,
          targetType: widget.isCampaign ? 1 : 2,
        ),
        onReloadTarget: () => setState(() => _future = _load()),
      );
    },
  );
}

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key, required this.data, this.onReloadTarget});
  final DonationRouteData data;

  /// Refetches the target. Supplied by the entry screen, which owns the
  /// future; absent when the target was handed over directly.
  final VoidCallback? onReloadTarget;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DonationCubit(context.read<DonationRepository>()),
    child: _DonationView(data: data, onReloadTarget: onReloadTarget),
  );
}

class _DonationView extends StatefulWidget {
  const _DonationView({required this.data, this.onReloadTarget});
  final DonationRouteData data;
  final VoidCallback? onReloadTarget;

  @override
  State<_DonationView> createState() => _DonationViewState();
}

class _DonationViewState extends State<_DonationView> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _amount = TextEditingController();
  final _itemName = TextEditingController();
  final _itemDescription = TextEditingController();
  final _quantity = TextEditingController();
  final _serviceDescription = TextEditingController();

  int _donationType = 1;
  int _paymentMethod = 0;
  int _unit = 3;
  int _deliveryMethod = 1;
  String? _caseNeedId;
  String? _centerId;
  DateTime? _scheduledAt;
  final _attachments = <String>[];

  @override
  void dispose() {
    for (final controller in [
      _message,
      _amount,
      _itemName,
      _itemDescription,
      _quantity,
      _serviceDescription,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackAppBar(
        title: Text(
          widget.data.isCampaign
              ? 'التبرع للحملة'
              : widget.data.isCase
                  ? 'التبرع للحالة'
                  : 'تبرع مباشر للجمعية',
        ),
      ),
      body: BlocConsumer<DonationCubit, AsyncState<DonationResponse>>(
        listener: (context, state) {
          if (state.status == AsyncStatus.success && state.data != null) {
            context.go('/donation-result', extra: state.data);
          } else if (state.status == AsyncStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message ?? 'تعذر إرسال التبرع')),
            );
          }
        },
        builder: (context, state) {
          final loading = state.status == AsyncStatus.loading;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                _targetCard(),
                const SizedBox(height: 24),
                _FormSection(
                  title: 'نوع التبرع',
                  icon: Icons.tune,
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 1,
                        label: const Text('مالي'),
                        icon: const Icon(Icons.payments_outlined),
                        enabled: _typeAllowed(1),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: const Text('عيني'),
                        icon: const Icon(Icons.inventory_2_outlined),
                        enabled: _typeAllowed(2),
                      ),
                      // Service donations are only offered for a direct
                      // charity donation; campaigns and cases only take
                      // money or in-kind donations.
                      if (widget.data.isCharity)
                        ButtonSegment(
                          value: 3,
                          label: const Text('خدمة'),
                          icon: const Icon(Icons.handyman_outlined),
                          enabled: _typeAllowed(3),
                        ),
                    ],
                    selected: {_donationType},
                    onSelectionChanged: loading
                        ? null
                        : (value) =>
                              setState(() => _donationType = value.first),
                  ),
                ),
                if (widget.data.isCase && _selectedNeed?.allowedDonationType != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'الاحتياج المحدد لهذه الحالة يقبل تبرعات '
                      '${ApiEnums.donationType[_selectedNeed!.allowedDonationType] ?? ''} '
                      'فقط.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
                if (widget.data.isCase) ...[
                  const SizedBox(height: 16),
                  _FormSection(
                    title: 'الاحتياج المطلوب تمويله',
                    icon: Icons.checklist_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _caseNeedField(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _FormSection(
                  title: switch (_donationType) {
                    1 => 'تفاصيل التبرع المالي',
                    2 => 'تفاصيل التبرع العيني',
                    _ => 'تفاصيل الخدمة المقدَّمة',
                  },
                  icon: switch (_donationType) {
                    1 => Icons.payments_outlined,
                    2 => Icons.inventory_2_outlined,
                    _ => Icons.handyman_outlined,
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_donationType == 1) ..._moneyFields(),
                      if (_donationType == 2) ..._itemFields(),
                      if (_donationType == 3) ..._serviceFields(),
                    ],
                  ),
                ),
                if (_donationType != 3) ...[
                  const SizedBox(height: 16),
                  _FormSection(
                    title: 'مركز الاستلام',
                    icon: Icons.storefront_outlined,
                    child: CenterPickerTile(
                      repository: context.read<CenterRepository>(),
                      selectedCenterId: _centerId,
                      onCenterChanged: (center) =>
                          setState(() => _centerId = center?.id),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _FormSection(
                  title: 'رسالة للجمعية',
                  icon: Icons.mail_outline,
                  optional: true,
                  child: TextFormField(
                    controller: _message,
                    enabled: !loading,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة قصيرة تُرفق مع تبرعك',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: _requiresProofAttachment
                      ? 'صورة إشعار التحويل'
                      : 'المرفقات',
                  icon: Icons.attach_file,
                  optional: !_requiresProofAttachment,
                  trailing: loading
                      ? null
                      : TextButton.icon(
                          onPressed: _pickAttachments,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة'),
                        ),
                  child: _attachmentsContent(),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar:
          BlocBuilder<DonationCubit, AsyncState<DonationResponse>>(
            builder: (context, state) {
              final loading = state.status == AsyncStatus.loading;
              return StickyActionButton(
                label: loading ? 'جارٍ الإرسال...' : 'مراجعة وتأكيد التبرع',
                // A case with no needs cannot produce a valid request, so
                // the button is disabled rather than failing on tap.
                onPressed: loading || _isBlockedCase ? null : _review,
                icon: Icons.fact_check_outlined,
                loading: loading,
              );
            },
          ),
    );
  }

  Widget _targetCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.surface,
            child: const Icon(Icons.favorite, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data.target.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.data.isCampaign
                      ? 'حملة'
                      : widget.data.isCase
                      ? 'حالة'
                      : 'جمعية',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The case's donatable needs. A case donation is rejected server-side
  /// without a `caseNeedId` (there is no automatic fallback), so an empty
  /// list means we cannot submit at all.
  List<CaseNeed> _caseNeeds() => widget.data.target.caseNeeds;

  /// A case donation without a `caseNeedId` is always rejected, so a case
  /// that exposes no needs cannot be donated to at all.
  bool get _isBlockedCase => widget.data.isCase && _caseNeeds().isEmpty;

  /// A bank transfer can only be verified from an uploaded receipt, so the
  /// attachment stops being optional once that payment method is chosen.
  bool get _requiresProofAttachment =>
      _donationType == 1 && _paymentMethod == 1;

  /// Whether [type] is a valid `DonationType` for the currently selected
  /// case need. The server rejects a mismatch (e.g. a money donation
  /// against an item-only need), so this gates the type picker itself
  /// rather than just seeding its initial value. Every type stays open when
  /// no need is selected yet, or the need gives no signal either way.
  bool _typeAllowed(int type) {
    final allowed = _selectedNeed?.allowedDonationType;
    return allowed == null || allowed == type;
  }

  CaseNeed? get _selectedNeed {
    final id = _caseNeedId;
    if (id == null) return null;
    for (final need in _caseNeeds()) {
      if (need.id == id) return need;
    }
    return null;
  }

  /// Locks the donation type to whatever the newly selected need accepts.
  ///
  /// `CaseNeedType` (0-3) and `DonationType` (1-3) are *different* enums, so
  /// the raw value must never be copied across. The need's shape is the
  /// reliable signal: a money need carries `amount`, an in-kind one carries
  /// `quantity`/`unit`. This is enforced, not just suggested — the server
  /// rejects a type/need mismatch, so switching to a need that only accepts
  /// one type must move `_donationType` off any now-disabled segment.
  void _selectNeed(String? id) {
    setState(() {
      _caseNeedId = id;
      final allowed = _selectedNeed?.allowedDonationType;
      if (allowed != null) _donationType = allowed;
    });
  }

  /// Describes what a need still asks for, e.g. "مطلوب 250 ر.س • تم 40".
  String _needSubtitle(CaseNeed need) {
    final parts = <String>[];
    final amount = need.amount ?? 0;
    final quantity = need.quantity ?? 0;
    if (amount > 0) {
      parts.add('مطلوب ${_trimNumber(amount)}');
      final done = need.fulfilledAmount ?? 0;
      if (done > 0) parts.add('تم ${_trimNumber(done)}');
    } else if (quantity > 0) {
      final unit = need.unitLabel;
      parts.add(
        'مطلوب ${_trimNumber(quantity)}${unit.isEmpty ? '' : ' $unit'}',
      );
      final done = need.fulfilledQuantity ?? 0;
      if (done > 0) parts.add('تم ${_trimNumber(done)}');
    }
    final type = need.typeLabel;
    if (type.isNotEmpty) parts.add(type);
    return parts.join(' • ');
  }

  static String _trimNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  List<Widget> _caseNeedField() {
    final needs = _caseNeeds();
    if (needs.isEmpty) {
      // Without a need to fund, the server will reject this donation. Say so
      // up front instead of letting the donor fill the form and fail on submit.
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لم تحدّد الجمعية بعد أي احتياج قابل للتبرع في هذه '
                      'الحالة، لذلك لا يمكن إتمام التبرع لها. جرّب حالة أو '
                      'حملة أخرى، أو تبرّع مباشرة للجمعية.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.onReloadTarget != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: widget.onReloadTarget,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('تحديث'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ];
    }
    final selected = _selectedNeed;
    return [
      AppDropdownFormField<String>(
        initialValue: _caseNeedId,
        decoration: const InputDecoration(
          labelText: 'الاحتياج المحدد (مطلوب للحالات)',
          prefixIcon: Icon(Icons.checklist_outlined),
        ),
        validator: (value) =>
            widget.data.isCase && (value?.trim().isEmpty ?? true)
                ? 'يلزم تحديد الاحتياج المطلوب تمويله'
                : null,
        // The dropdown renders each item's label in the collapsed field as
        // well as the menu, so keep the item a single Text and show the
        // quantity/progress detail in the summary card below instead.
        items: needs
            .map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: Text(
                  item.isFulfilled ? '${item.name} (مكتمل)' : item.name,
                ),
              ),
            )
            .toList(),
        onChanged: _selectNeed,
      ),
      if (selected != null) ...[
        const SizedBox(height: 10),
        _NeedSummary(
          need: selected,
          subtitle: _needSubtitle(selected),
          typeLabel: ApiEnums.donationType[selected.caseNeedType] ?? '',
        ),
      ],
      const SizedBox(height: 14),
    ];
  }

  List<Widget> _moneyFields() => [
    TextFormField(
      controller: _amount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'المبلغ'),
      validator: (value) {
        if (_donationType != 1) return null;
        final amount = double.tryParse(value ?? '');
        return amount == null || amount <= 0 ? 'أدخل مبلغًا صحيحًا' : null;
      },
    ),
    const SizedBox(height: 14),
    AppDropdownFormField<int>(
      initialValue: _paymentMethod,
      decoration: const InputDecoration(
        labelText: 'طريقة الدفع',
        prefixIcon: Icon(Icons.credit_card),
      ),
      items: ApiEnums.paymentMethod.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: (value) => setState(() => _paymentMethod = value ?? 0),
    ),
    if (_paymentMethod == 1) ...[
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'عند التحويل البنكي، يرجى إرفاق صورة إشعار التحويل في المرفقات أدناه ليتم التوثيق.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
              ),
            ),
          ],
        ),
      ),
    ],
  ];

  List<Widget> _itemFields() => [
    TextFormField(
      controller: _itemName,
      decoration: const InputDecoration(
        labelText: 'اسم المادة أو الصنف',
        prefixIcon: Icon(Icons.inventory_outlined),
      ),
      validator: (value) =>
          _donationType == 2 && (value?.trim().isEmpty ?? true)
          ? 'اسم الصنف مطلوب'
          : null,
    ),
    const SizedBox(height: 14),
    TextFormField(
      controller: _itemDescription,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(labelText: 'وصف الصنف (اختياري)'),
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الكمية'),
            validator: (value) {
              if (_donationType != 2) return null;
              final number = int.tryParse(value ?? '');
              return number == null || number <= 0 ? 'كمية غير صحيحة' : null;
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppDropdownFormField<int>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'الوحدة'),
            items: ApiEnums.unit.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _unit = value ?? 3),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    _deliveryField(),
  ];

  List<Widget> _serviceFields() => [
    TextFormField(
      controller: _serviceDescription,
      minLines: 3,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: 'وصف الخدمة',
        alignLabelWithHint: true,
        prefixIcon: Icon(Icons.handyman_outlined),
      ),
      validator: (value) =>
          _donationType == 3 && (value?.trim().isEmpty ?? true)
          ? 'وصف الخدمة مطلوب'
          : null,
    ),
    const SizedBox(height: 14),
    InkWell(
      onTap: _pickSchedule,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'موعد تقديم الخدمة (اختياري)',
          prefixIcon: Icon(Icons.event_outlined),
        ),
        child: Text(
          _scheduledAt == null
              ? 'بدون موعد محدد'
              : DateFormat('yyyy-MM-dd HH:mm').format(_scheduledAt!),
        ),
      ),
    ),
    const SizedBox(height: 14),
    _deliveryField(),
  ];

  Widget _deliveryField() => AppDropdownFormField<int>(
    initialValue: _deliveryMethod,
    decoration: const InputDecoration(
      labelText: 'طريقة التسليم',
      prefixIcon: Icon(Icons.local_shipping_outlined),
    ),
    items: ApiEnums.deliveryMethod.entries
        .map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        )
        .toList(),
    onChanged: (value) => setState(() => _deliveryMethod = value ?? 1),
  );

  Widget _attachmentsContent() {
    if (_attachments.isEmpty) {
      return Text(
        _requiresProofAttachment
            ? 'أرفق صورة إشعار التحويل البنكي (مطلوب)'
            : 'صور أو مستندات اختيارية',
        style: TextStyle(
          fontSize: 13,
          color: _requiresProofAttachment
              ? Colors.red.shade700
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _attachments.map((path) {
        final isImage =
            path.toLowerCase().endsWith('.jpg') ||
            path.toLowerCase().endsWith('.jpeg') ||
            path.toLowerCase().endsWith('.png');
        return Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: () => _previewFile(path, isImage),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: isImage
                    ? Image.file(File(path), fit: BoxFit.cover)
                    : const Icon(
                        Icons.insert_drive_file,
                        size: 32,
                        color: Colors.grey,
                      ),
              ),
            ),
            Positioned(
              top: -6,
              left: -6,
              child: InkWell(
                onTap: () => setState(() => _attachments.remove(path)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _previewFile(String path, bool isImage) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('معاينة المرفق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        maxScale: 4.0,
                        child: Image.file(
                          File(path),
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.insert_drive_file, size: 80, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 16),
                          const Text('معاينة هذا الملف غير متاحة حالياً كصورة', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null) return;
    const maxBytes = 50 * 1024 * 1024;
    final totalBytes = result.files.fold<int>(
      0,
      (sum, file) => sum + file.size,
    );
    if (totalBytes > maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب ألا يتجاوز مجموع المرفقات 50 ميغابايت.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _attachments
        ..clear()
        ..addAll(result.files.map((file) => file.path).whereType<String>());
    });
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  DonationRequest _request() => DonationRequest(
    targetId: widget.data.target.id,
    targetType: widget.data.targetType,
    donationType: _donationType,
    caseNeedId: _caseNeedId,
    centerId: _donationType != 3 ? _centerId : null,
    message: _message.text,
    amount: _donationType == 1 ? double.tryParse(_amount.text) : null,
    paymentMethod: _donationType == 1 ? _paymentMethod : null,
    itemName: _itemName.text,
    itemDescription: _itemDescription.text,
    quantity: _donationType == 2 ? int.tryParse(_quantity.text) : null,
    unit: _donationType == 2 ? _unit : null,
    serviceDescription: _serviceDescription.text,
    scheduledAt: _scheduledAt,
    deliveryMethod: _donationType == 1 ? null : _deliveryMethod,
    attachments: List.unmodifiable(_attachments),
  );

  Future<void> _review() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_formKey.currentState?.validate() != true) return;
    // The server requires a caseNeedId for every case donation and never
    // infers one, so refuse to submit rather than trigger a 400.
    if (widget.data.isCase && (_caseNeedId?.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يلزم تحديد الاحتياج المطلوب تمويله قبل إرسال التبرع لهذه الحالة.',
          ),
        ),
      );
      return;
    }
    // Belt-and-suspenders: the type picker already disables any segment the
    // selected need does not accept, but guard the submit too in case that
    // state ever gets out of sync, rather than let the server 400 it.
    if (!_typeAllowed(_donationType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نوع التبرع المحدد لا يطابق الاحتياج المختار لهذه الحالة.'),
        ),
      );
      return;
    }
    // A bank transfer can only be verified from an uploaded receipt, so
    // refuse to submit without one rather than leaving the donation stuck.
    if (_requiresProofAttachment && _attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يلزم إرفاق صورة إشعار التحويل البنكي قبل إرسال التبرع.',
          ),
        ),
      );
      return;
    }
    final request = _request();
    final amountLabel = request.amount != null
        ? '${request.amount}'
        : (ApiEnums.donationType[request.donationType] ?? 'تبرع');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد التبرع'),
        content: Text('هل تريد التبرع بـ $amountLabel؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (confirmed == true && mounted) {
      final cubit = context.read<DonationCubit>();
      if (widget.data.useGeneralEndpoint) {
        cubit.submitGeneral(request, targetTitle: widget.data.target.title);
      } else {
        cubit.submit(request, targetTitle: widget.data.target.title);
      }
    }
  }
}

class DonationResultScreen extends StatefulWidget {
  const DonationResultScreen({super.key, required this.response});
  final DonationResponse? response;

  @override
  State<DonationResultScreen> createState() => _DonationResultScreenState();
}

class _DonationResultScreenState extends State<DonationResultScreen>
    with SingleTickerProviderStateMixin {
  DonationResponse? _item;
  bool _refreshing = false;
  String? _refreshMessage;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _item = widget.response;
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();

    if (_item?.id.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStatus());
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final id = _item?.id.trim() ?? '';
    if (id.isEmpty || _refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshMessage = null;
    });
    try {
      final updated = await context.read<DonationRepository>().findInHistory(id);
      if (mounted) setState(() => _item = updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          _refreshMessage = 'قد تحتاج بوابة الدفع إلى وقت قصير لتحديث الحالة في الخادم.';
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final isError = item == null || item.status == 4 || item.status == 5;
    final isSuccess = item != null && item.status == 3;
    
    final iconColor = isError ? Colors.red : (isSuccess ? Colors.green : AppTheme.primary);
    final bgColor = isError ? Colors.red.withValues(alpha: 0.1) : (isSuccess ? Colors.green.withValues(alpha: 0.1) : AppTheme.primary.withValues(alpha: 0.1));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppBackAppBar(backgroundColor: Colors.transparent),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bgColor,
                  isDark ? scheme.surface : const Color(0xFFF8F9FB),
                  isDark ? scheme.surface : const Color(0xFFF8F9FB),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? scheme.surface : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: iconColor.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          isError ? Icons.error_outline : (isSuccess ? Icons.verified : Icons.favorite),
                          size: 72,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item == null
                          ? 'تعذر تحديد النتيجة'
                          : isError
                          ? 'لم تكتمل العملية'
                          : isSuccess
                          ? 'تم توثيق تبرعك بنجاح'
                          : 'شكرًا لعطائك ❤️',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Receipt Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? scheme.surfaceContainer : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'تفاصيل العملية',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),
                          
                          if (item != null) ...[
                            _receiptRow('الحالة', item.statusLabel,
                              color: ApiEnums.statusColor(item.status, family: 'donation')),
                            _receiptRow('تاريخ العملية', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
                          ],
                          
                          if (_refreshing) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                            const SizedBox(height: 8),
                            const Text('جاري تحديث الحالة...', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                          ],
                          if (_refreshMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                _refreshMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Actions
                    if (item?.id.isNotEmpty == true && !isSuccess)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _refreshing ? null : _refreshStatus,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('تحديث حالة العملية', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      
                    const SizedBox(height: 10),
                    if (item?.paymentUrl?.isNotEmpty == true)
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primaryLight]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => _openUrl(item!.paymentUrl!),
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('إكمال الدفع الإلكتروني', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                      
                    // A bank transfer with no receipt attached is stuck: the
                    // platform can only verify it from an uploaded proof, so
                    // this is the most important nudge on this screen.
                    if (item?.needsProofUpload == true && item!.id.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          foregroundColor: scheme.primary,
                        ),
                        onPressed: () =>
                            context.push('/donations/${item.id}/detail', extra: item),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('أرفق إشعار التحويل الآن', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    
                    if (item?.id.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: AppTheme.primary, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          foregroundColor: AppTheme.primary,
                        ),
                        onPressed: () => context.push('/donations/${item!.id}/trace'),
                        icon: const Icon(Icons.account_tree_outlined, size: 20),
                        label: const Text('تتبع مسار التبرع', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        foregroundColor: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('العودة إلى الرئيسية', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.w900, 
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class FundTraceScreen extends StatefulWidget {
  const FundTraceScreen({super.key, this.donationId});
  final String? donationId;

  @override
  State<FundTraceScreen> createState() => _FundTraceScreenState();
}

class _FundTraceScreenState extends State<FundTraceScreen> {
  Future<List<DonationResponse>>? _historyFuture;
  Future<DonationResponse>? _donationFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The aggregate view ("أين ذهبت تبرعاتي؟", no `donationId`) stacks every
  /// donation's own status tracker one after another — reading donation
  /// history (which carries real per-donation status) rather than the raw
  /// fund-flow graph, which only exposed backend node/edge labels.
  void _load() {
    final repository = context.read<DonationRepository>();
    if (widget.donationId == null) {
      _historyFuture = repository
          .history(page: 1, pageSize: 30)
          .then((snapshot) => snapshot.responses);
    } else {
      _donationFuture = repository.findInHistory(widget.donationId!);
    }
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(
      title: Text(
        widget.donationId == null ? 'أين ذهبت تبرعاتي؟' : 'مسار التبرع',
      ),
    ),
    body: widget.donationId == null
        ? _buildAggregateBody(context)
        : _buildStatusBody(context),
  );

  Widget _buildStatusBody(BuildContext context) => FutureBuilder<DonationResponse>(
    future: _donationFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          snapshot.data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError && snapshot.data == null) {
        return ErrorRetry(
          message: snapshot.error.toString(),
          onRetry: _reload,
        );
      }
      final item = snapshot.data;
      if (item == null) {
        return const EmptyView(
          message: 'لا تتوفر بيانات تتبع لهذا التبرع بعد.',
        );
      }
      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'رحلة عطائك',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
            ),
            _DonationTrackerSection(item: item),
          ],
        ),
      );
    },
  );

  Widget _buildAggregateBody(BuildContext context) => FutureBuilder<List<DonationResponse>>(
    future: _historyFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          snapshot.data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError && snapshot.data == null) {
        return ErrorRetry(
          message: snapshot.error.toString(),
          onRetry: _reload,
        );
      }
      final items = snapshot.data ?? const <DonationResponse>[];
      if (items.isEmpty) {
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              EmptyView(message: 'لا توجد تبرعات مسجّلة بعد.'),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'رحلة عطائك',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
            ),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const _TrackerDivider(),
              _DonationTrackerSection(item: items[i], showHeader: true),
            ],
          ],
        ),
      );
    },
  );
}

/// Details of the need the donor picked: what it still asks for, how far it
/// has come, and the donation type it pins the form to.
/// One labelled group on the donation form. Every section on this screen —
/// donation type, needs, type-specific fields, center, message, attachments —
/// renders through this so the page reads as one consistent form instead of
/// a stack of differently-styled widgets.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.optional = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest.withValues(alpha: 0.35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    children: optional
                        ? [
                            TextSpan(
                              text: ' (اختياري)',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NeedSummary extends StatelessWidget {
  const _NeedSummary({
    required this.need,
    required this.subtitle,
    required this.typeLabel,
  });

  final CaseNeed need;
  final String subtitle;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = need.progress;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  need.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (need.isFulfilled)
                const Icon(Icons.check_circle, size: 18, color: Colors.green),
            ],
          ),
          if (need.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              need.description,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
          if (typeLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'نوع التبرع مثبّت على «$typeLabel» ليطابق هذا الاحتياج.',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Separates two donations' status trackers in the aggregate trace view.
class _TrackerDivider extends StatelessWidget {
  const _TrackerDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.more_horiz,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

enum _TrackerStepState { done, current, pending, failed }

class _TrackerStep {
  const _TrackerStep(this.label, this.state);
  final String label;
  final _TrackerStepState state;
}

const _kFullTrackerLabels = [
  'قيد الدفع',
  'تم التسليم للمركز',
  'تم الترحيل للجمعية',
  'تمت المصادقة من الجمعية',
];

/// A donation to a trusted campaign (`campaign.isTrusted`, see
/// CAMPAIGN_ISTRUSTED_FOR_MOBILE.md) always routes through a center for
/// every donation type, and the backend only tracks these 2 donor-facing
/// stages for it instead of the usual 4 — there is no separate
/// "transferred"/"verified" stage to show.
const _kTrustedTrackerLabels = [
  'قيد الدفع',
  'تم تسليم المركز',
];

/// Maps a donation onto its donor-facing stages: 2 for a trusted campaign,
/// 4 otherwise.
///
/// A center handoff applies to money donations as much as in-kind ones (the
/// donor picks a receiving center for both, and the backend has matching
/// statuses — 6 "awaiting center confirmation", 7 "received at center" — for
/// both), so every donation type gets the same stage count (subject to the
/// trusted-campaign override above).
///
/// `DonationResponse.status` (see [ApiEnums.donationStatus]) is a coarse,
/// overlapping code, so completion is driven primarily by the dedicated
/// timestamps (`centerConfirmedAt`/`transferredToCharityAt`/`verifiedAt`),
/// which the backend sets exactly when each stage happens; `status` only
/// fills in where a timestamp might not have been recorded (e.g. a direct
/// charity receipt with no separate "transferred" event).
List<_TrackerStep> _buildTrackerSteps(DonationResponse item) {
  final labels = item.isTrusted ? _kTrustedTrackerLabels : _kFullTrackerLabels;

  if (item.status == 5) {
    return [
      _TrackerStep(labels[0], _TrackerStepState.failed),
      for (final label in labels.skip(1))
        _TrackerStep(label, _TrackerStepState.pending),
    ];
  }

  final completed = item.isTrusted
      ? _trustedStepsCompleted(item)
      : _stepsCompleted(item);

  return [
    for (var i = 0; i < labels.length; i++)
      _TrackerStep(
        labels[i],
        i < completed
            ? _TrackerStepState.done
            : i == completed
                ? (item.status == 4
                    ? _TrackerStepState.failed
                    : _TrackerStepState.current)
                : _TrackerStepState.pending,
      ),
  ];
}

int _stepsCompleted(DonationResponse item) {
  final paymentDone = item.status != 0 && item.status != 5;
  final centerDone = item.centerConfirmedAt != null ||
      const {2, 3, 7, 8}.contains(item.status);
  // `status == 7` alone is ambiguous: the backend reuses it for both
  // "received at center" and "transferred to the charity" stages,
  // distinguished only by `isPosted` (see [DonationResponse.isPosted]).
  final transferredDone = item.transferredToCharityAt != null ||
      const {2, 3, 8}.contains(item.status) ||
      (item.status == 7 && item.isPosted);
  final verifiedDone = item.verifiedAt != null ||
      const {2, 3, 8}.contains(item.status);
  return _leadingTrueCount([
    paymentDone,
    centerDone,
    transferredDone,
    verifiedDone,
  ]);
}

int _trustedStepsCompleted(DonationResponse item) {
  final paymentDone = item.status != 0 && item.status != 5;
  final centerDone = item.centerConfirmedAt != null ||
      const {2, 3, 7, 8}.contains(item.status);
  return _leadingTrueCount([paymentDone, centerDone]);
}

/// Counts the leading run of `true` flags, so a gap caused by inconsistent
/// data (e.g. a later timestamp set without an earlier one) still stops the
/// tracker at the first missing stage instead of overcounting.
int _leadingTrueCount(List<bool> flags) {
  var count = 0;
  for (final flag in flags) {
    if (!flag) break;
    count++;
  }
  return count;
}

/// One stage in the single-donation status tracker (see [_buildTrackerSteps]).
class _StatusTrackerNode extends StatelessWidget {
  const _StatusTrackerNode({required this.step, required this.isLast});
  final _TrackerStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color circleFill;
    final Color borderColor;
    final Color lineColor;
    final Widget icon;
    switch (step.state) {
      case _TrackerStepState.done:
        circleFill = AppTheme.primary;
        borderColor = AppTheme.primary;
        lineColor = AppTheme.primary;
        icon = const Icon(Icons.check, color: Colors.white, size: 22);
        break;
      case _TrackerStepState.current:
        circleFill = isDark ? scheme.surfaceContainer : Colors.white;
        borderColor = AppTheme.primary;
        lineColor = AppTheme.primary.withValues(alpha: 0.2);
        icon = const Icon(
          Icons.radio_button_checked,
          color: AppTheme.primary,
          size: 22,
        );
        break;
      case _TrackerStepState.failed:
        circleFill = Colors.red;
        borderColor = Colors.red;
        lineColor = Colors.red.withValues(alpha: 0.25);
        icon = const Icon(Icons.close, color: Colors.white, size: 22);
        break;
      case _TrackerStepState.pending:
        circleFill = isDark ? scheme.surfaceContainer : Colors.white;
        borderColor = scheme.outlineVariant;
        lineColor = scheme.outlineVariant;
        icon = Icon(
          Icons.circle,
          size: 10,
          color: scheme.onSurface.withValues(alpha: 0.25),
        );
        break;
    }

    final textColor = step.state == _TrackerStepState.pending
        ? scheme.onSurface.withValues(alpha: 0.45)
        : scheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: circleFill,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: icon,
            ),
            if (!isLast)
              Container(
                width: 3,
                height: 44,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              step.label,
              style: TextStyle(
                fontWeight: step.state == _TrackerStepState.current
                    ? FontWeight.w900
                    : FontWeight.w700,
                fontSize: 16,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One donation's full status tracker: an optional header identifying the
/// target/amount (used in the aggregate view, where several donations are
/// stacked), a rejected/failed banner when relevant, then the stage list.
class _DonationTrackerSection extends StatelessWidget {
  const _DonationTrackerSection({required this.item, this.showHeader = false});
  final DonationResponse item;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = _buildTrackerSteps(item);
    final amountLabel = item.amount != null
        ? NumberFormat('#,##0.##').format(item.amount)
        : item.typeLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Text(
            item.targetName,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            '$amountLabel • ${DateFormat('yyyy-MM-dd').format(item.donationDate.toLocal())}',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (item.status == 4 || item.status == 5)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.status == 5
                          ? 'فشلت عملية الدفع لهذا التبرع.'
                          : 'تم رفض هذا التبرع.',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (var i = 0; i < steps.length; i++)
          _StatusTrackerNode(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}
