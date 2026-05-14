import '../../../../core/error/failure.dart';

class ClientNotLinkedFailure extends Failure {}

class ProductsNotLinkedFailure extends Failure {
  final List<String> productNames;

  ProductsNotLinkedFailure(this.productNames);

  @override
  List<Object> get props => [productNames];
}

class ProductNotFoundInFdFailure extends Failure {
  final String productName;

  ProductNotFoundInFdFailure(this.productName);

  @override
  List<Object> get props => [productName];
}

class NoLinesFailure extends Failure {}
