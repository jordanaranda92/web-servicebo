import 'package:equatable/equatable.dart';

class OrderDateInfo extends Equatable {
  final DateTime date;
  final int clientCount;
  final int productCount;

  const OrderDateInfo({
    required this.date,
    required this.clientCount,
    required this.productCount,
  });

  @override
  List<Object?> get props => [date, clientCount, productCount];
}
