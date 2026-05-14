import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/invoice_preview.dart';
import '../../domain/invoice_failures.dart';
import '../../domain/usecases/check_duplicate_invoice.dart';
import '../../domain/usecases/create_provisional_invoice.dart';
import '../../domain/usecases/prepare_invoice_preview.dart';
import 'provisional_invoice_state.dart';

class ProvisionalInvoiceCubit extends Cubit<ProvisionalInvoiceState> {
  final PrepareInvoicePreview _prepareInvoicePreview;
  final CheckDuplicateInvoice _checkDuplicateInvoice;
  final CreateProvisionalInvoice _createProvisionalInvoice;

  ProvisionalInvoiceCubit(
    this._prepareInvoicePreview,
    this._checkDuplicateInvoice,
    this._createProvisionalInvoice,
  ) : super(const ProvisionalInvoiceInitial());

  Future<void> prepare({
    required String clientId,
    required String date,
    required List<String> productIds,
    required List<num> quantities,
    List<num> refunds = const [],
  }) async {
    emit(const ProvisionalInvoiceLoading());

    final result = await _prepareInvoicePreview(
      PrepareInvoicePreviewParams(
        clientId: clientId,
        date: date,
        productIds: productIds,
        quantities: quantities,
        refunds: refunds,
      ),
    );

    result.fold(
      (failure) => emit(
        ProvisionalInvoiceError(
          errorType: _mapFailure(failure),
          details: _extractDetails(failure),
        ),
      ),
      (preview) async {
        // Check for duplicate invoices (non-blocking on error)
        final duplicateResult = await _checkDuplicateInvoice(
          CheckDuplicateInvoiceParams(
            contactUuid: preview.clientFdUuid,
            date: preview.date,
          ),
        );

        duplicateResult.fold(
          // If check fails, show preview without warning
          (_) => emit(ProvisionalInvoicePreviewReady(preview: preview)),
          (isDuplicate) {
            if (isDuplicate) {
              emit(ProvisionalInvoiceDuplicateWarning(preview: preview));
            } else {
              emit(ProvisionalInvoicePreviewReady(preview: preview));
            }
          },
        );
      },
    );
  }

  Future<void> confirm(InvoicePreview preview) async {
    emit(ProvisionalInvoiceCreating(preview: preview));

    final result = await _createProvisionalInvoice(preview);

    result.fold(
      (failure) => emit(
        ProvisionalInvoiceError(
          errorType: _mapFailure(failure),
          details: _extractDetails(failure),
        ),
      ),
      (invoice) => emit(ProvisionalInvoiceSuccess(invoice: invoice)),
    );
  }

  ProvisionalInvoiceErrorType _mapFailure(Failure failure) {
    if (failure is ConfigNotFoundFailure) {
      return ProvisionalInvoiceErrorType.configNotFound;
    }
    if (failure is ClientNotLinkedFailure) {
      return ProvisionalInvoiceErrorType.clientNotLinked;
    }
    if (failure is ProductsNotLinkedFailure) {
      return ProvisionalInvoiceErrorType.productsNotLinked;
    }
    if (failure is ProductNotFoundInFdFailure) {
      return ProvisionalInvoiceErrorType.productNotFoundInFd;
    }
    if (failure is NoLinesFailure) {
      return ProvisionalInvoiceErrorType.noLines;
    }
    if (failure is NetworkFailure) {
      return ProvisionalInvoiceErrorType.network;
    }
    if (failure is ServerFailure) {
      return ProvisionalInvoiceErrorType.server;
    }
    return ProvisionalInvoiceErrorType.unknown;
  }

  List<String>? _extractDetails(Failure failure) {
    if (failure is ProductsNotLinkedFailure) return failure.productNames;
    if (failure is ProductNotFoundInFdFailure) return [failure.productName];
    return null;
  }
}
