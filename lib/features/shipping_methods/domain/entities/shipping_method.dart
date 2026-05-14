import 'package:equatable/equatable.dart';

class ShippingMethod extends Equatable {
  final String id;
  final String name;
  final String phone;

  const ShippingMethod({required this.id, required this.name, this.phone = ''});

  @override
  List<Object?> get props => [id, name, phone];
}
