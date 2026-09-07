import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/async_state.dart';
import '../data/donation_models.dart';
import '../data/donation_repository.dart';

class DonationCubit extends Cubit<AsyncState<DonationResponse>> {
  DonationCubit(this._repository) : super(const AsyncState());
  final DonationRepository _repository;

  Future<void> submit(
    DonationRequest request, {
    required String targetTitle,
  }) async {
    if (state.status == AsyncStatus.loading) return;
    emit(const AsyncState(status: AsyncStatus.loading));
    try {
      final response = await _repository.createWithOfflineFallback(
        request,
        targetTitle: targetTitle,
      );
      emit(AsyncState(status: AsyncStatus.success, data: response));
    } catch (error) {
      emit(AsyncState(status: AsyncStatus.failure, message: error.toString()));
    }
  }

  Future<void> submitGeneral(
    DonationRequest request, {
    required String targetTitle,
  }) async {
    if (state.status == AsyncStatus.loading) return;
    emit(const AsyncState(status: AsyncStatus.loading));
    try {
      final response = await _repository.createWithOfflineFallback(
        request,
        targetTitle: targetTitle,
        useGeneral: true,
      );
      emit(AsyncState(status: AsyncStatus.success, data: response));
    } catch (error) {
      emit(AsyncState(status: AsyncStatus.failure, message: error.toString()));
    }
  }
}

class DonationHistoryCubit extends Cubit<AsyncState<DonationHistorySnapshot>> {
  DonationHistoryCubit(this._repository) : super(const AsyncState());
  final DonationRepository _repository;
  bool _loadingMore = false;
  int? _statusFilter;
  bool? _centerFilter;

  int? get statusFilter => _statusFilter;
  bool? get centerFilter => _centerFilter;

  Future<void> load({int? status, bool? throughCenter}) async {
    _statusFilter = status;
    _centerFilter = throughCenter;
    if (state.status == AsyncStatus.loading) return;
    emit(AsyncState(status: AsyncStatus.loading, data: state.data));
    unawaited(_repository.trySyncQueuedDonations());
    try {
      emit(
        AsyncState(
          status: AsyncStatus.success,
          data: await _repository.history(
            page: 1,
            pageSize: 20,
            status: _statusFilter,
            throughCenter: _centerFilter,
          ),
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

  Future<void> loadMore() async {
    final current = state.data;
    if (_loadingMore ||
        current == null ||
        !current.hasMore ||
        !current.isServerBacked) {
      return;
    }
    _loadingMore = true;
    try {
      final next = await _repository.history(
        page: current.page + 1,
        pageSize: 20,
        status: _statusFilter,
        throughCenter: _centerFilter,
      );
      final ids = current.responses.map((item) => item.id).toSet();
      final mergedResponses = <DonationResponse>[
        ...current.responses,
        ...next.responses.where((item) => ids.add(item.id)),
      ];
      emit(
        AsyncState(
          status: AsyncStatus.success,
          data: DonationHistorySnapshot(
            records: next.records,
            responses: mergedResponses,
            warning: next.warning,
            isServerBacked: next.isServerBacked,
            hasMore: next.hasMore,
            page: next.page,
          ),
        ),
      );
    } catch (error) {
      emit(
        AsyncState(
          status: AsyncStatus.failure,
          data: current,
          message: error.toString(),
        ),
      );
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> clear() async {
    await _repository.clearLocalHistory();
    await load();
  }

  Future<void> refreshRecord(DonationRecord record) async {
    await load();
  }
}
