import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/core/state/paged_state.dart';
import 'package:give_chain_app/features/catalog/data/catalog_models.dart';
import 'package:give_chain_app/features/catalog/logic/catalog_cubits.dart';

void main() {
  final firstPage = List.generate(
    10,
    (index) => CatalogItem(id: '$index', title: 'عنصر $index'),
  );
  final secondPage = List.generate(
    2,
    (index) => CatalogItem(id: '${index + 10}', title: 'عنصر ${index + 10}'),
  );

  blocTest<PagedCatalogCubit<CatalogItem>, PagedState<CatalogItem>>(
    'loads first page then appends the next page',
    build: () => PagedCatalogCubit<CatalogItem>((page, pageSize) async {
      if (page == 1) {
        return PageResult(items: firstPage, hasMore: true);
      }
      return PageResult(items: secondPage, hasMore: false);
    }),
    act: (cubit) async {
      await cubit.load();
      await cubit.loadMore();
    },
    verify: (cubit) {
      expect(cubit.state.items, hasLength(12));
      expect(cubit.state.page, 2);
      expect(cubit.state.hasMore, isFalse);
    },
  );

  blocTest<PagedCatalogCubit<CatalogItem>, PagedState<CatalogItem>>(
    'exposes a loader error without remaining in loading state',
    build: () => PagedCatalogCubit<CatalogItem>(
      (_, _) async => throw Exception('network error'),
    ),
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.error, contains('network error'));
    },
  );
}
