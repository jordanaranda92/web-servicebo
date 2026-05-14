import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/domain/repositories/factura_directa_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/fd_new_contact.dart';
import '../repositories/clients_repository.dart';

class FetchNewFdContacts extends UseCase<List<FdNewContact>, NoParams> {
  final FacturaDirectaRepository _fdRepo;
  final ClientsRepository _repository;

  FetchNewFdContacts(this._fdRepo, this._repository);

  @override
  Future<Either<Failure, List<FdNewContact>>> call(NoParams params) async {
    dev.log('[FetchNewFdContacts] fetching new contacts', name: 'Clients');

    final contactsResult = await _fdRepo.getContacts();
    return contactsResult.fold((failure) => Left(failure), (rawContacts) async {
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
    });
  }
}
