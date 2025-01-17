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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'AIzaSyB40aTRgWvQzCwqOkH3QQj-RFVbu9UNxUw',
      appId: '1:843850032876:web:e7b99e642d4eec7ba3e7c9',
      messagingSenderId: '843850032876',
      projectId: 'ai-accountant-de349',
      authDomain: 'ai-accountant-de349.firebaseapp.com',
      storageBucket: 'ai-accountant-de349.firebasestorage.app',
    ),
  );
  runApp(DriverManagementApp());
}

class DriverManagementApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driver Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      home: DriverManagementScreen(),
    );
  }
}

class DriverManagementScreen extends StatefulWidget {
  @override
  _DriverManagementScreenState createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: 'AIzaSyCQ8sbo-2fr7GHbR9034d0G2oCTF_r4vh0',
  );
  bool _processing = false;
  String _status = '';

  Future<void> _pickAndProcessMultiplePDFs() async {
    try {
      setState(() {
        _processing = true;
        _status = 'Selecting PDFs...';
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true, // Enable multiple file selection
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'No files selected';
          _processing = false;
        });
        return;
      }

      int processedCount = 0;
      int totalFiles = result.files.length;

      for (PlatformFile file in result.files) {
        setState(() =>
            _status = 'Processing PDF ${processedCount + 1} of $totalFiles...');

        final bytes = file.bytes;
        if (bytes == null) {
          continue;
        }

        try {
          final document = PdfDocument(inputBytes: bytes);
          String pdfText = '';
          for (int i = 0; i < document.pages.count; i++) {
            pdfText +=
                PdfTextExtractor(document).extractText(startPageIndex: i);
          }

          final response = await model
              .generateContent([Content.text(_buildPrompt(pdfText))]);
          String jsonText = _cleanJsonResponse(response.text ?? '');

          final data = json.decode(jsonText);
          if (_validateAndSaveData(data)) {
            processedCount++;
          }
        } catch (e) {
          print('Error processing ${file.name}: $e');
        }
      }

      setState(() {
        _status = 'Completed! Processed $processedCount of $totalFiles files';
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
        _processing = false;
      });
    }
  }

  String _buildPrompt(String pdfText) {
    return """Extract the following information from this invoice and format it exactly as shown in the JSON template below.
      For miles, calculate the approximate distance between pickup and delivery locations.
      
      Template:
      {
        "driver_name": "full name of driver",
        "phone": "phone number if available, otherwise 'N/A'",
        "date": "YYYY-MM-DD",
        "amount": "0.00",
        "miles": "estimated miles between locations",
        "order_number": "Travel order number",
        "company": "company name"
      }

      Invoice text: $pdfText""";
  }

  String _cleanJsonResponse(String jsonText) {
    jsonText = jsonText.replaceAll('```json', '').replaceAll('```', '').trim();
    final startIdx = jsonText.indexOf('{');
    final endIdx = jsonText.lastIndexOf('}') + 1;

    if (startIdx != -1 && endIdx != -1) {
      return jsonText.substring(startIdx, endIdx);
    }
    return '{}';
  }

  bool _validateAndSaveData(Map<String, dynamic> data) {
    final requiredFields = [
      'driver_name',
      'phone',
      'date',
      'amount',
      'miles',
      'order_number',
      'company'
    ];

    if (requiredFields.every((field) => data.containsKey(field))) {
      final driverId =
          data['driver_name'].toString().toLowerCase().replaceAll(' ', '_');

      // Save driver profile
      _firebaseService.saveDriverData(driverId, {
        'name': data['driver_name'],
        'phone': data['phone'],
        'last_updated': FieldValue.serverTimestamp(),
      });

      // Save payment
      _firebaseService.addPayment(driverId, {
        'order_number': data['order_number'],
        'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
        'date': data['date'],
        'miles': data['miles'],
        'company': data['company'],
      });

      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Management'),
      ),
      body: Column(
        children: [
          // PDF Upload Section
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _processing ? null : _pickAndProcessMultiplePDFs,
                  child: Text('Upload PDFs'),
                ),
                if (_processing) CircularProgressIndicator(),
                Text(_status),
              ],
            ),
          ),

          // Driver List Section
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getDrivers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final driver = snapshot.data!.docs[index];
                    return ExpansionTile(
                      title: Text(driver['name']),
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: _firebaseService.getDriverPayments(driver.id),
                          builder: (context, paymentSnapshot) {
                            if (!paymentSnapshot.hasData) {
                              return CircularProgressIndicator();
                            }

                            return Column(
                              children:
                                  paymentSnapshot.data!.docs.map((payment) {
                                final data =
                                    payment.data() as Map<String, dynamic>;
                                return ListTile(
                                  title: Text('Order: ${data['order_number']}'),
                                  subtitle: Text('Date: ${data['date']}'),
                                  trailing: Text('\$${data['amount']}'),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
