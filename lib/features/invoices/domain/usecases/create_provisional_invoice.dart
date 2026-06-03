import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../entities/invoice.dart';
import '../entities/invoice_preview.dart';
import '../repositories/invoices_repository.dart';

class CreateProvisionalInvoice extends UseCase<Invoice, InvoicePreview> {
  final InvoicesRepository _invoicesRepo;
  final SettingsRepository _settingsRepo;

  static const _currency = 'EUR';

  CreateProvisionalInvoice(this._invoicesRepo, this._settingsRepo);

  static String calculateDueDateFromInvoiceDate(String invoiceDate) {
    final parsedDate = DateTime.tryParse(invoiceDate);
    if (parsedDate == null) {
      return invoiceDate;
    }

    final nextMonth = parsedDate.month == DateTime.december
        ? DateTime(parsedDate.year + 1, DateTime.january)
        : DateTime(parsedDate.year, parsedDate.month + 1);
    final lastDayOfNextMonth = DateTime(
      nextMonth.year,
      nextMonth.month + 1,
      0,
    ).day;
    final normalizedDay = parsedDate.day > lastDayOfNextMonth
        ? lastDayOfNextMonth
        : parsedDate.day;
    final dueDate = DateTime(nextMonth.year, nextMonth.month, normalizedDay);

    final month = dueDate.month.toString().padLeft(2, '0');
    final day = dueDate.day.toString().padLeft(2, '0');
    return '${dueDate.year}-$month-$day';
  }

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
            'dueDate': calculateDueDateFromInvoiceDate(preview.date),
            'draft': true,
            'lines': lines,
            if (preview.paymentMethod != null)
              'paymentMethod': preview.paymentMethod,
            if (preview.refundNotes.isNotEmpty)
              'notes': preview.refundNotes.join('\n'),
          },
        },
      };

      final result = await _invoicesRepo.createInvoice(body);
      return result.fold((failure) => Left(failure), (invoice) {
        dev.log(
          '[CreateProvisionalInvoice] created invoice ${invoice.docNumber}',
          name: 'Invoices',
        );
        return Right(invoice);
      });
    });
  }
}
