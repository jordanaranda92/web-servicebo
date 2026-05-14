import 'package:get_it/get_it.dart';

import '../../../features/invoices/data/repositories/invoices_repository_impl.dart';
import '../../../features/invoices/domain/repositories/invoices_repository.dart';
import '../../../features/invoices/domain/usecases/check_duplicate_invoice.dart';
import '../../../features/invoices/domain/usecases/create_provisional_invoice.dart';
import '../../../features/invoices/domain/usecases/get_fd_contact_names.dart';
import '../../../features/invoices/domain/usecases/get_invoice_by_id.dart';
import '../../../features/invoices/domain/usecases/get_invoices.dart';
import '../../../features/invoices/domain/usecases/get_invoices_by_date_range.dart';
import '../../../features/invoices/domain/usecases/prepare_invoice_preview.dart';
import '../../../features/invoices/presentation/bloc/invoice_detail_cubit.dart';
import '../../../features/invoices/presentation/bloc/invoices_cubit.dart';
import '../../../features/invoices/presentation/bloc/provisional_invoice_cubit.dart';

void registerInvoicesModule(GetIt sl) {
  sl.registerLazySingleton<InvoicesRepository>(
    () => InvoicesRepositoryImpl(sl()),
  );

  sl.registerLazySingleton(() => GetInvoices(sl()));
  sl.registerLazySingleton(() => GetInvoiceById(sl()));
  sl.registerLazySingleton(() => GetInvoicesByDateRange(sl()));
  sl.registerLazySingleton(() => GetFdContactNames(sl()));
  sl.registerLazySingleton(() => PrepareInvoicePreview(sl(), sl(), sl(), sl()));
  sl.registerLazySingleton(() => CheckDuplicateInvoice(sl()));
  sl.registerLazySingleton(() => CreateProvisionalInvoice(sl(), sl()));

  sl.registerFactory(
    () => InvoicesCubit(
      sl(),
      sl<GetInvoicesByDateRange>(),
      sl<GetFdContactNames>(),
    ),
  );
  sl.registerFactory(() => ProvisionalInvoiceCubit(sl(), sl(), sl()));
  sl.registerFactory(() => InvoiceDetailCubit(sl()));
}
