import 'package:cloud_functions/cloud_functions.dart';

import '../../error/exceptions.dart';
import '../../log/app_logger.dart';
import 'factura_directa_api_data_source.dart';

class FacturaDirectaApiDataSourceImpl implements FacturaDirectaApiDataSource {
  FacturaDirectaApiDataSourceImpl(this._logger);

  final AppLogger _logger;

  /// Calls the Cloud Function proxy with unified error handling.
  Future<Map<String, dynamic>> _callProxy({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    _logger.debug('[FD API] $method $path via proxy');
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('fdProxy');

      final payload = <String, dynamic>{
        'path': path,
        'method': method,
        if (queryParameters != null) 'queryParameters': queryParameters,
        if (body != null) 'body': body,
      };

      final result = await callable.call<Map<String, dynamic>>(payload);
      _logger.debug('[FD API] Proxy response keys: ${result.data.keys}');
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      _logger.warning('[FD API] CloudFunction error: ${e.code} ${e.message}');
      if (e.code == 'unauthenticated') {
        throw const ServerException(
          message: 'Autenticación requerida',
          statusCode: 401,
        );
      }
      throw ServerException(message: e.message ?? 'Error del proxy');
    } catch (e, st) {
      _logger.error('[FD API] Proxy unexpected error: $e', e, st);
      throw NetworkException('Error al llamar al proxy: $e');
    }
  }

  List<Map<String, dynamic>> _parseList(Map<String, dynamic> data) {
    try {
      final items = data['items'] as List<dynamic>;
      _logger.debug('[FD API] items count: ${items.length}');
      return items.cast<Map<String, dynamic>>();
    } on TypeError catch (e, st) {
      _logger.error('[FD API] Parse error: $e', e, st);
      throw ParsingException('Error al parsear la respuesta: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getContacts() async {
    final data = await _callProxy(
      path: '/contacts',
      queryParameters: {'limit': '500'},
    );
    return _parseList(data);
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    final data = await _callProxy(
      path: '/products',
      queryParameters: {'limit': '500'},
    );
    return _parseList(data);
  }

  @override
  Future<List<Map<String, dynamic>>> getInvoices() async {
    final normalData = await _callProxy(
      path: '/invoices',
      queryParameters: {'limit': '500', 'related': 'state'},
    );
    final items = _parseList(normalData);

    // Best-effort: try to fetch drafts too
    try {
      final draftData = await _callProxy(
        path: '/invoices',
        queryParameters: {'limit': '500', 'related': 'state', 'draft': 'only'},
      );
      items.addAll(_parseList(draftData));
    } on Exception catch (e) {
      _logger.warning('[FD API] Could not fetch draft invoices: $e');
    }

    return items;
  }

  @override
  Future<Map<String, dynamic>> getInvoiceById(String id) async {
    final data = await _callProxy(
      path: '/invoices/$id',
      queryParameters: {'related': 'state'},
    );
    return data;
  }

  @override
  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> body) async {
    final data = await _callProxy(
      path: '/invoices',
      method: 'POST',
      body: body,
    );
    return data;
  }

  @override
  Future<List<Map<String, dynamic>>> getInvoicesByContact({
    required String contactUuid,
    required String minDate,
    required String maxDate,
    String? draft,
  }) async {
    final qp = <String, String>{
      'contact': contactUuid,
      'minDate': minDate,
      'maxDate': maxDate,
      'limit': '5',
    };
    if (draft != null) qp['draft'] = draft;

    final data = await _callProxy(path: '/invoices', queryParameters: qp);
    return _parseList(data);
  }

  @override
  Future<List<Map<String, dynamic>>> getInvoicesByDateRange({
    required String minDate,
    required String maxDate,
  }) async {
    final normalData = await _callProxy(
      path: '/invoices',
      queryParameters: {
        'minDate': minDate,
        'maxDate': maxDate,
        'related': 'state',
        'limit': '500',
      },
    );
    final items = _parseList(normalData);

    // Best-effort: try to fetch drafts too
    try {
      final draftData = await _callProxy(
        path: '/invoices',
        queryParameters: {
          'minDate': minDate,
          'maxDate': maxDate,
          'related': 'state',
          'limit': '500',
          'draft': 'only',
        },
      );
      items.addAll(_parseList(draftData));
    } on Exception catch (e) {
      _logger.warning('[FD API] Could not fetch draft invoices: $e');
    }

    return items;
  }

  @override
  Future<Map<String, dynamic>> getContactById(
    String contactId, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _callProxy(
      path: '/contacts/$contactId',
      queryParameters: queryParameters?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
    return data;
  }
}
