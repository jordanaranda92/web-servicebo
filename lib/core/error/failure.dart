import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  @override
  List<Object> get props => [];
}

// General failures
class NetworkFailure extends Failure {}

class ServerFailure extends Failure {}

class CacheFailure extends Failure {}

class EntityMappingFailure extends Failure {}

class InternalFailure extends Failure {}

class FileSystemFailure extends Failure {}

class ConfigNotFoundFailure extends Failure {}

class PrerequisiteFailure extends Failure {
  final bool facturaDirectaMissing;

  PrerequisiteFailure({this.facturaDirectaMissing = false});

  @override
  List<Object> get props => [facturaDirectaMissing];
}

// Auth failures
class AuthInvalidCredentialsFailure extends Failure {}

class AuthUserDisabledFailure extends Failure {}

class AuthTooManyRequestsFailure extends Failure {}

class AuthUnknownFailure extends Failure {}
