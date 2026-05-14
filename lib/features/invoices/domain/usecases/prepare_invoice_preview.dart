import 'dart:developer' as dev;

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/data/datasources/factura_directa_api_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../clients/domain/repositories/clients_repository.dart';
import '../../../products/domain/repositories/products_repository.dart';
import '../../../products/domain/usecases/get_fd_products.dart';
import '../entities/invoice_preview.dart';
import '../invoice_failures.dart';

class PrepareInvoicePreviewParams extends Equatable {
  final String clientId;
  final String date;
  final List<String> productIds;
  final List<num> quantities;
  final List<num> refunds;

  const PrepareInvoicePreviewParams({
    required this.clientId,
    required this.date,
    required this.productIds,
    required this.quantities,
    this.refunds = const [],
  });

  @override
  List<Object?> get props => [clientId, date, productIds, quantities, refunds];
}

class PrepareInvoicePreview
    extends UseCase<InvoicePreview, PrepareInvoicePreviewParams> {
  final ClientsRepository _clientsRepository;
  final ProductsRepository _productsRepository;
  final GetFdProducts _getFdProducts;
  final FacturaDirectaApiDataSource _fdApi;

  static const _reMapping = {
    'S_IVA_21': 'S_IVA_RE_5.2',
    'S_IVA_10': 'S_IVA_RE_1.4',
  };

  static const _taxPercentages = {
    'S_IVA_21': 21.0,
    'S_IVA_10': 10.0,
    'S_IVA_4': 4.0,
    'S_IVA_RE_5.2': 5.2,
    'S_IVA_RE_1.4': 1.4,
    'S_IVA_RE_0.5': 0.5,
  };

  PrepareInvoicePreview(
    this._clientsRepository,
    this._productsRepository,
    this._getFdProducts,
    this._fdApi,
  );

  @override
  Future<Either<Failure, InvoicePreview>> call(
    PrepareInvoicePreviewParams params,
  ) async {
    dev.log(
      '[PrepareInvoicePreview] preparing for client=${params.clientId}',
      name: 'Invoices',
    );

    // 1. Get client from Firestore
    final clientsResult = await _clientsRepository.getClients();
    return clientsResult.fold((failure) => Left(failure), (clients) async {
      final client = clients.where((c) => c.id == params.clientId).firstOrNull;
      if (client == null) return Left(ClientNotLinkedFailure());

      // 3. Validate client has FD UUID
      if (client.facturaDirectaUuid.isEmpty) {
        return Left(ClientNotLinkedFailure());
      }

      // 4. Get products from Firestore
      final productsResult = await _productsRepository.getProducts();
      return productsResult.fold((failure) => Left(failure), (products) async {
        // 5. Filter products with quantity > 0 and collect refunds
        final activeProducts =
            <({String productId, String fdUuid, String name, num qty})>[];
        final pendingRefunds = <({String fdUuid, num refund})>[];
        for (var i = 0; i < params.productIds.length; i++) {
          if (i >= params.quantities.length) break;
          final qty = params.quantities[i];

          final product = products
              .where((p) => p.id == params.productIds[i])
              .firstOrNull;
          if (product == null) continue;

          // Collect refund info to resolve FD name later
          final refund = i < params.refunds.length ? params.refunds[i] : 0;
          if (refund > 0 && product.facturaDirectaUuid.isNotEmpty) {
            pendingRefunds.add((
              fdUuid: product.facturaDirectaUuid,
              refund: refund,
            ));
          }

          if (qty <= 0) continue;

          activeProducts.add((
            productId: product.id,
            fdUuid: product.facturaDirectaUuid,
            name: product.name,
            qty: qty,
          ));
        }

        if (activeProducts.isEmpty) return Left(NoLinesFailure());

        // 6. Validate all products have FD UUID
        final unlinked = activeProducts
            .where((p) => p.fdUuid.isEmpty)
            .map((p) => p.name)
            .toList();
        if (unlinked.isNotEmpty) {
          return Left(ProductsNotLinkedFailure(unlinked));
        }

        // 7. Consolidate by FD UUID (sum quantities)
        final consolidated = <String, ({String name, num qty})>{};
        for (final p in activeProducts) {
          final existing = consolidated[p.fdUuid];
          if (existing != null) {
            consolidated[p.fdUuid] = (
              name: existing.name,
              qty: existing.qty + p.qty,
            );
          } else {
            consolidated[p.fdUuid] = (name: p.name, qty: p.qty);
          }
        }

        // 8. Get FD products for prices and taxes
        final fdResult = await _getFdProducts(NoParams());
        return fdResult.fold((failure) => Left(failure), (fdProducts) async {
          final fdMap = {for (final fp in fdProducts) fp.uuid: fp};

          // Build refund notes using FD product names
          final refundNotes = <String>[];
          for (final r in pendingRefunds) {
            final fdProduct = fdMap[r.fdUuid];
            final name = fdProduct?.name ?? r.fdUuid;
            final unit = r.refund == 1 ? 'ud.' : 'uds.';
            refundNotes.add(
              'Abono ${_formatRefundQty(r.refund)} $unit de $name',
            );
          }

          // 9. Get contact from FD for payment method and fiscal position
          String? paymentMethod;
          String? salesFiscalPosition;
          try {
            final contactData = await _fdApi.getContactById(
              client.facturaDirectaUuid,
            );
            final main =
                (contactData['content'] as Map<String, dynamic>?)?['main']
                    as Map<String, dynamic>?;
            paymentMethod = main?['receivePaymentMethod'] as String?;
            salesFiscalPosition =
                (main?['fiscalPositions'] as Map<String, dynamic>?)?['sales']
                    as String?;
            dev.log(
              '[PrepareInvoicePreview] contact fiscal=$salesFiscalPosition, '
              'paymentMethod=$paymentMethod',
              name: 'Invoices',
            );
          } on ServerException catch (e) {
            dev.log(
              '[PrepareInvoicePreview] Error getting contact: ${e.message}',
              name: 'Invoices',
            );
            return Left(ServerFailure());
          } on NetworkException {
            return Left(NetworkFailure());
          }

          final applyRe = salesFiscalPosition == 'aut_re';

          final lines = <InvoicePreviewLine>[];
          for (final entry in consolidated.entries) {
            final fdProduct = fdMap[entry.key];
            if (fdProduct == null) {
              return Left(ProductNotFoundInFdFailure(entry.value.name));
            }

            final unitPrice = fdProduct.salesPrice ?? 0.0;
            final qty = entry.value.qty;

            // Build tax list: original taxes + RE if applicable
            final lineTaxIds = List<String>.from(fdProduct.salesTax);
            if (applyRe) {
              for (final taxId in fdProduct.salesTax) {
                final reId = _reMapping[taxId];
                if (reId != null && !lineTaxIds.contains(reId)) {
                  lineTaxIds.add(reId);
                }
              }
            }

            // Sum all tax percentages for display
            final totalTaxPct = lineTaxIds.fold<double>(
              0.0,
              (sum, id) => sum + (_taxPercentages[id] ?? 0.0),
            );

            lines.add(
              InvoicePreviewLine(
                fdProductUuid: entry.key,
                productName: fdProduct.name,
                quantity: qty,
                unitPrice: unitPrice,
                tax: lineTaxIds,
                taxPercentage: totalTaxPct > 0 ? totalTaxPct : null,
                description: fdProduct.salesDescription,
                lineTotal: qty * unitPrice,
              ),
            );
          }

          // 10. Calculate subtotal, tax breakdown by individual tax ID, total
          final subtotal = lines.fold(0.0, (sum, l) => sum + l.lineTotal);
          final taxBreakdown = <String, ({double base, double amount})>{};
          for (final line in lines) {
            for (final taxId in line.tax) {
              final pct = _taxPercentages[taxId];
              if (pct != null && pct > 0) {
                final label = taxId.contains('RE')
                    ? 'IVA Recargo de Equivalencia '
                          '${pct.toStringAsFixed(2).replaceAll('.', ',')}%'
                    : 'IVA ${pct.toStringAsFixed(0)}%';
                final taxAmount = double.parse(
                  (line.lineTotal * pct / 100).toStringAsFixed(2),
                );
                final existing = taxBreakdown[label];
                taxBreakdown[label] = (
                  base: (existing?.base ?? 0) + line.lineTotal,
                  amount: (existing?.amount ?? 0) + taxAmount,
                );
              }
            }
          }
          final total =
              subtotal + taxBreakdown.values.fold(0.0, (s, v) => s + v.amount);

          return Right(
            InvoicePreview(
              clientName: client.name,
              clientFdUuid: client.facturaDirectaUuid,
              date: params.date,
              lines: lines,
              subtotal: subtotal,
              taxBreakdown: taxBreakdown,
              total: total,
              paymentMethod: paymentMethod,
              refundNotes: refundNotes,
            ),
          );
        });
      });
    });
  }

  static String _formatRefundQty(num value) {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}
