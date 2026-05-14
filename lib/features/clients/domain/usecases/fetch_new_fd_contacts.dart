import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/data/datasources/factura_directa_api_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/fd_new_contact.dart';
import '../repositories/clients_repository.dart';

class FetchNewFdContacts extends UseCase<List<FdNewContact>, NoParams> {
  final FacturaDirectaApiDataSource _fdApi;
  final ClientsRepository _repository;

  FetchNewFdContacts(this._fdApi, this._repository);

  @override
  Future<Either<Failure, List<FdNewContact>>> call(NoParams params) async {
    dev.log('[FetchNewFdContacts] fetching new contacts', name: 'Clients');

    try {
      final rawContacts = await _fdApi.getContacts();
      dev.log(
        '[FetchNewFdContacts] fetched ${rawContacts.length} contacts from FD',
        name: 'Clients',
      );

      final uuidsResult = await _repository.getExistingFdUuids();
      final existingUuids = uuidsResult.getOrElse((_) => const {});

      final newContacts = <FdNewContact>[];

      for (final json in rawContacts) {
        final content = json['content'] as Map<String, dynamic>?;
        final main = content?['main'] as Map<String, dynamic>? ?? {};
        final uuid = content?['uuid'] as String? ?? '';

        if (uuid.isEmpty || existingUuids.contains(uuid)) continue;

        final fdName = (main['name'] as String?) ?? '';
        final fdTitle = main['title'] as String?;
        final displayName = (fdTitle != null && fdTitle.isNotEmpty)
            ? fdTitle
            : fdName;
        final fiscalId = (main['fiscalId'] as String?) ?? '';

        newContacts.add(
          FdNewContact(
            uuid: uuid,
            displayName: displayName,
            fiscalName: fdName,
            fiscalId: fiscalId,
          ),
        );
      }

      dev.log(
        '[FetchNewFdContacts] found ${newContacts.length} new contacts',
        name: 'Clients',
      );

      return Right(newContacts);
    } on ServerException catch (e) {
      dev.log(
        '[FetchNewFdContacts] ServerException: ${e.message}',
        name: 'Clients',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } catch (e, st) {
      dev.log(
        '[FetchNewFdContacts] unexpected error: $e',
        name: 'Clients',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure());
    }
  }
}
