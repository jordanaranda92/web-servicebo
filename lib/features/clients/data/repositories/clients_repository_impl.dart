import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/log/app_logger.dart';
import '../../../client_categories/data/datasources/client_category_firestore_data_source.dart';
import '../../../clients/domain/entities/client_category.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/fd_new_contact.dart';
import '../../domain/repositories/clients_repository.dart';
import '../datasources/client_firestore_data_source.dart';
import '../models/client_model.dart';

class ClientsRepositoryImpl implements ClientsRepository {
  final ClientFirestoreDataSource _clientDataSource;
  final ClientCategoryFirestoreDataSource _categoryDataSource;
  final AppLogger _logger;

  ClientsRepositoryImpl(
    this._clientDataSource,
    this._categoryDataSource,
    this._logger,
  );

  @override
  Future<Either<Failure, List<Client>>> getClients() async {
    _logger.debug('[ClientsRepo] getClients() called');

    try {
      // Load clients and categories in parallel
      final clientsFuture = _clientDataSource.getAll();
      final categoriesFuture = _categoryDataSource.getAll();

      final clientModels = await clientsFuture;
      final categories = await categoriesFuture;

      // Build category ID → name map
      final categoryMap = <String, String>{
        for (final c in categories) c.id: c.name,
      };

      // Build category ID → color map
      final categoryColorMap = <String, String>{
        for (final c in categories)
          if (c.color != null) c.id: c.color!,
      };

      // Convert to entities with resolved category names
      final clients = clientModels.map((model) {
        final categoryName = model.clientCategoryId != null
            ? categoryMap[model.clientCategoryId!]
            : null;
        final categoryColor = model.clientCategoryId != null
            ? categoryColorMap[model.clientCategoryId!]
            : null;
        return model.toEntity(
          categoryName: categoryName,
          categoryColor: categoryColor,
        );
      }).toList();

      // Sort alphabetically by name
      clients.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      _logger.debug('[ClientsRepo] loaded ${clients.length} clients');
      return Right(clients);
    } on ServerException catch (e) {
      _logger.error('[ClientsRepo] ServerException: ${e.message}');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      _logger.error('[ClientsRepo] unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Stream<Either<Failure, List<Client>>> watchClients() {
    _logger.debug('[ClientsRepo] watchClients() called');

    // Combine clients + categories streams to resolve category names
    List<ClientModel>? latestClients;
    List<ClientCategory>? latestCategories;

    final controller = StreamController<Either<Failure, List<Client>>>();

    void emitIfReady() {
      if (latestClients == null || latestCategories == null) return;

      final categoryMap = <String, String>{
        for (final c in latestCategories!) c.id: c.name,
      };

      final categoryColorMap = <String, String>{
        for (final c in latestCategories!)
          if (c.color != null) c.id: c.color!,
      };

      final clients = latestClients!.map((model) {
        final catId = model.clientCategoryId;
        final categoryName = catId != null ? categoryMap[catId] : null;
        final categoryColor = catId != null ? categoryColorMap[catId] : null;
        return model.toEntity(
          categoryName: categoryName,
          categoryColor: categoryColor,
        );
      }).toList();

      // Sort alphabetically by name
      clients.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      _logger.debug(
        '[ClientsRepo] watchClients emitting ${clients.length} clients',
      );
      controller.add(Right(clients));
    }

    final clientsSub = _clientDataSource.watchAll().listen(
      (models) {
        latestClients = models;
        emitIfReady();
      },
      onError: (Object e) {
        _logger.error('[ClientsRepo] watchClients clients error: $e');
        controller.add(Left(ServerFailure()));
      },
    );

    final categoriesSub = _categoryDataSource.watchAll().listen(
      (categories) {
        latestCategories = categories;
        emitIfReady();
      },
      onError: (Object e) {
        _logger.error('[ClientsRepo] watchClients categories error: $e');
        controller.add(Left(ServerFailure()));
      },
    );

    controller.onCancel = () {
      clientsSub.cancel();
      categoriesSub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<Either<Failure, Unit>> saveClientsBatch({
    Map<String, String> nameChanges = const {},
    Map<String, String?> categoryChanges = const {},
    Map<String, Map<String, String?>> shippingMethodsByDayChanges = const {},
  }) async {
    _logger.debug(
      '[ClientsRepo] saveClientsBatch('
      'name: ${nameChanges.length}, '
      'cat: ${categoryChanges.length}, '
      'shipping: ${shippingMethodsByDayChanges.length})',
    );

    try {
      // Collect all document IDs that need changes
      final allIds = <String>{
        ...nameChanges.keys,
        ...categoryChanges.keys,
        ...shippingMethodsByDayChanges.keys,
      };

      if (allIds.isEmpty) return const Right(unit);

      // Build updates map: docId → { field: value }
      final updates = <String, Map<String, dynamic>>{};

      for (final id in allIds) {
        final fields = <String, dynamic>{};
        if (nameChanges.containsKey(id)) {
          fields['name'] = nameChanges[id];
        }
        if (categoryChanges.containsKey(id)) {
          fields['clientCategoryId'] = categoryChanges[id];
        }
        if (shippingMethodsByDayChanges.containsKey(id)) {
          fields['shippingMethodsByDay'] = shippingMethodsByDayChanges[id];
        }
        updates[id] = fields;
      }

      await _clientDataSource.batchUpdate(updates);

      _logger.debug(
        '[ClientsRepo] saveClientsBatch: updated ${updates.length} docs',
      );
      return const Right(unit);
    } on ServerException catch (e) {
      _logger.error('[ClientsRepo] ServerException: ${e.message}');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      _logger.error('[ClientsRepo] unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getExistingFdUuids() async {
    try {
      final clients = await _clientDataSource.getAll();
      final uuids = <String>{
        for (final c in clients)
          if (c.facturaDirectaUuid.isNotEmpty) c.facturaDirectaUuid,
      };
      return Right(uuids);
    } on ServerException catch (e) {
      _logger.error('[ClientsRepo] ServerException: ${e.message}');
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('[ClientsRepo] unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, int>> batchAddFromFdContacts(
    List<FdNewContact> contacts,
  ) async {
    try {
      final models = contacts
          .map(
            (c) => ClientModel(
              id: '',
              name: c.displayName,
              facturaDirectaUuid: c.uuid,
              facturaDirectaName: c.fiscalName,
            ),
          )
          .toList();

      await _clientDataSource.batchAdd(models);
      _logger.debug(
        '[ClientsRepo] batchAddFromFdContacts: added ${models.length}',
      );
      return Right(models.length);
    } on ServerException catch (e) {
      _logger.error('[ClientsRepo] ServerException: ${e.message}');
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('[ClientsRepo] unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }
}
