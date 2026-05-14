import 'package:equatable/equatable.dart';

class Invoice extends Equatable {
  final String id;
  final String docNumber;
  final String? date;
  final String? contactId;
  final String? contactName;
  final double? subtotal;
  final double? total;
  final String? currency;
  final bool isDraft;
  final bool isVoided;
  final String? status;
  final List<InvoiceLine> lines;

  const Invoice({
    required this.id,
    required this.docNumber,
    this.date,
    this.contactId,
    this.contactName,
    this.subtotal,
    this.total,
    this.currency,
    this.isDraft = false,
    this.isVoided = false,
    this.status,
    this.lines = const [],
  });

  Invoice copyWith({String? contactName}) {
    return Invoice(
      id: id,
      docNumber: docNumber,
      date: date,
      contactId: contactId,
      contactName: contactName ?? this.contactName,
      subtotal: subtotal,
      total: total,
      currency: currency,
      isDraft: isDraft,
      isVoided: isVoided,
      status: status,
      lines: lines,
    );
  }

  @override
  List<Object?> get props => [
    id,
    docNumber,
    date,
    contactId,
    contactName,
    subtotal,
    total,
    currency,
    isDraft,
    isVoided,
    status,
    lines,
  ];
}

class InvoiceLine extends Equatable {
  final String? description;
  final double? quantity;
  final double? price;
  final double? total;
  final List<String> tax;
  final double? taxPercentage;

  const InvoiceLine({
    this.description,
    this.quantity,
    this.price,
    this.total,
    this.tax = const [],
    this.taxPercentage,
  });

  @override
  List<Object?> get props => [
    description,
    quantity,
    price,
    total,
    tax,
    taxPercentage,
  ];
}
