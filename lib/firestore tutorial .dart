// lib/main.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firebase_service.dart';
import 'screens/vehicle_management_screen.dart';
import 'screens/profit_loss_screen.dart';
import 'screens/driver_view_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/admin_login_screen.dart';
import 'screens/driver_login_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'firebase_options.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Get an instance of Firestore
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Try to add a document to FirestoreR
  try {
    // Add a document to the 'my_collection' collection with a specific document ID
    await firestore.collection('my_collection').doc('my_document_id').set({
      // Document data:
      'field1': 'value1', // String field
      'field2': 123, // Integer field
      'field3': true, // Boolean field
      'field4': DateTime.now(), // Timestamp field
    });

    // Add a document to a subcollection inside the document
    await firestore
        .collection('my_collection')
        .doc('my_document_id')
        .collection('my_subcollection')
        .add({
      'subfield1': 'subvalue1',
      'subfield2': 456,
    });

    // Print success message
    print('Document and subcollection document added successfully!');
  } catch (e) {
    // Print error message if adding document fails
    print('Error adding document: $e');
  }

  try {
    // Get a specific document from the 'my_collection' collection
    DocumentSnapshot documentSnapshot =
        await firestore.collection('my_collection').doc('my_document_id').get();

    if (documentSnapshot.exists) {
      print('Document ID: ${documentSnapshot.id}');
      print('Document Data: ${documentSnapshot.data()}');
    } else {
      print('Document does not exist');
    }
  } catch (e) {
    print('Error fetching document: $e');
  }

  try {
    // Get all documents from the 'my_collection' collection
    QuerySnapshot querySnapshot =
        await firestore.collection('my_collection').get();

    // Iterate through the documents
    for (var doc in querySnapshot.docs) {
      print('Document ID: ${doc.id}');
      print('Document Data: ${doc.data()}');
    }
  } catch (e) {
    print('Error fetching documents: $e');
  }

  try {
    // Get all documents from the 'my_subcollection' subcollection
    QuerySnapshot querySnapshot = await firestore
        .collection('my_collection')
        .doc('my_document_id')
        .collection('my_subcollection')
        .get();

    // Iterate through the documents
    for (var doc in querySnapshot.docs) {
      print('Subcollection Document ID: ${doc.id}');
      print('Subcollection Document Data: ${doc.data()}');
    }
  } catch (e) {
    print('Error fetching subcollection documents: $e');
  }
  try {
    // Get a specific document from the 'my_collection' collection
    DocumentSnapshot documentSnapshot =
        await firestore.collection('my_collection').doc('my_document_id').get();

    if (documentSnapshot.exists) {
      // Access specific fields
      String field1Value = documentSnapshot.get('field1');
      int field2Value = documentSnapshot.get('field2');
      bool field3Value = documentSnapshot.get('field3');
      DateTime field4Value = documentSnapshot.get('field4');

      print('Field 1: $field1Value');
      print('Field 2: $field2Value');
      print('Field 3: $field3Value');
      print('Field 4: $field4Value');

      // Access fields using the data() method
      Map<String, dynamic>? data =
          documentSnapshot.data() as Map<String, dynamic>?;
      if (data != null) {
        String field1ValueData = data['field1'];
        int field2ValueData = data['field2'];
        bool field3ValueData = data['field3'];
        DateTime field4ValueData = data['field4'];

        print('Field 1 (from data()): $field1ValueData');
        print('Field 2 (from data()): $field2ValueData');
        print('Field 3 (from data()): $field3ValueData');
        print('Field 4 (from data()): $field4ValueData');
      }
    } else {
      print('Document does not exist');
    }
  } catch (e) {
    print('Error fetching document: $e');
  }

  try {
    // Get documents where 'field2' is greater than 100
    QuerySnapshot querySnapshot = await firestore
        .collection('my_collection')
        .where('field2', isGreaterThan: 100)
        .get();

    for (var doc in querySnapshot.docs) {
      print('Document ID: ${doc.id}, Data: ${doc.data()}');
    }
  } catch (e) {
    print('Error fetching documents: $e');
  }

  try {
    // Get documents where 'field1' is equal to 'value1'
    QuerySnapshot querySnapshot = await firestore
        .collection('my_collection')
        .where('field1', isEqualTo: 'value1')
        .get();

    for (var doc in querySnapshot.docs) {
      print('Document ID: ${doc.id}, Data: ${doc.data()}');
    }
  } catch (e) {
    print('Error fetching documents: $e');
  }

  try {
    // Get documents sorted by 'field2' in ascending order
    QuerySnapshot querySnapshot =
        await firestore.collection('my_collection').orderBy('field2').get();

    for (var doc in querySnapshot.docs) {
      print('Document ID: ${doc.id}, Data: ${doc.data()}');
    }
  } catch (e) {
    print('Error fetching documents: $e');
  }

  try {
    // Get documents sorted by 'field4' in descending order
    QuerySnapshot querySnapshot = await firestore
        .collection('my_collection')
        .orderBy('field4', descending: true)
        .get();

    for (var doc in querySnapshot.docs) {
      print('Document ID: ${doc.id}, Data: ${doc.data()}');
    }
  } catch (e) {
    print('Error fetching documents: $e');
  }
}
