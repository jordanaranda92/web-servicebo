import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:servicebo/core/error/exceptions.dart';
import 'package:servicebo/features/settings/data/datasources/local/settings_local_data_source.dart';
import 'package:servicebo/features/settings/data/datasources/remote/settings_remote_data_source.dart';
import 'package:servicebo/features/settings/data/repositories/settings_repository_impl.dart';

class MockSettingsLocalDataSource extends Mock
    implements SettingsLocalDataSource {}

class MockSettingsRemoteDataSource extends Mock
    implements SettingsRemoteDataSource {}

void main() {
  late SettingsRepositoryImpl repository;
  late MockSettingsLocalDataSource mockLocal;
  late MockSettingsRemoteDataSource mockRemote;

  setUp(() {
    mockLocal = MockSettingsLocalDataSource();
    mockRemote = MockSettingsRemoteDataSource();
    repository = SettingsRepositoryImpl(mockLocal, mockRemote);
  });

  group('SettingsRepositoryImpl', () {
    group('getPageSize', () {
      test('should return page size from local data source', () {
        when(() => mockLocal.getPageSize()).thenReturn(25);

        final result = repository.getPageSize();

        expect(result, 25);
      });

      test('should throw on CacheException', () {
        when(
          () => mockLocal.getPageSize(),
        ).thenThrow(const CacheException('Error'));

        expect(() => repository.getPageSize(), throwsA(isA<CacheException>()));
      });
    });

    group('savePageSize', () {
      test('should return Right(unit) when save succeeds', () async {
        when(() => mockLocal.savePageSize(any())).thenAnswer((_) async {});

        final result = await repository.savePageSize(25);

        expect(result, const Right(unit));
      });
    });
  });
}
