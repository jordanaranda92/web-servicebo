import 'package:equatable/equatable.dart';

import '../../domain/entities/invoice.dart';

sealed class InvoiceDetailState extends Equatable {
  const InvoiceDetailState();

  @override
  List<Object?> get props => [];
}

class InvoiceDetailInitial extends InvoiceDetailState {
  const InvoiceDetailInitial();
}

class InvoiceDetailLoading extends InvoiceDetailState {
  const InvoiceDetailLoading();
}

class InvoiceDetailLoaded extends InvoiceDetailState {
  final Invoice invoice;

  const InvoiceDetailLoaded({required this.invoice});

  @override
  List<Object?> get props => [invoice];
}

class InvoiceDetailError extends InvoiceDetailState {
  final InvoiceDetailErrorType errorType;

  const InvoiceDetailError({required this.errorType});

  @override
  List<Object?> get props => [errorType];
}

enum InvoiceDetailErrorType { configNotFound, network, server, unknown }
