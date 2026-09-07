import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/async_state.dart';
import '../../../core/state/paged_state.dart';
import '../data/catalog_models.dart';

typedef PageLoader<T> = Future<PageResult<T>> Function(int page, int pageSize);

class PagedCatalogCubit<T> extends Cubit<PagedState<T>> {
  PagedCatalogCubit(this._loader) : super(const PagedState());
  final PageLoader<T> _loader;
  static const pageSize = 10;

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading || state.isLoadingMore) return;
    if (!refresh && state.items.isNotEmpty) return;
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        items: refresh ? const [] : state.items,
        page: refresh ? 0 : state.page,
      ),
    );
    try {
      final result = await _loader(1, pageSize);
      emit(PagedState(items: result.items, page: 1, hasMore: result.hasMore));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: error.toString()));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final nextPage = state.page + 1;
      final result = await _loader(nextPage, pageSize);
      final merged = <T>{...state.items, ...result.items}.toList();
      emit(
        state.copyWith(
          items: merged,
          page: nextPage,
          hasMore: result.hasMore && result.items.isNotEmpty,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      emit(state.copyWith(isLoadingMore: false, error: error.toString()));
    }
  }
}

class DetailCubit<T> extends Cubit<AsyncState<T>> {
  DetailCubit(this._loader, {Future<T> Function()? refreshLoader})
    : _refreshLoader = refreshLoader,
      super(const AsyncState());
  final Future<T> Function() _loader;

  /// Used for a manual pull-to-refresh. Defaults to [_loader] itself, so
  /// screens that never pass one keep their existing behaviour unchanged.
  final Future<T> Function()? _refreshLoader;

  Future<void> load({bool forceRefresh = false}) async {
    emit(const AsyncState(status: AsyncStatus.loading));
    try {
      final loader = forceRefresh ? (_refreshLoader ?? _loader) : _loader;
      emit(AsyncState(status: AsyncStatus.success, data: await loader()));
    } catch (error) {
      emit(AsyncState(status: AsyncStatus.failure, message: error.toString()));
    }
  }
}
