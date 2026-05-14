import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/local/settings_local_data_source.dart';
import '../datasources/remote/settings_remote_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._localDataSource, this._remoteDataSource);

  final SettingsLocalDataSource _localDataSource;
  final SettingsRemoteDataSource _remoteDataSource;

  // Page size

  @override
  int getPageSize() => _localDataSource.getPageSize();

  @override
  Future<Either<Failure, Unit>> savePageSize(int size) async {
    try {
      await _localDataSource.savePageSize(size);
      return const Right(unit);
    } on CacheException {
      return Left(CacheFailure());
    }
  }

  // Invoice series

  @override
  Future<Either<Failure, String?>> getInvoiceSeries() async {
    try {
      final series = await _remoteDataSource.getInvoiceSeries();
      return Right(series);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> saveInvoiceSeries(String series) async {
    try {
      await _remoteDataSource.saveInvoiceSeries(series);
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    }
  }
}
