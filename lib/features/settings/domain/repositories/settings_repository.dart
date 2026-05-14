import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

abstract class SettingsRepository {
  // Page size
  int getPageSize();
  Future<Either<Failure, Unit>> savePageSize(int size);

  // Invoice series
  Future<Either<Failure, String?>> getInvoiceSeries();
  Future<Either<Failure, Unit>> saveInvoiceSeries(String series);
}
