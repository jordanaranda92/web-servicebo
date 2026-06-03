import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:servicebo/core/error/failure.dart';
import 'package:servicebo/features/invoices/domain/entities/invoice.dart';
import 'package:servicebo/features/invoices/domain/entities/invoice_preview.dart';
import 'package:servicebo/features/invoices/domain/repositories/invoices_repository.dart';
import 'package:servicebo/features/invoices/domain/usecases/create_provisional_invoice.dart';
import 'package:servicebo/features/settings/domain/repositories/settings_repository.dart';

class MockInvoicesRepository extends Mock implements InvoicesRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late CreateProvisionalInvoice useCase;
  late MockInvoicesRepository mockInvoicesRepository;
  late MockSettingsRepository mockSettingsRepository;

  const tInvoicePreview = InvoicePreview(
    clientName: 'Cliente de prueba',
    clientFdUuid: 'con_10000000-0000-4000-8000-000000000000',
    date: '2026-06-02',
    lines: [
      InvoicePreviewLine(
        fdProductUuid: 'pro_10000000-0000-4000-8000-000000000000',
        productName: 'Servicio',
        quantity: 1,
        unitPrice: 100,
        tax: ['S_IVA_21'],
        description: 'Descripcion servicio',
        lineTotal: 100,
      ),
    ],
    subtotal: 100,
    taxBreakdown: {'S_IVA_21': (base: 100, amount: 21)},
    total: 121,
  );

  const tCreatedInvoice = Invoice(id: 'inv_1', docNumber: 'F1-0001');

  setUp(() {
    mockInvoicesRepository = MockInvoicesRepository();
    mockSettingsRepository = MockSettingsRepository();
    useCase = CreateProvisionalInvoice(
      mockInvoicesRepository,
      mockSettingsRepository,
    );
  });

  group('CreateProvisionalInvoice', () {
    test(
      'should include dueDate one month after invoice date when create succeeds',
      () async {
        // arrange
        when(
          () => mockSettingsRepository.getInvoiceSeries(),
        ).thenAnswer((_) async => const Right('F1'));
        when(
          () => mockInvoicesRepository.createInvoice(any()),
        ).thenAnswer((_) async => const Right(tCreatedInvoice));

        // act
        final result = await useCase(tInvoicePreview);

        // assert
        expect(result, const Right(tCreatedInvoice));
        final captured =
            verify(
                  () => mockInvoicesRepository.createInvoice(captureAny()),
                ).captured.single
                as Map<String, dynamic>;
        final content = captured['content'] as Map<String, dynamic>;
        final main = content['main'] as Map<String, dynamic>;
        expect(main['dueDate'], '2026-07-02');
      },
    );

    test(
      'should cap dueDate to last day of next month when invoice date is month end',
      () {
        // act
        final dueDate =
            CreateProvisionalInvoice.calculateDueDateFromInvoiceDate(
              '2026-01-31',
            );

        // assert
        expect(dueDate, '2026-02-28');
      },
    );

    test(
      'should return ConfigNotFoundFailure when invoice series is missing',
      () async {
        // arrange
        when(
          () => mockSettingsRepository.getInvoiceSeries(),
        ).thenAnswer((_) async => const Right(''));

        // act
        final result = await useCase(tInvoicePreview);

        // assert
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<ConfigNotFoundFailure>()),
          (_) => fail('Expected a Left with ConfigNotFoundFailure'),
        );
        verifyNever(() => mockInvoicesRepository.createInvoice(any()));
      },
    );
  });
}
