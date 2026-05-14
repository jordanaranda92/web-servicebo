import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../clients/domain/entities/client_category.dart';
import '../repositories/client_categories_repository.dart';

class GetClientCategories extends UseCase<List<ClientCategory>, NoParams> {
  final ClientCategoriesRepository _repository;

  GetClientCategories(this._repository);

  @override
  Future<Either<Failure, List<ClientCategory>>> call(NoParams params) {
    return _repository.getCategories();
  }
}
