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

  Stream<QuerySnapshot> getDriverPayments(
    String driverId, {
    String sortField = 'date',
    bool ascending = false,
  }) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('payments')
        .orderBy(sortField, descending: !ascending)
        .snapshots();
  }

  Future<void> saveDriverData(String driverId, Map<String, dynamic> data) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> addPayment(
      String driverId, Map<String, dynamic> paymentData) async {
    final orderNumber = paymentData['order_number'] as String;

    // Check if order number already exists
    final existing = await _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('payments')
        .where('order_number', isEqualTo: orderNumber)
        .get();

    if (existing.docs.isEmpty) {
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('payments')
          .add(paymentData);
    }
  }

  Future<void> saveFieldTemplate(
    String templateName, {
    required List<String> fields,
    required String documentIdField,
    required String promptTemplate,
  }) async {
    await _firestore.collection('templates').doc(templateName).set({
      'fields': fields,
      'documentIdField': documentIdField,
      'promptTemplate': promptTemplate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getAllTemplates() {
    return _firestore.collection('templates').snapshots();
  }

  Future<DocumentSnapshot> getTemplate(String templateName) {
    return _firestore.collection('templates').doc(templateName).get();
  }

  Future<QuerySnapshot> getDriverPaymentsOnce(String driverId) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('payments')
        .get();
  }

  Future<void> deleteDriver(String driverId) {
    return _firestore.collection('drivers').doc(driverId).delete();
  }

  Future<void> deletePayment(String driverId, String paymentId) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('payments')
        .doc(paymentId)
        .delete();
  }

  Future<void> updatePayment(
      String driverId, String paymentId, Map<String, dynamic> data) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('payments')
        .doc(paymentId)
        .update(data);
  }

  Future<void> addMaintenance(
      String driverId, Map<String, dynamic> maintenanceData) async {
    // Add maintenance as a special type of payment
    await _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('payments')
        .add({
      ...maintenanceData,
      'maintenance_fee': maintenanceData['amount'], // Mark as maintenance
      'amount':
          -maintenanceData['amount'], // Negative amount as it's a deduction
    });
  }

  Future<DocumentSnapshot?> getZelleMappings() async {
    return await _firestore.collection('settings').doc('zelle_mappings').get();
  }

  Future<void> saveZelleMappings(Map<String, String> mappings) async {
    await _firestore.collection('settings').doc('zelle_mappings').set(mappings);
  }

  // New methods for merge dictionary
  Future<void> saveMergeMappings(Map<String, String> mappings) async {
    await _firestore.collection('settings').doc('merge_mappings').set(mappings);
  }

  Future<DocumentSnapshot> getMergeMappings() async {
    return await _firestore.collection('settings').doc('merge_mappings').get();
  }

  Future<void> mergeDrivers(
      String sourceDriverId, String targetDriverId) async {
    // Get existing merge mappings
    final mergeDoc = await getMergeMappings();
    Map<String, String> mergeDirectory = Map<String, String>.from(
        mergeDoc?.data() as Map<String, dynamic>? ?? {});

    // Update merge mappings
    mergeDirectory[sourceDriverId] = targetDriverId;
    await saveMergeMappings(mergeDirectory);

    // Get source driver's payments
    final sourcePayments = await getDriverPaymentsOnce(sourceDriverId);

    // Move payments to target driver
    for (var payment in sourcePayments.docs) {
      final paymentData = payment.data() as Map<String, dynamic>;
      await addPayment(targetDriverId, paymentData);
      await deletePayment(sourceDriverId, payment.id);
    }

    // Delete source driver
    await deleteDriver(sourceDriverId);
  }

  // Vehicle Methods
  Stream<QuerySnapshot> getVehicles() {
    return _firestore.collection('vehicles').snapshots();
  }

  Future<void> addVehicle(String vehicleId, Map<String, dynamic> data) {
    return _firestore.collection('vehicles').doc(vehicleId).set(data);
  }

  Future<void> updateVehicle(String vehicleId, Map<String, dynamic> data) {
    return _firestore.collection('vehicles').doc(vehicleId).update(data);
  }

  Future<void> addVehicleCost(
      String vehicleId, String costType, Map<String, dynamic> costData) {
    return _firestore
        .collection('vehicles')
        .doc(vehicleId)
        .collection(costType)
        .add(costData);
  }

  Stream<QuerySnapshot> getVehicleCosts(String vehicleId, String costType) {
    return _firestore
        .collection('vehicles')
        .doc(vehicleId)
        .collection(costType)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> assignDriverToVehicle(String vehicleId, String driverId) {
    return _firestore.collection('vehicles').doc(vehicleId).update({
      'assigned_drivers': FieldValue.arrayUnion([driverId])
    });
  }

  Future<void> removeDriverFromVehicle(String vehicleId, String driverId) {
    return _firestore.collection('vehicles').doc(vehicleId).update({
      'assigned_drivers': FieldValue.arrayRemove([driverId])
    });
  }

  Future<DocumentSnapshot> getDriverById(String driverId) async {
    return await _firestore.collection('drivers').doc(driverId).get();
  }

  Future<String?> getDriverIdByEmail(String email) async {
    final querySnapshot = await _firestore
        .collection('drivers')
        .where('email', isEqualTo: email)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
  }

  Future<void> updateDriverEmail(String driverId, String email) async {
    await _firestore
        .collection('drivers')
        .doc(driverId)
        .update({'email': email});
  }
}
