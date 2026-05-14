import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../client_categories/domain/usecases/get_client_categories.dart';
import '../../../shipping_methods/domain/entities/shipping_method.dart';
import '../../../shipping_methods/domain/usecases/get_shipping_methods.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/client_category.dart';
import '../../domain/entities/fd_new_contact.dart';
import '../../domain/usecases/add_selected_fd_contacts.dart';
import '../../domain/usecases/fetch_new_fd_contacts.dart';
import '../../domain/usecases/get_fd_fiscal_ids.dart';
import '../../domain/usecases/save_clients_batch.dart';
import '../../domain/usecases/watch_clients.dart';
import 'clients_state.dart';

class ClientsCubit extends Cubit<ClientsState> {
  final WatchClients _watchClients;
  final GetClientCategories _getClientCategories;
  final GetShippingMethods _getShippingMethods;
  final SaveClientsBatch _saveClientsBatch;
  final FetchNewFdContacts _fetchNewFdContacts;
  final AddSelectedFdContacts _addSelectedFdContacts;
  final GetFdFiscalIds _getFdFiscalIds;

  StreamSubscription<Either<Failure, List<Client>>>? _clientsSub;
  String _currentFilter = '';
  Map<String, String> _fiscalIdsByUuid = {};
  bool _pendingFiscalIds = true;
  List<Client>? _bufferedClients;

  ClientsCubit(
    this._watchClients,
    this._getClientCategories,
    this._getShippingMethods,
    this._saveClientsBatch,
    this._fetchNewFdContacts,
    this._addSelectedFdContacts,
    this._getFdFiscalIds,
  ) : super(const ClientsInitial());

  void watchClientsStream() {
    emit(const ClientsLoading());
    _pendingFiscalIds = true;
    _bufferedClients = null;
    _clientsSub?.cancel();

    // Launch fiscal IDs load in parallel
    _loadFiscalIds();

    _clientsSub = _watchClients().listen((result) {
      result.fold(
        (failure) => emit(ClientsError(errorType: _mapFailure(failure))),
        (clients) {
          if (_pendingFiscalIds) {
            _bufferedClients = clients;
          } else {
            _emitLoaded(clients);
          }
        },
      );
    });
  }

  Future<void> _loadFiscalIds() async {
    final result = await _getFdFiscalIds(NoParams());
    result.fold((_) => _fiscalIdsByUuid = {}, (ids) => _fiscalIdsByUuid = ids);
    _pendingFiscalIds = false;

    final buffered = _bufferedClients;
    _bufferedClients = null;
    if (buffered != null) {
      _emitLoaded(buffered);
    }
  }

  Future<void> reloadFiscalIds() async {
    final result = await _getFdFiscalIds(NoParams());
    result.fold((_) {}, (ids) => _fiscalIdsByUuid = ids);

    final currentState = state;
    if (currentState is ClientsLoaded) {
      _emitLoaded(currentState.allClients);
    }
  }

  void _emitLoaded(List<Client> clients) {
    final filtered = _applyFilter(clients);
    emit(
      ClientsLoaded(
        allClients: clients,
        filteredClients: filtered,
        nameFilter: _currentFilter,
        fiscalIdsByUuid: _fiscalIdsByUuid,
      ),
    );
  }

  List<Client> _applyFilter(List<Client> clients) {
    final trimmed = _currentFilter.trim().toLowerCase();
    if (trimmed.isEmpty) return clients;
    return clients.where((c) {
      final fiscalId =
          _fiscalIdsByUuid[c.facturaDirectaUuid]?.toLowerCase() ?? '';
      return c.name.toLowerCase().contains(trimmed) ||
          c.facturaDirectaName.toLowerCase().contains(trimmed) ||
          fiscalId.contains(trimmed);
    }).toList();
  }

  void filterByName(String query) {
    _currentFilter = query;
    final currentState = state;
    if (currentState is! ClientsLoaded) return;

    final filtered = _applyFilter(currentState.allClients);
    emit(
      ClientsLoaded(
        allClients: currentState.allClients,
        filteredClients: filtered,
        nameFilter: query,
        fiscalIdsByUuid: _fiscalIdsByUuid,
      ),
    );
  }

  /// Saves all pending changes in a single batch API call.
  /// Returns false on failure.
  Future<bool> saveBatchChanges({
    Map<String, String> nameChanges = const {},
    Map<String, String?> categoryChanges = const {},
    Map<String, Map<String, String?>> shippingMethodsByDayChanges = const {},
  }) async {
    final result = await _saveClientsBatch(
      SaveClientsBatchParams(
        nameChanges: nameChanges,
        categoryChanges: categoryChanges,
        shippingMethodsByDayChanges: shippingMethodsByDayChanges,
      ),
    );

    return result.isRight();
  }

  /// Fetches the list of available client categories.
  /// Returns null on failure.
  Future<List<ClientCategory>?> fetchCategories() async {
    final result = await _getClientCategories(NoParams());
    return result.fold((_) => null, (categories) => categories);
  }

  Future<List<ShippingMethod>?> fetchShippingMethods() async {
    final result = await _getShippingMethods(NoParams());
    return result.fold((_) => null, (methods) => methods);
  }

  ClientsErrorType _mapFailure(Failure failure) {
    if (failure is NetworkFailure) return ClientsErrorType.network;
    if (failure is ServerFailure) return ClientsErrorType.server;
    return ClientsErrorType.unknown;
  }

  Future<Either<Failure, List<FdNewContact>>> fetchNewContacts() async {
    return _fetchNewFdContacts(NoParams());
  }

  Future<bool> addSelectedContacts(List<FdNewContact> contacts) async {
    final result = await _addSelectedFdContacts(
      AddSelectedFdContactsParams(contacts: contacts),
    );
    return result.isRight();
  }

  @override
  Future<void> close() {
    _clientsSub?.cancel();
    return super.close();
  }
}
