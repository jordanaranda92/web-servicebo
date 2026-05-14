import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'feedback_state.dart';

class FeedbackCubit extends Cubit<FeedbackState> {
  Timer? _timer;

  FeedbackCubit() : super(const FeedbackState());

  void show(String message, {bool isSuccess = true}) {
    _timer?.cancel();
    emit(FeedbackState(message: message, isSuccess: isSuccess));
    _timer = Timer(const Duration(seconds: 3), clear);
  }

  void clear() {
    _timer?.cancel();
    emit(const FeedbackState());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
