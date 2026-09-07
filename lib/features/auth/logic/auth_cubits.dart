import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/async_state.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

class SignUpCubit extends Cubit<AsyncState<AuthResponse>> {
  SignUpCubit(this._repository) : super(const AsyncState());
  final AuthRepository _repository;

  Future<void> signUp(SignUpRequest request) async {
    if (state.status == AsyncStatus.loading) return;
    emit(const AsyncState(status: AsyncStatus.loading));
    try {
      final response = await _repository.signUp(request);
      emit(AsyncState(status: AsyncStatus.success, data: response));
    } catch (error) {
      emit(AsyncState(status: AsyncStatus.failure, message: error.toString()));
    }
  }
}

class ForgotPasswordCubit
    extends Cubit<AsyncState<PasswordResetRequestResult>> {
  ForgotPasswordCubit(this._repository) : super(const AsyncState());
  final AuthRepository _repository;

  Future<void> request(String email) async {
    if (state.status == AsyncStatus.loading) return;
    emit(const AsyncState(status: AsyncStatus.loading));
    try {
      emit(
        AsyncState(
          status: AsyncStatus.success,
          data: await _repository.requestPasswordReset(email),
        ),
      );
    } catch (error) {
      emit(AsyncState(status: AsyncStatus.failure, message: error.toString()));
    }
  }
}

class ResetPasswordCubit extends Cubit<AsyncState<PasswordResetRequestResult>> {
  ResetPasswordCubit(this._repository) : super(const AsyncState());
  final AuthRepository _repository;

  Future<void> reset(ResetPasswordRequest request) async {
    if (state.status == AsyncStatus.loading) return;
    emit(const AsyncState(status: AsyncStatus.loading));
    try {
      emit(
        AsyncState(
          status: AsyncStatus.success,
          data: await _repository.resetPassword(request),
        ),
      );
    } catch (error) {
      emit(AsyncState(status: AsyncStatus.failure, message: error.toString()));
    }
  }
}
