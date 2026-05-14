import 'package:fpdart/fpdart.dart';
import 'package:equatable/equatable.dart';

import '../error/failure.dart';

// ignore: avoid_types_as_parameter_names
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}
