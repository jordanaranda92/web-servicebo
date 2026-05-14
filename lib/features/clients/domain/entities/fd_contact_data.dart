import 'package:equatable/equatable.dart';

class FdContactData extends Equatable {
  final String uuid;
  final String name;
  final String? fiscalId;
  final String? email;
  final String? phone;
  final String? city;
  final String? province;
  final String? country;
  final String? paymentMethod;
  final String? currency;

  const FdContactData({
    required this.uuid,
    required this.name,
    this.fiscalId,
    this.email,
    this.phone,
    this.city,
    this.province,
    this.country,
    this.paymentMethod,
    this.currency,
  });

  @override
  List<Object?> get props => [
    uuid,
    name,
    fiscalId,
    email,
    phone,
    city,
    province,
    country,
    paymentMethod,
    currency,
  ];
}
