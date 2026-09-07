import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/ui/catalog_widgets.dart';

class QuickDonateScreen extends StatefulWidget {
  const QuickDonateScreen({super.key});

  @override
  State<QuickDonateScreen> createState() => _QuickDonateScreenState();
}

class _QuickDonateScreenState extends State<QuickDonateScreen> {
  String _targetType = 'campaign';
  late Future<PageResult<CatalogItem>> _itemsFuture;

  final _searchController = TextEditingController();
  CatalogQuery _currentFilter = const CatalogQuery();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadItems() {
    final repo = context.read<CatalogRepository>();
    final query = _currentFilter.copyWith(search: _searchController.text);
    setState(() {
      _itemsFuture = _targetType == 'campaign'
          ? repo.campaigns(page: 1, pageSize: 50, filter: query)
          : repo.cases(page: 1, pageSize: 50, filter: query);
    });
  }

  void _openFilters() async {
    final isCase = _targetType == 'case';
    // `/api/lookup/campaign-types` and `/case-categories` return a
    // completely different set of names than what campaigns/cases actually
    // carry in production (confirmed against live data), so a type filter
    // built from them would offer options that match nothing. The types
    // actually in use are read off the items already on screen instead.
    final loaded = await _itemsFuture;
    final typeOptions = <String, String>{};
    for (final item in loaded.items) {
      if (item.typeId.isNotEmpty && item.typeName.isNotEmpty) {
        typeOptions[item.typeId] = item.typeName;
      }
    }
    if (!mounted) return;
    final filter = await showModalBottomSheet<CatalogQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        initialFilter: _currentFilter,
        isCase: isCase,
        typeOptions: typeOptions,
      ),
    );
    if (filter != null) {
      _currentFilter = filter;
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SegmentedButton<String>(
            // "campaign" and "case" are simply which list is shown — the API
            // has no notion of an "urgent campaign", so the label must not
            // claim one. Only a case carries a real priority field.
            segments: const [
              ButtonSegment(
                value: 'campaign',
                label: Text('الحملات'),
                icon: Icon(Icons.campaign_outlined),
              ),
              ButtonSegment(
                value: 'case',
                label: Text('حالات إنسانية'),
                icon: Icon(Icons.volunteer_activism_outlined),
              ),
            ],
            selected: {_targetType},
            onSelectionChanged: (value) {
              // The two lists filter on different properties (campaign type
              // vs. case priority), so a filter picked for one would silently
              // misapply to the other if it survived the switch.
              _targetType = value.first;
              _currentFilter = const CatalogQuery();
              _searchController.clear();
              _loadItems();
            },
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'ابحث هنا...',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _openFilters,
                icon: Icon(
                  _currentFilter.isEmpty
                      ? Icons.filter_list
                      : Icons.filter_list_off,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<PageResult<CatalogItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SkeletonList();
              }
              if (snapshot.hasError) {
                return ErrorRetry(
                  message: snapshot.error?.toString() ?? 'تعذر تحميل البيانات',
                  onRetry: _loadItems,
                );
              }
              final items = snapshot.data?.items ?? const [];
              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () {
                    _loadItems();
                    return _itemsFuture;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyView(message: 'لا توجد فرص متاحة حالياً'),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () {
                  _loadItems();
                  return _itemsFuture;
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return CatalogCard(
                      item: item,
                      width: double.infinity,
                      donateLabel: 'تبرع سريع',
                      onTap: () => context.push(
                        _targetType == 'campaign'
                            ? '/campaigns/${item.id}'
                            : '/cases/${item.id}',
                        extra: item,
                      ),
                      onDonate: () =>
                          _showQuickDonateBottomSheet(context, item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showQuickDonateBottomSheet(BuildContext context, CatalogItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _QuickDonateBottomSheet(item: item, targetType: _targetType),
    );
  }
}

class _QuickDonateBottomSheet extends StatefulWidget {
  const _QuickDonateBottomSheet({required this.item, required this.targetType});

  final CatalogItem item;
  final String targetType;

  @override
  State<_QuickDonateBottomSheet> createState() =>
      _QuickDonateBottomSheetState();
}

class _QuickDonateBottomSheetState extends State<_QuickDonateBottomSheet> {
  int? _selectedAmountIndex;
  final _amountController = TextEditingController();
  static const _presetAmounts = [10, 50, 100, 500];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

  void _submit() {
    if (!TokenStorage.hasSession) {
      context.pop();
      context.push('/login');
      return;
    }
    // Go to full donate screen with prefilled target, or we can send directly
    // Since the system has a full donation flow, we redirect to it for now
    // A better approach would be to have a specialized quick_donation API endpoint
    // but we use the existing route.
    context.pop();
    final route = widget.targetType == 'campaign'
        ? '/campaigns/${widget.item.id}/donate'
        : '/cases/${widget.item.id}/donate';
    context.push(route, extra: widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.softOf(context),
                    child: const Icon(Icons.favorite, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تبرع لـ:',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'اختر المبلغ',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetAmounts.asMap().entries.map((entry) {
                  final selected = _selectedAmountIndex == entry.key;
                  return ChoiceChip(
                    label: Text('${entry.value}'),
                    selected: selected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppTheme.primaryForeground
                          : scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedAmountIndex = entry.key;
                        _amountController.text = '${entry.value}';
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'أو أدخل مبلغاً مخصصاً',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() => _selectedAmountIndex = null),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.primaryForeground,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'المتابعة للدفع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filters real to what the API actually exposes:
/// - a campaign has `campaignType` and `status`, no priority;
/// - a case has `category` (same shape as a campaign type) and `priority`,
///   no status filter offered here since almost every case in production is
///   simply "open" (see BACKEND note in CatalogItem.displayStatus).
class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({
    required this.initialFilter,
    required this.isCase,
    this.typeOptions = const {},
  });

  final CatalogQuery initialFilter;
  final bool isCase;

  /// Type id → display name, gathered from the items already loaded.
  final Map<String, String> typeOptions;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late bool _onlyTrusted;
  late String _priority;
  late String _typeId;

  @override
  void initState() {
    super.initState();
    _onlyTrusted = widget.initialFilter.onlyTrusted;
    _priority = widget.initialFilter.priority;
    _typeId = widget.initialFilter.typeId;
  }

  bool get _hasActiveFilter =>
      _priority.isNotEmpty || _onlyTrusted || _typeId.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isCase ? 'تصفية الحالات' : 'تصفية الحملات',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  if (_hasActiveFilter)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => setState(() {
                        _priority = '';
                        _onlyTrusted = false;
                        _typeId = '';
                      }),
                      child: const Text(
                        'إعادة ضبط',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'جهات موثقة فقط',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: _onlyTrusted,
                      onChanged: (v) => setState(() => _onlyTrusted = v),
                    ),
                  ),
                ],
              ),
              if (widget.isCase) ...[
                const Divider(height: 12),
                const Text(
                  'الأولوية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _choiceChip('', 'الكل', scheme),
                    _choiceChip('3', 'عاجلة', scheme),
                    _choiceChip('2', 'عالية', scheme),
                    _choiceChip('1', 'عادية', scheme),
                    _choiceChip('0', 'منخفضة', scheme),
                  ],
                ),
              ],
              if (widget.typeOptions.isNotEmpty) ...[
                const Divider(height: 12),
                Text(
                  widget.isCase ? 'التصنيف' : 'نوع الحملة',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _typeChip('', 'الكل', scheme),
                    for (final entry in widget.typeOptions.entries)
                      _typeChip(entry.key, entry.value, scheme),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    CatalogQuery(
                      onlyTrusted: _onlyTrusted,
                      priority: _priority,
                      typeId: _typeId,
                      search: widget.initialFilter.search,
                    ),
                  );
                },
                child: const Text(
                  'تطبيق',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceChip(String value, String label, ColorScheme scheme) {
    final selected = _priority == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppTheme.primary,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      labelStyle: TextStyle(
        color: selected ? Colors.white : scheme.onSurface,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: selected
            ? AppTheme.primary
            : scheme.outline.withValues(alpha: 0.2),
      ),
      onSelected: (_) => setState(() => _priority = value),
    );
  }

  Widget _typeChip(String value, String label, ColorScheme scheme) {
    final selected = _typeId == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppTheme.primary,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      labelStyle: TextStyle(
        color: selected ? Colors.white : scheme.onSurface,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: selected
            ? AppTheme.primary
            : scheme.outline.withValues(alpha: 0.2),
      ),
      onSelected: (_) => setState(() => _typeId = value),
    );
  }
}
