import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/data/datasources/factura_directa_api_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/fd_contact_data.dart';

class GetClientFdData extends UseCase<FdContactData, String> {
  final FacturaDirectaApiDataSource _fdApi;

  GetClientFdData(this._fdApi);

  /// [params] is the FacturaDirecta contact UUID.
  @override
  Future<Either<Failure, FdContactData>> call(String params) async {
    dev.log(
      '[GetClientFdData] fetching FD data for uuid=$params',
      name: 'Clients',
    );

    try {
      final json = await _fdApi.getContactById(
        params,
        queryParameters: {'related': 'receivePaymentMethod'},
      );

      final content = json['content'] as Map<String, dynamic>?;
      final main = content?['main'] as Map<String, dynamic>? ?? {};
      final uuid = content?['uuid'] as String? ?? params;
      final name = (main['name'] as String?) ?? '';

      final countryCode = main['country'] as String?;
      final regionCode = main['region'] as String?;

      // Resolve receivePaymentMethod UUID → human-readable title
      final paymentMethodId = main['receivePaymentMethod'] as String?;
      String? paymentMethodTitle;
      if (paymentMethodId != null) {
        final related = json['related'] as Map<String, dynamic>?;
        final objects = related?['objects'] as Map<String, dynamic>?;
        final pamObj = objects?[paymentMethodId] as Map<String, dynamic>?;
        final pamMain = pamObj?['main'] as Map<String, dynamic>?;
        paymentMethodTitle = pamMain?['title'] as String?;
      }

      return Right(
        FdContactData(
          uuid: uuid,
          name: name,
          fiscalId: main['fiscalId'] as String?,
          email: main['email'] as String?,
          phone: main['phone'] as String?,
          city: main['city'] as String?,
          province: _provinceName(regionCode),
          country: _countryName(countryCode),
          paymentMethod: paymentMethodTitle,
          currency: main['currency'] as String?,
        ),
      );
    } on ServerException catch (e) {
      dev.log(
        '[GetClientFdData] ServerException: ${e.message}',
        name: 'Clients',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } catch (e, st) {
      dev.log(
        '[GetClientFdData] unexpected error: $e',
        name: 'Clients',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  static String? _provinceName(String? code) {
    if (code == null || code.isEmpty) return null;
    return _provinceCodes[code] ?? code;
  }

  static const _provinceCodes = <String, String>{
    '01': 'Álava',
    '02': 'Albacete',
    '03': 'Alicante',
    '04': 'Almería',
    '05': 'Ávila',
    '06': 'Badajoz',
    '07': 'Baleares',
    '08': 'Barcelona',
    '09': 'Burgos',
    '10': 'Cáceres',
    '11': 'Cádiz',
    '12': 'Castellón',
    '13': 'Ciudad Real',
    '14': 'Córdoba',
    '15': 'A Coruña',
    '16': 'Cuenca',
    '17': 'Girona',
    '18': 'Granada',
    '19': 'Guadalajara',
    '20': 'Guipúzcoa',
    '21': 'Huelva',
    '22': 'Huesca',
    '23': 'Jaén',
    '24': 'León',
    '25': 'Lleida',
    '26': 'La Rioja',
    '27': 'Lugo',
    '28': 'Madrid',
    '29': 'Málaga',
    '30': 'Murcia',
    '31': 'Navarra',
    '32': 'Ourense',
    '33': 'Asturias',
    '34': 'Palencia',
    '35': 'Las Palmas',
    '36': 'Pontevedra',
    '37': 'Salamanca',
    '38': 'Santa Cruz de Tenerife',
    '39': 'Cantabria',
    '40': 'Segovia',
    '41': 'Sevilla',
    '42': 'Soria',
    '43': 'Tarragona',
    '44': 'Teruel',
    '45': 'Toledo',
    '46': 'Valencia',
    '47': 'Valladolid',
    '48': 'Vizcaya',
    '49': 'Zamora',
    '50': 'Zaragoza',
    '51': 'Ceuta',
    '52': 'Melilla',
  };

  static String? _countryName(String? code) {
    if (code == null || code.isEmpty) return null;
    return _countryCodes[code.toUpperCase()] ?? code;
  }

  static const _countryCodes = <String, String>{
    'ES': 'España',
    'PT': 'Portugal',
    'FR': 'Francia',
    'DE': 'Alemania',
    'IT': 'Italia',
    'GB': 'Reino Unido',
    'US': 'Estados Unidos',
    'MX': 'México',
    'AR': 'Argentina',
    'CO': 'Colombia',
    'CL': 'Chile',
    'PE': 'Perú',
    'BR': 'Brasil',
    'NL': 'Países Bajos',
    'BE': 'Bélgica',
    'AT': 'Austria',
    'CH': 'Suiza',
    'IE': 'Irlanda',
    'PL': 'Polonia',
    'SE': 'Suecia',
    'NO': 'Noruega',
    'DK': 'Dinamarca',
    'FI': 'Finlandia',
    'GR': 'Grecia',
    'RO': 'Rumanía',
    'CZ': 'República Checa',
    'HU': 'Hungría',
    'HR': 'Croacia',
    'BG': 'Bulgaria',
    'SK': 'Eslovaquia',
    'SI': 'Eslovenia',
    'LT': 'Lituania',
    'LV': 'Letonia',
    'EE': 'Estonia',
    'CY': 'Chipre',
    'MT': 'Malta',
    'LU': 'Luxemburgo',
    'AD': 'Andorra',
    'MA': 'Marruecos',
  };
}
