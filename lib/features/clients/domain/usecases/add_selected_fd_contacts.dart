import 'dart:developer' as dev;

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/fd_new_contact.dart';
import '../repositories/clients_repository.dart';

class AddSelectedFdContacts extends UseCase<int, AddSelectedFdContactsParams> {
  final ClientsRepository _repository;

  AddSelectedFdContacts(this._repository);

  @override
  Future<Either<Failure, int>> call(AddSelectedFdContactsParams params) async {
    dev.log(
      '[AddSelectedFdContacts] adding ${params.contacts.length} contacts',
      name: 'Clients',
    );

    final result = await _repository.batchAddFromFdContacts(params.contacts);

    result.fold(
      (failure) =>
          dev.log('[AddSelectedFdContacts] failed: $failure', name: 'Clients'),
      (count) => dev.log(
        '[AddSelectedFdContacts] added $count clients',
        name: 'Clients',
      ),
    );

    return result;
  }
}

class AddSelectedFdContactsParams extends Equatable {
  final List<FdNewContact> contacts;

  const AddSelectedFdContactsParams({required this.contacts});

  @override
  List<Object?> get props => [contacts];
}
