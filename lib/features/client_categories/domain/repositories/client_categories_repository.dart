import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../clients/domain/entities/client_category.dart';

abstract class ClientCategoriesRepository {
  Future<Either<Failure, List<ClientCategory>>> getCategories();
  Stream<Either<Failure, List<ClientCategory>>> watchCategories();
  Future<Either<Failure, Unit>> addCategory({
    required String name,
    String? color,
  });
  Future<Either<Failure, Unit>> updateCategory({
    required String id,
    required String name,
    String? color,
  });
  Future<Either<Failure, Unit>> deleteCategory({required String id});
}
