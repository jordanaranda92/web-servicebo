import 'package:equatable/equatable.dart';

import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_preview.dart';

sealed class ProvisionalInvoiceState extends Equatable {
  const ProvisionalInvoiceState();

  @override
  List<Object?> get props => [];
}

final class ProvisionalInvoiceInitial extends ProvisionalInvoiceState {
  const ProvisionalInvoiceInitial();
}

final class ProvisionalInvoiceLoading extends ProvisionalInvoiceState {
  const ProvisionalInvoiceLoading();
}

final class ProvisionalInvoicePreviewReady extends ProvisionalInvoiceState {
  final InvoicePreview preview;

  const ProvisionalInvoicePreviewReady({required this.preview});

  @override
  List<Object?> get props => [preview];
}

final class ProvisionalInvoiceDuplicateWarning extends ProvisionalInvoiceState {
  final InvoicePreview preview;

  const ProvisionalInvoiceDuplicateWarning({required this.preview});

  @override
  List<Object?> get props => [preview];
}

final class ProvisionalInvoiceCreating extends ProvisionalInvoiceState {
  final InvoicePreview preview;

  const ProvisionalInvoiceCreating({required this.preview});

  @override
  List<Object?> get props => [preview];
}

final class ProvisionalInvoiceSuccess extends ProvisionalInvoiceState {
  final Invoice invoice;

  const ProvisionalInvoiceSuccess({required this.invoice});

  @override
  List<Object?> get props => [invoice];
}

final class ProvisionalInvoiceError extends ProvisionalInvoiceState {
  final ProvisionalInvoiceErrorType errorType;
  final List<String>? details;

  const ProvisionalInvoiceError({required this.errorType, this.details});

  @override
  List<Object?> get props => [errorType, details];
}

enum ProvisionalInvoiceErrorType {
  configNotFound,
  clientNotLinked,
  productsNotLinked,
  productNotFoundInFd,
  noLines,
  network,
  server,
  unknown,
}
