import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/async_state.dart';
import '../data/profile_repository.dart';

class UpdateProfileCubit extends Cubit<AsyncState<ProfileOperationResult>> {
  UpdateProfileCubit(this._repository) : super(const AsyncState());
  final ProfileRepository _repository;
  Future<void> submit(UpdateProfileRequest request) async {
    if (state.status == AsyncStatus.loading) return;
    emit(const AsyncState(status: AsyncStatus.loading));
    try {
      emit(
        AsyncState(
          status: AsyncStatus.success,
          data: await _repository.updateProfile(request),
        ),
      );
    } catch (error) {
      emit(AsyncState(status: AsyncStatus.failure, message: error.toString()));
    }
  }
}

class ChangePasswordCubit extends Cubit<AsyncState<ProfileOperationResult>> {
  ChangePasswordCubit(this._repository) : super(const AsyncState());
  final ProfileRepository _repository;
  Future<void> submit(ChangePasswordRequest request) async {
    if (state.status == AsyncStatus.loading) return;
    emit(const AsyncState(status: AsyncStatus.loading));
    try {
      emit(
        AsyncState(
          status: AsyncStatus.success,
          data: await _repository.changePassword(request),
        ),
      );
    } catch (error) {
      emit(AsyncState(status: AsyncStatus.failure, message: error.toString()));
    }
  }
}
