import 'package:fpdart/fpdart.dart';

import '../../../../core/data/datasources/factura_directa_api_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoices_repository.dart';
import '../dto/invoice_dto.dart';

class InvoicesRepositoryImpl implements InvoicesRepository {
  final FacturaDirectaApiDataSource _apiDataSource;

  InvoicesRepositoryImpl(this._apiDataSource);

  @override
  Future<Either<Failure, List<Invoice>>> getInvoices() async {
    try {
      final rawItems = await _apiDataSource.getInvoices();
      final invoices =
          rawItems.map((json) => InvoiceDto.fromJson(json).toEntity()).toList()
            ..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
      return Right(invoices);
    } on ServerException {
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on ParsingException {
      return Left(EntityMappingFailure());
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesByDateRange({
    required String minDate,
    required String maxDate,
  }) async {
    try {
      final rawItems = await _apiDataSource.getInvoicesByDateRange(
        minDate: minDate,
        maxDate: maxDate,
      );
      final invoices = rawItems
          .map((json) => InvoiceDto.fromJson(json).toEntity())
          .toList();
      return Right(invoices);
    } on ServerException {
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on ParsingException {
      return Left(EntityMappingFailure());
    }
  }

  @override
  Future<Either<Failure, Invoice>> getInvoiceById(String id) async {
    try {
      final rawData = await _apiDataSource.getInvoiceById(id);
      var invoice = InvoiceDto.fromJson(rawData).toEntity();

      // Best-effort: resolve contact name from FD contact API
      final contactId = invoice.contactId;
      if (contactId != null && contactId.isNotEmpty) {
        try {
          final contactData = await _apiDataSource.getContactById(contactId);
          final content = contactData['content'] as Map<String, dynamic>? ?? {};
          final main = content['main'] as Map<String, dynamic>? ?? {};
          final title = main['title'] as String?;
          final name = main['name'] as String?;
          final resolvedName = (title != null && title.isNotEmpty)
              ? title
              : name;
          if (resolvedName != null && resolvedName.isNotEmpty) {
            invoice = invoice.copyWith(contactName: resolvedName);
          }
        } catch (_) {
          // Non-blocking: keep the name from the invoice if contact fetch fails
        }
      }

      return Right(invoice);
    } on ServerException {
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on ParsingException {
      return Left(EntityMappingFailure());
    }
  }
}
