import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/get_invoice_by_id.dart';
import 'invoice_detail_state.dart';

class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  final GetInvoiceById _getInvoiceById;

  String? _lastId;

  InvoiceDetailCubit(this._getInvoiceById)
    : super(const InvoiceDetailInitial());

  Future<void> loadInvoice(String id) async {
    _lastId = id;
    emit(const InvoiceDetailLoading());

    final result = await _getInvoiceById(id);

    result.fold(
      (failure) => emit(InvoiceDetailError(errorType: _mapFailure(failure))),
      (invoice) => emit(InvoiceDetailLoaded(invoice: invoice)),
    );
  }

  Future<void> retry() async {
    final id = _lastId;
    if (id != null) {
      await loadInvoice(id);
    }
  }

  InvoiceDetailErrorType _mapFailure(Failure failure) {
    if (failure is ConfigNotFoundFailure) {
      return InvoiceDetailErrorType.configNotFound;
    }
    if (failure is NetworkFailure) {
      return InvoiceDetailErrorType.network;
    }
    if (failure is ServerFailure) {
      return InvoiceDetailErrorType.server;
    }
    return InvoiceDetailErrorType.unknown;
  }
}
