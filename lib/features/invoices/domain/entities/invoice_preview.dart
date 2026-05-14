import 'package:equatable/equatable.dart';

class InvoicePreviewLine extends Equatable {
  final String fdProductUuid;
  final String productName;
  final num quantity;
  final double unitPrice;
  final List<String> tax;
  final double? taxPercentage;
  final String? description;
  final double lineTotal;

  const InvoicePreviewLine({
    required this.fdProductUuid,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.tax,
    this.taxPercentage,
    this.description,
    required this.lineTotal,
  });

  @override
  List<Object?> get props => [
    fdProductUuid,
    productName,
    quantity,
    unitPrice,
    tax,
    taxPercentage,
    description,
    lineTotal,
  ];
}

class InvoicePreview extends Equatable {
  final String clientName;
  final String clientFdUuid;
  final String date;
  final List<InvoicePreviewLine> lines;
  final double subtotal;
  final Map<String, ({double base, double amount})> taxBreakdown;
  final double total;
  final String? paymentMethod;
  final List<String> refundNotes;

  const InvoicePreview({
    required this.clientName,
    required this.clientFdUuid,
    required this.date,
    required this.lines,
    required this.subtotal,
    required this.taxBreakdown,
    required this.total,
    this.paymentMethod,
    this.refundNotes = const [],
  });

  @override
  List<Object?> get props => [
    clientName,
    clientFdUuid,
    date,
    lines,
    subtotal,
    taxBreakdown,
    total,
    paymentMethod,
    refundNotes,
  ];
}
