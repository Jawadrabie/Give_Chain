import 'package:equatable/equatable.dart';

enum AsyncStatus { initial, loading, success, failure }

class AsyncState<T> extends Equatable {
  const AsyncState({
    this.status = AsyncStatus.initial,
    this.data,
    this.message,
  });

  final AsyncStatus status;
  final T? data;
  final String? message;

  AsyncState<T> copyWith({
    AsyncStatus? status,
    T? data,
    String? message,
    bool clearMessage = false,
  }) {
    return AsyncState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, data, message];
}
