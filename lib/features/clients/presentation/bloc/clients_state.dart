import 'package:equatable/equatable.dart';

import '../../domain/entities/client.dart';

abstract class ClientsState extends Equatable {
  const ClientsState();

  @override
  List<Object?> get props => [];
}

class ClientsInitial extends ClientsState {
  const ClientsInitial();
}

class ClientsLoading extends ClientsState {
  const ClientsLoading();
}

class ClientsLoaded extends ClientsState {
  final List<Client> allClients;
  final List<Client> filteredClients;
  final String nameFilter;
  final bool isSaving;
  final bool isSyncing;
  final Map<String, String> fiscalIdsByUuid;

  const ClientsLoaded({
    required this.allClients,
    required this.filteredClients,
    this.nameFilter = '',
    this.isSaving = false,
    this.isSyncing = false,
    this.fiscalIdsByUuid = const {},
  });

  @override
  List<Object?> get props => [
    allClients,
    filteredClients,
    nameFilter,
    isSaving,
    isSyncing,
    fiscalIdsByUuid,
  ];
}

class ClientsError extends ClientsState {
  final ClientsErrorType errorType;

  const ClientsError({required this.errorType});

  @override
  List<Object?> get props => [errorType];
}

enum ClientsErrorType { network, server, unknown }
