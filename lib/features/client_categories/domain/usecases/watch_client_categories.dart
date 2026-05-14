import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../clients/domain/entities/client_category.dart';
import '../repositories/client_categories_repository.dart';

class WatchClientCategories {
  final ClientCategoriesRepository _repository;

  WatchClientCategories(this._repository);

  Stream<Either<Failure, List<ClientCategory>>> call() {
    return _repository.watchCategories();
  }
}
