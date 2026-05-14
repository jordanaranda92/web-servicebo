import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/data/datasources/factura_directa_api_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';

/// Returns a map of FD contact UUID → fiscalId (NIF/CIF).
class GetFdFiscalIds extends UseCase<Map<String, String>, NoParams> {
  final FacturaDirectaApiDataSource _fdApi;

  GetFdFiscalIds(this._fdApi);

  @override
  Future<Either<Failure, Map<String, String>>> call(NoParams params) async {
    dev.log('[GetFdFiscalIds] fetching fiscal IDs from FD', name: 'Clients');

    try {
      final rawContacts = await _fdApi.getContacts();
      final fiscalIds = <String, String>{};

      for (final json in rawContacts) {
        final content = json['content'] as Map<String, dynamic>?;
        final main = content?['main'] as Map<String, dynamic>? ?? {};
        final uuid = content?['uuid'] as String? ?? '';
        final fiscalId = main['fiscalId'] as String?;

        if (uuid.isNotEmpty && fiscalId != null && fiscalId.isNotEmpty) {
          fiscalIds[uuid] = fiscalId;
        }
      }

      dev.log(
        '[GetFdFiscalIds] resolved ${fiscalIds.length} fiscal IDs',
        name: 'Clients',
      );

      return Right(fiscalIds);
    } on ServerException catch (e) {
      dev.log(
        '[GetFdFiscalIds] ServerException: ${e.message}',
        name: 'Clients',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } catch (e, st) {
      dev.log(
        '[GetFdFiscalIds] unexpected error: $e',
        name: 'Clients',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure());
    }
  }
}
