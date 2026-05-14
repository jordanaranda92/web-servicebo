/// Base class for all technical exceptions in the data layer.
///
/// Exceptions should only be thrown in datasources and caught
/// in repositories, where they are converted to [Failure] types.
abstract class AppException implements Exception {
  final String? message;

  const AppException([this.message]);

  @override
  String toString() => message ?? runtimeType.toString();
}

/// Thrown when a server request fails.
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({String? message, this.statusCode}) : super(message);
}

/// Thrown when local cache operations fail.
class CacheException extends AppException {
  const CacheException([super.message]);
}

/// Thrown when there is no network connectivity.
class NetworkException extends AppException {
  const NetworkException([super.message]);
}

/// Thrown when a requested resource is not found.
class NotFoundException extends AppException {
  const NotFoundException([super.message]);
}

/// Thrown when data parsing/mapping fails.
class ParsingException extends AppException {
  const ParsingException([super.message]);
}

/// Thrown when file system operations fail (read, write, copy, etc.).
///
/// Named `FileAccessException` to avoid collision with `dart:io.FileSystemException`.
class FileAccessException extends AppException {
  const FileAccessException([super.message]);
}
