import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/paged_state.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../logic/catalog_cubits.dart';
import 'catalog_widgets.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../../core/widgets/app_dropdown_form_field.dart';

class CatalogListScreen extends StatefulWidget {
  const CatalogListScreen({
    super.key,
    required this.kind,
    this.embedded = false,
  });

  final CatalogKind kind;
  final bool embedded;

  @override
  State<CatalogListScreen> createState() => _CatalogListScreenState();
}

enum CatalogKind { campaigns, cases }

class _CatalogListScreenState extends State<CatalogListScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  PagedCatalogCubit<CatalogItem>? _cubit;
  Timer? _debounce;
  String _status = '';
  String _typeId = '';
  String _priority = '';
  bool _onlyTrusted = false;

  CatalogQuery get _filter => CatalogQuery(
    search: _search.text,
    status: _status,
    typeId: _typeId,
    priority: _priority,
    onlyTrusted: _onlyTrusted,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final repository = context.read<CatalogRepository>();
    _cubit = PagedCatalogCubit<CatalogItem>(
      (page, size) => widget.kind == CatalogKind.campaigns
          ? repository.campaigns(page: page, pageSize: size, filter: _filter)
          : repository.cases(page: page, pageSize: size, filter: _filter),
    )..load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    _cubit?.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 320) {
      _cubit?.loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _reload);
  }

  Future<void> _reload() async {
    await _cubit?.load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SkeletonList();
    return BlocProvider.value(
      value: cubit,
      child: _CatalogBody(
        kind: widget.kind,
        embedded: widget.embedded,
        scroll: _scroll,
        search: _search,
        status: _status,
        typeId: _typeId,
        priority: _priority,
        onlyTrusted: _onlyTrusted,
        onSearchChanged: _onSearchChanged,
        onOpenFilters: _openFilters,
      ),
    );
  }

  Future<void> _openFilters() async {
    final currentItems = _cubit?.state.items ?? const <CatalogItem>[];
    // `/api/lookup/campaign-types` and `/case-categories` return a
    // completely different set of names than what campaigns/cases actually
    // carry (confirmed against live data), so the type filter is built only
    // from what the loaded items themselves report.
    final typeOptions = <String, String>{};
    for (final item in currentItems) {
      if (item.typeId.isNotEmpty && item.typeName.isNotEmpty) {
        typeOptions[item.typeId] = item.typeName;
      }
    }
    var status = _status;
    var typeId = _typeId;
    var priority = _priority;
    var trusted = _onlyTrusted;
    if (!mounted) return;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final scheme = Theme.of(context).colorScheme;

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'تصفية النتائج',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () {
                            setSheetState(() {
                              status = '';
                              typeId = '';
                              priority = '';
                              trusted = false;
                            });
                          },
                          child: const Text('مسح الكل', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppDropdownFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'الحالة',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('جميع الحالات'),
                        ),
                        if (widget.kind == CatalogKind.campaigns) ...const [
                          DropdownMenuItem(value: '0', child: Text('قيد التخطيط')),
                          DropdownMenuItem(value: '1', child: Text('نشطة')),
                          DropdownMenuItem(value: '2', child: Text('متوقفة مؤقتًا')),
                          DropdownMenuItem(value: '3', child: Text('مكتملة')),
                          DropdownMenuItem(value: '4', child: Text('ملغاة')),
                        ] else ...const [
                          DropdownMenuItem(value: '0', child: Text('مفتوحة')),
                          DropdownMenuItem(value: '1', child: Text('قيد التنفيذ')),
                          DropdownMenuItem(value: '2', child: Text('تم الحل')),
                          DropdownMenuItem(value: '3', child: Text('مغلقة')),
                        ],
                      ],
                      onChanged: (value) {
                        setSheetState(() => status = value ?? '');
                      },
                    ),
                    if (typeOptions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      AppDropdownFormField<String>(
                        initialValue: typeOptions.containsKey(typeId) ? typeId : '',
                        decoration: const InputDecoration(
                          labelText: 'النوع',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('جميع الأنواع'),
                          ),
                          ...typeOptions.entries.map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() => typeId = value ?? '');
                        },
                      ),
                    ],
                    if (widget.kind == CatalogKind.cases) ...[
                      const SizedBox(height: 10),
                      AppDropdownFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'الأولوية',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('جميع الأولويات'),
                          ),
                          DropdownMenuItem(value: '0', child: Text('منخفضة')),
                          DropdownMenuItem(value: '1', child: Text('عادية')),
                          DropdownMenuItem(value: '2', child: Text('عالية')),
                          DropdownMenuItem(value: '3', child: Text('عاجلة')),
                        ],
                        onChanged: (value) {
                          setSheetState(() => priority = value ?? '');
                        },
                      ),
                    ],
                    if (widget.kind == CatalogKind.campaigns) ...[
                      const SizedBox(height: 6),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: trusted,
                          title: const Text('الحملات الموثقة فقط', style: TextStyle(fontSize: 14)),
                          onChanged: (value) {
                            setSheetState(() => trusted = value);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('تطبيق الفلاتر', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _status = status;
        _typeId = typeId;
        _priority = priority;
        _onlyTrusted = trusted;
      });
      await _reload();
    }
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({
    required this.kind,
    required this.embedded,
    required this.scroll,
    required this.search,
    required this.status,
    required this.typeId,
    required this.priority,
    required this.onlyTrusted,
    required this.onSearchChanged,
    required this.onOpenFilters,
  });

  final CatalogKind kind;
  final bool embedded;
  final ScrollController scroll;
  final TextEditingController search;
  final String status;
  final String typeId;
  final String priority;
  final bool onlyTrusted;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final title = kind == CatalogKind.campaigns ? 'الحملات' : 'الحالات';
    final embeddedTitle = kind == CatalogKind.campaigns ? 'الحملات' : 'الحالات';
    final searchHint = kind == CatalogKind.campaigns
        ? '....ابحث عن حملة معينة'
        : '....ابحث عن حالة معينة';
    final activeFilters = [
      if (status.isNotEmpty) status,
      if (typeId.isNotEmpty) typeId,
      if (priority.isNotEmpty) priority,
      if (onlyTrusted) 'trusted',
    ].length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final body = ColoredBox(
      color: bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (embedded)
                  Text(
                    embeddedTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (embedded) const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: search,
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            hintText: searchHint,
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: isDark
                                ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                : CatalogLook.searchFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: CatalogLook.brandGreen,
                                width: 1.4,
                              ),
                            ),
                            suffixIcon: search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'مسح البحث',
                                    onPressed: () {
                                      search.clear();
                                      onSearchChanged('');
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Badge(
                      isLabelVisible: activeFilters > 0,
                      label: Text('$activeFilters'),
                      child: IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: isDark
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : CatalogLook.softButton,
                          foregroundColor: CatalogLook.brandGreen,
                        ),
                        tooltip: 'الفلاتر',
                        onPressed: onOpenFilters,
                        icon: const Icon(Icons.tune),
                      ),
                    ),
                  ],
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
                      return const SkeletonList();
                    }
                    if (state.error != null && state.items.isEmpty) {
                      return ErrorRetry(
                        message: state.error!,
                        onRetry: () => context
                            .read<PagedCatalogCubit<CatalogItem>>()
                            .load(refresh: true),
                      );
                    }
                    if (state.items.isEmpty) {
                      return const EmptyView(
                        message: 'لا توجد نتائج مطابقة للبحث أو الفلاتر.',
                      );
                    }
                    return RefreshIndicator(
                      color: CatalogLook.brandGreen,
                      onRefresh: () => context
                          .read<PagedCatalogCubit<CatalogItem>>()
                          .load(refresh: true),
                      child: ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount:
                            state.items.length + (state.isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                          final detailRoute = kind == CatalogKind.campaigns
                              ? '/campaigns/${item.id}'
                              : '/cases/${item.id}';
                          final donateRoute = '$detailRoute/donate';
                          return CatalogCard(
                            item: item,
                            onTap: () =>
                                context.push(detailRoute, extra: item),
                            onDonate: () {
                              if (item.canDonate) {
                                context.push(donateRoute, extra: item);
                              } else {
                                context.push(detailRoute, extra: item);
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
    if (embedded) return body;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBackAppBar(
        title: Text(title),
        backgroundColor: bg,
      ),
      body: body,
    );
  }
}
