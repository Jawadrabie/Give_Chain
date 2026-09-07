import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/paged_state.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/logic/catalog_cubits.dart';
import '../../catalog/ui/catalog_widgets.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class CharitiesScreen extends StatefulWidget {
  const CharitiesScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<CharitiesScreen> createState() => _CharitiesScreenState();
}

class _CharitiesScreenState extends State<CharitiesScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _selectedCategory = '';
  PagedCatalogCubit<Charity>? _cubit;
  Timer? _debounce;
  
  final _categories = const [
    'الصحة',
    'الغذاء',
    'التعليم',
    'تنمية مجتمعية',
    'إسكان',
    'الأسرة',
    'أيتام',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final repository = context.read<CatalogRepository>();
    _cubit = PagedCatalogCubit<Charity>(
      (page, size) => repository.charities(
        page: page,
        pageSize: size,
        search: _search.text,
        category: _selectedCategory,
        onlyTrusted: false,
      ),
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
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      _cubit?.loadMore();
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _cubit?.load(refresh: true),
    );
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? '' : category;
    });
    _cubit?.load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SkeletonList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final body = ColoredBox(
      color: bg,
      child: BlocProvider.value(
        value: cubit,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.embedded)
                    const Text(
                      'الجمعيات',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (widget.embedded) const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _search,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: '....ابحث عن جمعية معينة',
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
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح البحث',
                                onPressed: () {
                                  _search.clear();
                                  _onSearch('');
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) => _onCategoryChanged(cat),
                          selectedColor: CatalogLook.brandGreen.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? CatalogLook.brandGreen
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                          side: isSelected 
                              ? const BorderSide(color: CatalogLook.brandGreen)
                              : BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  BlocBuilder<PagedCatalogCubit<Charity>, PagedState<Charity>>(
                    builder: (context, state) {
                      if (state.isLoading && state.items.isEmpty) {
                        return const SkeletonList();
                      }
                      if (state.error != null && state.items.isEmpty) {
                        return ErrorRetry(
                          message: state.error!,
                          onRetry: () => context
                              .read<PagedCatalogCubit<Charity>>()
                              .load(refresh: true),
                        );
                      }
                      if (state.items.isEmpty) {
                        return const EmptyView(
                          message: 'لا توجد جمعيات مطابقة للبحث.',
                        );
                      }
                      return RefreshIndicator(
                        color: CatalogLook.brandGreen,
                        onRefresh: () => context
                            .read<PagedCatalogCubit<Charity>>()
                            .load(refresh: true),
                        child: ListView.separated(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          itemCount:
                              state.items.length +
                              (state.isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            if (index == state.items.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final charity = state.items[index];
                            return CharityCard(
                              charity: charity,
                              onTap: () => context.push(
                                '/charities/${charity.id}',
                                extra: charity,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
    return widget.embedded
        ? body
        : Scaffold(
            backgroundColor: bg,
            appBar: AppBackAppBar(
              title: const Text('الجمعيات'),
              backgroundColor: bg,
            ),
            body: body,
          );
  }
}
