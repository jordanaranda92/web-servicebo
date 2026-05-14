import 'package:equatable/equatable.dart';

class FeedbackState extends Equatable {
  final String? message;
  final bool isSuccess;

  const FeedbackState({this.message, this.isSuccess = true});

  bool get hasMessage => message != null;

  @override
  List<Object?> get props => [message, isSuccess];
}
