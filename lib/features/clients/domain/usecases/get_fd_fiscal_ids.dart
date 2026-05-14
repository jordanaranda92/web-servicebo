import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/domain/repositories/factura_directa_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';

/// Returns a map of FD contact UUID → fiscalId (NIF/CIF).
class GetFdFiscalIds extends UseCase<Map<String, String>, NoParams> {
  final FacturaDirectaRepository _fdRepo;

  GetFdFiscalIds(this._fdRepo);

  @override
  Future<Either<Failure, Map<String, String>>> call(NoParams params) async {
    dev.log('[GetFdFiscalIds] fetching fiscal IDs from FD', name: 'Clients');

    final contactsResult = await _fdRepo.getContacts();
    return contactsResult.fold((failure) => Left(failure), (rawContacts) {
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
    });
  }
}
