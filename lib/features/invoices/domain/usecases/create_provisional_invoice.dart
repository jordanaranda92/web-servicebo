import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/data/datasources/factura_directa_api_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../data/dto/invoice_dto.dart';
import '../entities/invoice.dart';
import '../entities/invoice_preview.dart';

class CreateProvisionalInvoice extends UseCase<Invoice, InvoicePreview> {
  final FacturaDirectaApiDataSource _fdApi;
  final SettingsRepository _settingsRepo;

  static const _currency = 'EUR';

  CreateProvisionalInvoice(this._fdApi, this._settingsRepo);

  @override
  Future<Either<Failure, Invoice>> call(InvoicePreview preview) async {
    dev.log(
      '[CreateProvisionalInvoice] creating for client=${preview.clientName}',
      name: 'Invoices',
    );

    // Resolve invoice series from Firestore
    final seriesResult = await _settingsRepo.getInvoiceSeries();
    return seriesResult.fold((failure) => Left(failure), (series) async {
      if (series == null || series.isEmpty) {
        return Left(ConfigNotFoundFailure());
      }

      try {
        final lines = preview.lines.map((line) {
          return <String, dynamic>{
            'quantity': line.quantity,
            'unitPrice': line.unitPrice,
            'tax': line.tax,
            'text': line.description ?? line.productName,
            'document': line.fdProductUuid,
          };
        }).toList();

        final body = <String, dynamic>{
          'content': {
            'type': 'invoice',
            'main': {
              'docNumber': {'series': series},
              'contact': preview.clientFdUuid,
              'currency': _currency,
              'date': preview.date,
              'draft': true,
              'lines': lines,
              if (preview.paymentMethod != null)
                'paymentMethod': preview.paymentMethod,
              if (preview.refundNotes.isNotEmpty)
                'notes': preview.refundNotes.join('\n'),
            },
          },
        };

        final response = await _fdApi.createInvoice(body);
        final invoice = InvoiceDto.fromJson(response).toEntity();

        dev.log(
          '[CreateProvisionalInvoice] created invoice ${invoice.docNumber}',
          name: 'Invoices',
        );

        return Right(invoice);
      } on ServerException catch (e) {
        dev.log(
          '[CreateProvisionalInvoice] ServerException: ${e.message}',
          name: 'Invoices',
        );
        return Left(ServerFailure());
      } on NetworkException {
        return Left(NetworkFailure());
      } on ParsingException {
        return Left(EntityMappingFailure());
      } catch (e, st) {
        dev.log(
          '[CreateProvisionalInvoice] unexpected error: $e',
          name: 'Invoices',
          error: e,
          stackTrace: st,
        );
        return Left(InternalFailure());
      }
    });
  }
}
