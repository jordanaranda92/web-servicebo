import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/error/exceptions.dart';
import 'settings_remote_data_source.dart';

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  SettingsRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  static const _collection = 'factura_directa_configuration';
  static const _docId = 'default';
  static const _fieldInvoiceSeries = 'invoiceSeries';

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.collection(_collection).doc(_docId);

  @override
  Future<String?> getInvoiceSeries() async {
    try {
      final doc = await _docRef.get();
      if (!doc.exists || doc.data() == null) return null;
      return doc.data()![_fieldInvoiceSeries] as String?;
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading invoice series: $e');
    }
  }

  @override
  Future<void> saveInvoiceSeries(String series) async {
    try {
      await _docRef.set({_fieldInvoiceSeries: series}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error saving invoice series: $e');
    }
  }
}
