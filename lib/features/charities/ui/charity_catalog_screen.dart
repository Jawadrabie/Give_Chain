import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/paged_state.dart';
import '../../../core/widgets/async_view.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/logic/catalog_cubits.dart';
import '../../catalog/ui/catalog_widgets.dart';
import '../../../core/widgets/app_back_app_bar.dart';

/// Full-page version of a charity's campaigns/cases.
/// The embedded charity tabs use /charities/{id}/campaigns|cases, while this
/// screen intentionally uses the additional documented
/// /campaigns/by-charity/{id} and /cases/by-charity/{id} endpoints.
class CharityCatalogScreen extends StatefulWidget {
  const CharityCatalogScreen({
    super.key,
    required this.charityId,
    required this.campaigns,
    this.charityName = '',
  });

  final String charityId;
  final bool campaigns;
  final String charityName;

  @override
  State<CharityCatalogScreen> createState() => _CharityCatalogScreenState();
}

class _CharityCatalogScreenState extends State<CharityCatalogScreen> {
  final _search = TextEditingController();
  PagedCatalogCubit<CatalogItem>? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final repository = context.read<CatalogRepository>();
    _cubit = PagedCatalogCubit<CatalogItem>(
      widget.campaigns
          ? (page, size) => repository.campaignsByCharity(
              widget.charityId,
              page: page,
              pageSize: size,
              filter: CatalogQuery(search: _search.text),
            )
          : (page, size) => repository.casesByCharity(
              widget.charityId,
              page: page,
              pageSize: size,
              filter: CatalogQuery(search: _search.text),
            ),
    )..load();
  }

  @override
  void dispose() {
    _search.dispose();
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    return Scaffold(
      appBar: AppBackAppBar(
        title: Text(
          widget.charityName.isEmpty
              ? (widget.campaigns ? 'حملات الجمعية' : 'حالات الجمعية')
              : '${widget.campaigns ? 'حملات' : 'حالات'} ${widget.charityName}',
        ),
      ),
      body: cubit == null
          ? const Center(child: CircularProgressIndicator())
          : BlocProvider.value(
              value: cubit,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SearchBar(
                      controller: _search,
                      hintText: widget.campaigns
                          ? 'ابحث ضمن حملات الجمعية'
                          : 'ابحث ضمن حالات الجمعية',
                      leading: const Icon(Icons.search),
                      onChanged: (_) => cubit.load(refresh: true),
                      trailing: [
                        if (_search.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _search.clear();
                              cubit.load(refresh: true);
                            },
                            icon: const Icon(Icons.close),
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
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (state.error != null && state.items.isEmpty) {
                              return ErrorRetry(
                                message: state.error!,
                                onRetry: () => cubit.load(refresh: true),
                              );
                            }
                            if (state.items.isEmpty) {
                              return EmptyView(
                                message: widget.campaigns
                                    ? 'لا توجد حملات فعالة لهذه الجمعية.'
                                    : 'لا توجد حالات مفتوحة لهذه الجمعية.',
                              );
                            }
                            return RefreshIndicator(
                              onRefresh: () => cubit.load(refresh: true),
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification.metrics.extentAfter < 320) {
                                    cubit.loadMore();
                                  }
                                  return false;
                                },
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    24,
                                  ),
                                  itemCount:
                                      state.items.length +
                                      (state.isLoadingMore ? 1 : 0),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    if (index == state.items.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    final item = state.items[index];
                                    return CatalogCard(
                                      item: item,
                                      onTap: () => context.push(
                                        widget.campaigns
                                            ? '/campaigns/${item.id}'
                                            : '/cases/${item.id}',
                                        extra: item,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}
