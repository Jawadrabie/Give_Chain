import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/async_state.dart';
import '../data/home_overview.dart';
import '../data/home_repository.dart';

class HomeOverviewCubit extends Cubit<AsyncState<HomeOverview>> {
  HomeOverviewCubit(this._repository) : super(const AsyncState());
  final HomeRepository _repository;

  Future<void> load({bool forceRefresh = false}) async {
    if (state.status == AsyncStatus.loading) return;

    final hasData = state.data != null;
    // تحديث صامت عند وجود بيانات مسبقاً أو عند السحب للتحديث مع بيانات ظاهرة.
    if (!hasData) {
      emit(AsyncState(status: AsyncStatus.loading, data: state.data));
    }

    try {
      emit(
        AsyncState(
          status: AsyncStatus.success,
          data: await _repository.load(forceRefresh: forceRefresh),
        ),
      );
    } catch (error) {
      emit(
        AsyncState(
          status: AsyncStatus.failure,
          data: state.data,
          message: error.toString(),
        ),
      );
    }
  }
}
