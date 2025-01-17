// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> loadTemplates() async {
    final snapshot = await _firestore.collection('templates').get();
    return Map.fromEntries(
      snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
    );
  }

  Future<void> saveTemplate(String name, Map<String, dynamic> template) async {
    await _firestore.collection('templates').doc(name).set(template);
  }

  Future<void> saveDocumentData(
      String templateName, Map<String, dynamic> data) async {
    final template =
        await _firestore.collection('templates').doc(templateName).get();
    final structure = template.data()!;

    // Create main document
    final mainCollectionName = structure['name'];
    final mainDocRef = _firestore.collection(mainCollectionName).doc();

    // Separate main fields and subcollections
    Map<String, dynamic> mainFields = {};
    Map<String, dynamic> subcollections = {};

    structure['fields'].forEach((field) {
      if (field['isSubcollection']) {
        subcollections[field['name']] = field['fields'];
      } else {
        mainFields[field['name']] = data[field['name']];
      }
    });

    // Save main document
    await mainDocRef.set(mainFields);

    // Save subcollections
    for (var sub in subcollections.entries) {
      if (data[sub.key] != null) {
        await mainDocRef.collection(sub.key).add(data[sub.key]);
      }
    }
  }

  Stream<QuerySnapshot> getCollectionDocuments(
      String templateName, String collectionPath) {
    return _firestore.collection(collectionPath).snapshots();
  }

  Stream<QuerySnapshot> getTemplateDocuments(String templateName) {
    return _firestore
        .collection('templates')
        .doc(templateName)
        .collection('documents')
        .snapshots();
  }

  Future<Map<String, dynamic>> loadTemplate(String templateName) async {
    final doc =
        await _firestore.collection('templates').doc(templateName).get();
    return doc.data() ?? {};
  }

  Stream<QuerySnapshot> getDrivers() {
    return _firestore.collection('drivers').orderBy('name').snapshots();
  }

  Stream<QuerySnapshot> getDriverPayments(String driverId) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('payments')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> saveDriverData(String driverId, Map<String, dynamic> data) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> addPayment(String driverId, Map<String, dynamic> paymentData) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('payments')
        .add(paymentData);
  }
}
