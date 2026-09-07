import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_enums.dart';
import '../../../core/network/url_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../media/ui/media_gallery_screen.dart';
import '../../media/ui/media_manager_screen.dart';
import '../data/complaint_models.dart';
import '../data/complaint_repository.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../../core/widgets/app_dropdown_form_field.dart';

class CreateComplaintScreen extends StatefulWidget {
  const CreateComplaintScreen({
    super.key,
    this.charityId = '',
    this.charityName = '',
  });

  /// Empty when the screen is opened outside a charity's context, in which
  /// case the complaint is filed against the platform.
  final String charityId;
  final String charityName;

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  int _type = 0;
  int _severity = 0;
  late int _targetType;
  bool _loading = false;
  final _attachments = <String>[];

  /// A complaint reached from a charity page starts aimed at that charity;
  /// one reached from the profile has no charity to aim at, so it defaults
  /// to the platform.
  bool get _hasCharity => widget.charityId.trim().isNotEmpty;

  bool get _isAgainstCharity =>
      _targetType == ComplaintTargetType.charity;

  @override
  void initState() {
    super.initState();
    _targetType = _hasCharity
        ? ComplaintTargetType.charity
        : ComplaintTargetType.admin;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null) return;
    const maxBytes = 50 * 1024 * 1024;
    final totalBytes = result.files.fold<int>(
      0,
      (sum, item) => sum + item.size,
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
        ..addAll(result.files.map((item) => item.path).whereType<String>());
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _loading = true);
    try {
      final complaint = await context.read<ComplaintRepository>().create(
        ComplaintRequest(
          charityId: _isAgainstCharity ? widget.charityId : '',
          targetType: _targetType,
          complaintType: _type,
          description: _description.text,
          severity: _severity,
          attachments: _attachments,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال الشكوى')));
        context.go('/complaints/${complaint.id}', extra: complaint);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Lets the donor aim the complaint. Opened from a charity page both
  /// targets are offered; opened from the profile there is no charity to
  /// name, so the platform is stated rather than chosen.
  List<Widget> _targetSection() {
    if (!_hasCharity) {
      return [
        Card(
          child: ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('الجهة المشتكى عليها'),
            subtitle: Text(
              ComplaintTargetType.labels[ComplaintTargetType.admin]!,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'لتقديم شكوى ضد جمعية معيّنة، افتح صفحة الجمعية ثم اختر «تقديم شكوى».',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ];
    }
    final charityLabel = widget.charityName.isEmpty
        ? 'الجمعية'
        : widget.charityName;
    return [
      const Text(
        'الجهة المشتكى عليها',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      SegmentedButton<int>(
        segments: [
          ButtonSegment(
            value: ComplaintTargetType.charity,
            label: Text(charityLabel, overflow: TextOverflow.ellipsis),
            icon: const Icon(Icons.apartment_outlined),
          ),
          ButtonSegment(
            value: ComplaintTargetType.admin,
            label: Text(
              ComplaintTargetType.labels[ComplaintTargetType.admin]!,
            ),
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
        selected: {_targetType},
        onSelectionChanged: _loading
            ? null
            : (value) => setState(() => _targetType = value.first),
      ),
      const SizedBox(height: 14),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('تقديم شكوى')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ..._targetSection(),
          AppDropdownFormField<int>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'نوع الشكوى'),
            items: ApiEnums.complaintType.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) => setState(() => _type = value ?? 0),
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<int>(
            initialValue: _severity,
            decoration: const InputDecoration(labelText: 'درجة الخطورة'),
            items: ApiEnums.complaintSeverity.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) => setState(() => _severity = value ?? 0),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _description,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'وصف الشكوى',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().length < 10
                ? 'اكتب وصفًا واضحًا لا يقل عن 10 محارف'
                : null,
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('صور أو مستندات إثبات'),
              subtitle: Text(
                _attachments.isEmpty
                    ? 'اختياري'
                    : '${_attachments.length} مرفق',
              ),
              trailing: TextButton(
                onPressed: _loading ? null : _pick,
                child: const Text('اختيار'),
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(_loading ? 'جارٍ الإرسال...' : 'إرسال الشكوى'),
          ),
        ],
      ),
    ),
  );
}

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});
  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  final _items = <Complaint>[];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refresh();
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

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _hasMore = true;
    });
    try {
      final result = await context.read<ComplaintRepository>().mine(
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = 1;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await context.read<ComplaintRepository>().mine(
        page: next,
        pageSize: _pageSize,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('شكاوي')),
    body: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _items.isEmpty
        ? ErrorRetry(message: _error!, onRetry: _refresh)
        : _items.isEmpty
        ? const EmptyView(message: 'لا توجد شكاوى مقدمة.')
        : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final item = _items[index];
                return Card(
                  child: ListTile(
                    title: Text(
                      item.complaintNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${item.targetLabel} • ${item.typeLabel} • ${item.severityLabel}\n'
                      '${DateFormat('yyyy-MM-dd').format(item.createdAt.toLocal())}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(
                        item.statusLabel,
                        style: TextStyle(
                          color: ApiEnums.statusColor(
                            item.status,
                            family: 'complaint',
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: ApiEnums.statusColor(
                        item.status,
                        family: 'complaint',
                      ).withValues(alpha: 0.12),
                      side: BorderSide(
                        color: ApiEnums.statusColor(
                          item.status,
                          family: 'complaint',
                        ),
                      ),
                    ),
                    onTap: () =>
                        context.push('/complaints/${item.id}', extra: item),
                  ),
                );
              },
            ),
          ),
  );
}

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key, required this.id, this.initial});
  final String id;
  final Complaint? initial;
  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late Future<Complaint> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.initial == null
        ? context.read<ComplaintRepository>().detail(widget.id)
        : Future.value(widget.initial!);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('تفاصيل الشكوى')),
    body: FutureBuilder<Complaint>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ErrorRetry(
            message: snapshot.error?.toString() ?? 'تعذر تحميل الشكوى',
            onRetry: () => setState(
              () => _future = context.read<ComplaintRepository>().detail(
                widget.id,
              ),
            ),
          );
        }
        final item = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              item.complaintNumber,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    item.isAgainstCharity
                        ? Icons.apartment_outlined
                        : Icons.shield_outlined,
                    size: 18,
                  ),
                  label: Text(item.targetLabel),
                ),
                Chip(label: Text(item.typeLabel)),
                Chip(label: Text(item.severityLabel)),
                Chip(
                  label: Text(
                    item.statusLabel,
                    style: TextStyle(
                      color: ApiEnums.statusColor(
                        item.status,
                        family: 'complaint',
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: ApiEnums.statusColor(
                    item.status,
                    family: 'complaint',
                  ).withValues(alpha: 0.12),
                  side: BorderSide(
                    color: ApiEnums.statusColor(
                      item.status,
                      family: 'complaint',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(item.description, style: const TextStyle(height: 1.7)),
            if (item.resolutionNotes.isNotEmpty) ...[
              const SizedBox(height: 18),
              Card(
                color: AppTheme.successSurfaceOf(context),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'ملاحظات الحل:\n${item.resolutionNotes}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
            if (item.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'المرفقات',
                style: TextStyle(fontWeight: FontWeight.w800),
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
                        title: 'مرفقات الشكوى',
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
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => context.push(
                  '/media/manage',
                  extra: MediaManagerArgs(
                    ownerType: 4,
                    ownerId: item.id,
                    title: 'مرفقات الشكوى',
                  ),
                ),
                icon: const Icon(Icons.attach_file),
                label: const Text('إدارة مرفقات الشكوى'),
              ),
            ],
          ],
        );
      },
    ),
  );
}
