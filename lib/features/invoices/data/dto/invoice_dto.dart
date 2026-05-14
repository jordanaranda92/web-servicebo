import '../../domain/entities/invoice.dart';

class InvoiceDto {
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

  const InvoiceDto({
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

  factory InvoiceDto.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? {};
    final main = content['main'] as Map<String, dynamic>? ?? {};
    final uuid = content['uuid'] as String? ?? '';
    final docNumber = main['docNumber'] as Map<String, dynamic>? ?? {};
    final series = docNumber['series'] as String? ?? '';
    final number = docNumber['number']?.toString() ?? '';
    final counterpart = main['counterpart'] as Map<String, dynamic>? ?? {};
    final counterpartTitle = counterpart['title'] as String?;
    final counterpartName = counterpart['name'] as String?;
    final resolvedContactName =
        (counterpartTitle != null && counterpartTitle.isNotEmpty)
        ? counterpartTitle
        : counterpartName;

    final related = json['related'] as Map<String, dynamic>? ?? {};
    final statusValue = related['state'];
    final status = statusValue is String
        ? statusValue
        : (statusValue is Map ? statusValue['name'] as String? : null);

    final rawLines = main['lines'] as List<dynamic>? ?? [];
    final parsedLines = rawLines.map((l) {
      final lineMap = l as Map<String, dynamic>;
      final rawTax = lineMap['tax'] as List<dynamic>? ?? [];
      final taxList = rawTax.map((t) => t.toString()).toList();
      return InvoiceLine(
        description: lineMap['text'] as String?,
        quantity: (lineMap['quantity'] as num?)?.toDouble(),
        price: (lineMap['unitPrice'] as num?)?.toDouble(),
        total: (lineMap['lineTotal'] as num?)?.toDouble(),
        tax: taxList,
        taxPercentage: (lineMap['taxPercentage'] as num?)?.toDouble(),
      );
    }).toList();

    return InvoiceDto(
      id: uuid,
      docNumber: '$series$number',
      date: main['date'] as String?,
      contactId: main['contact'] as String?,
      contactName: resolvedContactName,
      subtotal: (main['linesTotal'] as num?)?.toDouble(),
      total: (main['total'] as num?)?.toDouble(),
      currency: main['currency'] as String?,
      isDraft: main['draft'] == true,
      isVoided: main['voided'] == true,
      status: status,
      lines: parsedLines,
    );
  }

  Invoice toEntity() {
    // Derive effective status: if the invoice is a draft, force 'draft' status
    // regardless of what related.state says (FD may not return state for drafts).
    final effectiveStatus = isDraft ? 'draft' : (isVoided ? 'voided' : status);

    return Invoice(
      id: id,
      docNumber: docNumber,
      date: date,
      contactId: contactId,
      contactName: contactName,
      subtotal: subtotal,
      total: total,
      currency: currency,
      isDraft: isDraft,
      isVoided: isVoided,
      status: effectiveStatus,
      lines: lines,
    );
  }
}
