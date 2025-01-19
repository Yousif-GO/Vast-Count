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
        brightness: Brightness.light,
        primaryColor: Color(0xFF007BFF), // Your primary color
        hintColor: Color(0xFF6C757D), // Hint text color
        scaffoldBackgroundColor: Color(0xFFF8F9FA), // Background color
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF343A40)), // Default text color
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF007BFF), // Button background color
            foregroundColor: Colors.white, // Button text colori
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: TextStyle(fontSize: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF007BFF), // Your app bar background color
          titleTextStyle: TextStyle(
            color: Colors.white, // Your app bar title text color
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF007BFF)),
            borderRadius: BorderRadius.circular(8),
          ),
          labelStyle: TextStyle(color: Color(0xFF6C757D)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthCheckScreen(),
        '/admin_login': (context) => AdminLoginScreen(),
        '/driver_login': (context) => DriverLoginScreen(),
        '/main': (context) => MainScreen(),
        '/driver_view': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final driverId = args?['driverId'] as String? ?? '';
          // Fetch driver data to get the name
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseService().getDriverById(driverId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text('Driver not found'));
              }
              final driverData = snapshot.data!.data() as Map<String, dynamic>;
              final driverName =
                  driverData['name'] as String? ?? 'Unknown Driver';
              return DriverViewScreen(
                  driverId: driverId, driverName: driverName);
            },
          );
        },
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  int _loginOptionIndex = 0; // Track the selected login option
  final List<String> _loginOptions = ['admin', 'driver'];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          // User is signed in, check if admin or driver
          return FutureBuilder<String?>(
            future: _checkAdminStatus(snapshot.data!.email),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (adminSnapshot.data == 'admin') {
                return MainScreen();
              } else if (adminSnapshot.data == 'driver') {
                return DriverLoginScreen();
              } else {
                return AdminLoginScreen();
              }
            },
          );
        } else {
          // User is not signed in, show login options
          return _buildLoginOptions(context);
        }
      },
    );
  }

  Widget _buildLoginOptions(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Select Login Option',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _loginOptionIndex =
                          (_loginOptionIndex - 1) % _loginOptions.length;
                    });
                  },
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_loginOptions[_loginOptionIndex] == 'admin') {
                      Navigator.pushNamed(context, '/admin_login');
                    } else if (_loginOptions[_loginOptionIndex] == 'driver') {
                      Navigator.pushNamed(context, '/driver_login');
                    }
                  },
                  child: Text(
                      '${_loginOptions[_loginOptionIndex][0].toUpperCase()}${_loginOptions[_loginOptionIndex].substring(1)} Login'),
                ),
                SizedBox(width: 20),
                IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: () {
                    setState(() {
                      _loginOptionIndex =
                          (_loginOptionIndex + 1) % _loginOptions.length;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _checkAdminStatus(String? email) async {
    if (email == null) return null;
    // Check if the email is in the admin list
    final adminEmails = [
      'vast.expand@gmail.com'
    ]; // Replace with your admin emails
    if (adminEmails.contains(email)) {
      return 'admin';
    }
    // Check if the email is in the driver list
    final driverId = await FirebaseService().getDriverIdByEmail(email);
    if (driverId != null) {
      return 'driver';
    }
    return null;
  }
}

class DriverAuthScreen extends StatelessWidget {
  final String driverId;
  final String adminEmail;

  DriverAuthScreen({required this.driverId, required this.adminEmail});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseService().getDriverById(driverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Driver not found'));
        }
        final driverData = snapshot.data!.data() as Map<String, dynamic>;
        final driverName = driverData['name'] as String? ?? 'Unknown Driver';

        return _buildAuthScreen(context, driverId, driverName);
      },
    );
  }

  Widget _buildAuthScreen(
      BuildContext context, String driverId, String driverName) {
    final TextEditingController _emailController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(title: Text('Driver Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Enter Admin Email to view driver details',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Admin Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (value != adminEmail) {
                    return 'Incorrect email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverViewScreen(
                          driverId: driverId,
                          driverName: driverName,
                        ),
                      ),
                    );
                  }
                },
                child: Text('View Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  final model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: 'AIzaSyCQ8sbo-2fr7GHbR9034d0G2oCTF_r4vh0',
  );
  bool _processing = false;
  String _status = '';
  String _sortField = 'date';
  bool _sortAscending = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Screen'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Drivers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Vehicles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Profit & Loss',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        unselectedLabelStyle: TextStyle(color: Colors.grey),
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return DriverManagementScreen(
          firebaseService: _firebaseService,
          model: model,
          processing: _processing,
          status: _status,
          sortField: _sortField,
          sortAscending: _sortAscending,
          setProcessing: (bool value) => setState(() => _processing = value),
          setStatus: (String value) => setState(() => _status = value),
          setSortField: (String value) => setState(() => _sortField = value),
          setSortAscending: (bool value) =>
              setState(() => _sortAscending = value),
        );
      case 1:
        return VehicleManagementScreen();
      case 2:
        return ProfitLossScreen();
      default:
        return Container();
    }
  }
}

class DriverManagementScreen extends StatefulWidget {
  final FirebaseService firebaseService;
  final GenerativeModel model;
  final bool processing;
  final String status;
  final String sortField;
  final bool sortAscending;
  final Function(bool) setProcessing;
  final Function(String) setStatus;
  final Function(String) setSortField;
  final Function(bool) setSortAscending;

  DriverManagementScreen({
    required this.firebaseService,
    required this.model,
    required this.processing,
    required this.status,
    required this.sortField,
    required this.sortAscending,
    required this.setProcessing,
    required this.setStatus,
    required this.setSortField,
    required this.setSortAscending,
  });

  @override
  _DriverManagementScreenState createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  String _sortField = 'date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _sortField = widget.sortField;
    _sortAscending = widget.sortAscending;
  }

  @override
  void didUpdateWidget(covariant DriverManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sortField != oldWidget.sortField ||
        widget.sortAscending != oldWidget.sortAscending) {
      setState(() {
        _sortField = widget.sortField;
        _sortAscending = widget.sortAscending;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Management'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort),
            onSelected: (String field) {
              widget.setSortField(field);
              widget.setSortAscending(
                  _sortField == field ? !_sortAscending : true);
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(_sortField == 'date'
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : null),
                    SizedBox(width: 8),
                    Text('Sort by Date'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(_sortField == 'amount'
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : null),
                    SizedBox(width: 8),
                    Text('Sort by Amount'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'order_number',
                child: Row(
                  children: [
                    Icon(_sortField == 'order_number'
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : null),
                    SizedBox(width: 8),
                    Text('Sort by Order Number'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // PDF Upload Section
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: widget.processing
                          ? null
                          : _pickAndProcessMultiplePDFs,
                      child: Text('Upload PDFs'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed:
                          widget.processing ? null : _processZellePayments,
                      child: Text('Upload Zelle Statement'),
                    ),
                  ],
                ),
                if (widget.processing) CircularProgressIndicator(),
                Text(widget.status),
              ],
            ),
          ),

          // Driver List Section
          Expanded(
            child: _buildDriverList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverList() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.firebaseService.getDrivers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final drivers = snapshot.data!.docs;

        return ListView.builder(
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driverDoc = drivers[index];
            final driverData = driverDoc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(driverData['name'] ?? 'Unknown Driver'),
              subtitle: Text(driverDoc.id),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.visibility),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DriverViewScreen(
                            driverId: driverDoc.id,
                            driverName: driverData['name'] ?? 'Unknown Driver',
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.merge_type),
                    onPressed: () =>
                        _showMergeDialog(driverDoc.id, driverData['name']),
                  ),
                  IconButton(
                    icon: Icon(Icons.build),
                    onPressed: () => _showMaintenanceDialog(
                        driverDoc.id, driverData['name']),
                  ),
                  IconButton(
                    icon: Icon(Icons.email),
                    onPressed: () => _showAssignEmailDialog(
                        driverDoc.id, driverData['name']),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndProcessMultiplePDFs() async {
    try {
      widget.setProcessing(true);
      widget.setStatus('Selecting PDFs...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        widget.setStatus('No files selected');
        widget.setProcessing(false);
        return;
      }

      int processedCount = 0;
      int totalFiles = result.files.length;

      for (PlatformFile file in result.files) {
        widget.setStatus(
            'Processing PDF ${processedCount + 1} of $totalFiles...');

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

          final response = await widget.model
              .generateContent([Content.text(_buildPrompt(pdfText))]);
          String jsonText = _cleanJsonResponse(response.text ?? '');

          final data = json.decode(jsonText);
          if (_validateAndSaveData(data, file.name, bytes)) {
            processedCount++;
          }
        } catch (e) {
          print('Error processing ${file.name}: $e');
        }
      }

      widget.setStatus('Processing complete. Starting cleanup...');
      await _cleanupDuplicates();

      widget.setStatus(
          'Completed! Processed $processedCount of $totalFiles files');
      widget.setProcessing(false);
    } catch (e) {
      widget.setStatus('Error: ${e.toString()}');
      widget.setProcessing(false);
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

  bool _validateAndSaveData(
      Map<String, dynamic> data, String fileName, Uint8List fileBytes) {
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
      widget.firebaseService.saveDriverData(driverId, {
        'name': data['driver_name'],
        'phone': data['phone'],
        'last_updated': FieldValue.serverTimestamp(),
      });

      // Save payment
      widget.firebaseService.addPayment(driverId, {
        'order_number': data['order_number'],
        'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
        'date': data['date'],
        'miles': data['miles'],
        'company': data['company'],
        'insurance_fee': 0.0,
      });
      _uploadPdfToStorage(fileBytes, fileName, driverId);
      _cleanupDuplicates();
      return true;
    }
    return false;
  }

  Future<void> _uploadPdfToStorage(
      Uint8List fileBytes, String fileName, String driverId) async {
    try {
      final storageRef =
          FirebaseStorage.instance.ref().child('pdfs/$driverId/$fileName');
      final uploadTask = storageRef.putData(fileBytes);
      await uploadTask.whenComplete(() => print('PDF uploaded to storage'));
      // Check for duplicates in storage
      await _checkForDuplicatePdfs(fileName, driverId);
    } catch (e) {
      print('Error uploading PDF to storage: $e');
    }
  }

  Future<void> _checkForDuplicatePdfs(String fileName, String driverId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('pdfs/$driverId');
      final listResult = await storageRef.listAll();
      if (listResult.items.length > 1) {
        // Check if there are other files with the same name
        final duplicateFiles =
            listResult.items.where((item) => item.name == fileName).toList();
        if (duplicateFiles.length > 1) {
          // Delete all but the most recent file
          duplicateFiles.sort((a, b) => a.name.compareTo(b.name));
          for (int i = 0; i < duplicateFiles.length - 1; i++) {
            await duplicateFiles[i].delete();
            print('Deleted duplicate PDF: ${duplicateFiles[i].name}');
          }
        }
      }
    } catch (e) {
      print('Error checking for duplicate PDFs: $e');
    }
  }

  Future<void> _mergeDrivers(String sourceId, String targetId) async {
    try {
      final sourcePayments =
          await widget.firebaseService.getDriverPaymentsOnce(sourceId);
      final targetPayments =
          await widget.firebaseService.getDriverPaymentsOnce(targetId);

      final targetOrderNumbers = targetPayments.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['order_number']?.toString() ?? '';
          })
          .where((orderNumber) => orderNumber.isNotEmpty)
          .toSet();

      for (var payment in sourcePayments.docs) {
        final data = payment.data() as Map<String, dynamic>;
        final orderNumber = data['order_number']?.toString() ?? '';

        if (orderNumber.isNotEmpty &&
            !targetOrderNumbers.contains(orderNumber)) {
          await widget.firebaseService.addPayment(targetId, data);
        }
      }

      await widget.firebaseService.deleteDriver(sourceId);
      widget.setStatus('Drivers merged successfully');
      await _cleanupDuplicates();
    } catch (e) {
      widget.setStatus('Error merging drivers: $e');
    }
  }

  Future<void> _showMergeDialog(
      String sourceDriverId, String sourceDriverName) async {
    await showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: widget.firebaseService.getDrivers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final drivers = snapshot.data!.docs;

          return AlertDialog(
            title: Text('Merge Driver: $sourceDriverName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Driver to merge with:'),
                  ...drivers
                      .where((driver) => driver.id != sourceDriverId)
                      .map((driver) {
                    final data = driver.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name'] as String? ?? 'Unknown Driver'),
                      onTap: () async {
                        final targetDriverId = driver.id;
                        await widget.firebaseService
                            .mergeDrivers(sourceDriverId, targetDriverId);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cleanupDuplicates() async {
    try {
      widget.setStatus('Cleaning up duplicates...');

      // Get all drivers
      final drivers = await widget.firebaseService.getDrivers().first;

      for (var driver in drivers.docs) {
        final driverId = driver.id;
        final payments =
            await widget.firebaseService.getDriverPaymentsOnce(driverId);

        // Track processed order numbers
        Set<String> processedOrders = {};

        // Track insurance weeks
        Set<int> insuranceWeeks = {};

        // Sort payments by date
        final sortedPayments = payments.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            return (aData['date'] ?? '')
                .toString()
                .compareTo((bData['date'] ?? '').toString());
          });

        for (var payment in sortedPayments) {
          final data = payment.data() as Map<String, dynamic>;
          final date = DateTime.tryParse(data['date']?.toString() ?? '');
          final orderNumber = data['order_number']?.toString() ?? '';

          if (date != null) {
            final weekNumber =
                (date.difference(DateTime(date.year, 1, 1)).inDays / 7).ceil();

            // Delete duplicate order numbers (keep first occurrence)
            if (orderNumber.isNotEmpty) {
              if (processedOrders.contains(orderNumber)) {
                await widget.firebaseService
                    .deletePayment(driverId, payment.id);
              } else {
                processedOrders.add(orderNumber);
              }
            }

            // Handle insurance deduction
            if (!insuranceWeeks.contains(weekNumber)) {
              final amount = data['amount'] as num? ?? 0.0;
              final insuranceFee = 150.0; // Set your insurance fee here
              await widget.firebaseService.updatePayment(driverId, payment.id, {
                'amount': amount - insuranceFee,
                'insurance_fee': insuranceFee,
              });
              insuranceWeeks.add(weekNumber);
            }
          }
        }
      }

      widget.setStatus('Cleanup completed');
    } catch (e) {
      widget.setStatus('Cleanup error: $e');
    }
  }

  void _showMaintenanceDialog(String driverId, String driverName) {
    final maintenanceController = TextEditingController();
    final dateController = TextEditingController(
        text: DateTime.now().toIso8601String().split('T')[0]);
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Maintenance Fee - $driverName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: maintenanceController,
              decoration: InputDecoration(
                labelText: 'Maintenance Amount (\$)',
                hintText: 'Enter amount',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            TextField(
              controller: dateController,
              decoration: InputDecoration(
                labelText: 'Date',
                hintText: 'YYYY-MM-DD',
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  dateController.text = date.toIso8601String().split('T')[0];
                }
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: 'Comment',
                hintText: 'Enter maintenance details',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(maintenanceController.text);
              if (amount != null && amount > 0) {
                await widget.firebaseService.addMaintenance(driverId, {
                  'amount': amount,
                  'date': dateController.text,
                  'type': 'maintenance_fee',
                  'comment': commentController.text.trim(),
                  'order_number':
                      'MAINT-${DateTime.now().millisecondsSinceEpoch}',
                });
                Navigator.pop(context);
                widget.setStatus('Maintenance fee added');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _processZellePayments() async {
    try {
      widget.setProcessing(true);
      widget.setStatus('Selecting Zelle statement...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        widget.setStatus('No file selected');
        widget.setProcessing(false);
        return;
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        widget.setStatus('Invalid file');
        widget.setProcessing(false);
        return;
      }

      widget.setStatus('Reading statement...');
      final content = String.fromCharCodes(bytes);

      widget.setStatus('Processing with AI...');
      final response = await widget.model.generateContent([
        Content.text('''
          Extract Zelle payments from this statement and format as JSON:
          {
            "payments": [
              {
                "recipient": "recipient name",
                "amount": "amount as number",
                "date": "YYYY-MM-DD",
                "note": "payment note if available"
              }
            ]
          }
          
          Statement text:
          $content
        ''')
      ]);

      widget.setStatus('Parsing results...');
      final jsonText = _cleanJsonResponse(response.text ?? '');
      final data = json.decode(jsonText) as Map<String, dynamic>;

      if (!data.containsKey('payments') || (data['payments'] as List).isEmpty) {
        widget.setStatus('No payments found in statement');
        widget.setProcessing(false);
        return;
      }

      widget.setStatus('Loading existing mappings...');
      final zelleDoc = await widget.firebaseService.getZelleMappings();
      Map<String, String> zelleDirectory = Map<String, String>.from(
          zelleDoc?.data() as Map<String, dynamic>? ?? {});

      // Group payments by recipient
      widget.setStatus('Processing payments...');
      Map<String, List<Map<String, dynamic>>> paymentsByRecipient = {};
      for (var payment in data['payments'] as List) {
        final paymentMap = payment as Map<String, dynamic>;
        final recipient =
            paymentMap['recipient']?.toString().toLowerCase() ?? '';
        if (recipient.isNotEmpty) {
          paymentsByRecipient.putIfAbsent(recipient, () => []).add(paymentMap);
        }
      }

      int processedCount = 0;
      // Show recipient matching dialog
      for (var recipient in paymentsByRecipient.keys) {
        widget.setStatus('Processing recipient: $recipient');
        if (zelleDirectory.containsKey(recipient)) {
          // Use existing mapping
          final driverId = zelleDirectory[recipient]!;
          await _addZellePaymentsToDriver(
              driverId, paymentsByRecipient[recipient]!);
          processedCount += paymentsByRecipient[recipient]!.length;
        } else {
          // Show mapping dialog
          await _showZelleMatchingDialog(
              recipient, paymentsByRecipient[recipient]!, zelleDirectory);
          processedCount += paymentsByRecipient[recipient]!.length;
        }
      }

      widget.setStatus('Saving mappings...');
      await widget.firebaseService.saveZelleMappings(zelleDirectory);

      widget.setStatus('Completed! Processed $processedCount payments');
      widget.setProcessing(false);
    } catch (e, stackTrace) {
      print('Error processing Zelle payments: $e\n$stackTrace');
      widget.setStatus('Error: ${e.toString()}');
      widget.setProcessing(false);
    }
  }

  Future<void> _showZelleMatchingDialog(
      String recipient,
      List<Map<String, dynamic>> payments,
      Map<String, String> zelleDirectory) async {
    await showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: widget.firebaseService.getDrivers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final drivers = snapshot.data!.docs;
          final total = payments.fold(
              0.0,
              (sum, payment) =>
                  sum + (double.tryParse(payment['amount'].toString()) ?? 0.0));

          return AlertDialog(
            title: Text('Match Zelle Recipient'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recipient: $recipient'),
                  Text('Total Amount: \$${total.toStringAsFixed(2)}'),
                  Text('Payments:'),
                  ...payments
                      .map((p) => Text('  \$${p['amount']} on ${p['date']}')),
                  Divider(),
                  Text('Select Driver:'),
                  ...drivers.map((driver) {
                    final data = driver.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name'] as String? ?? 'Unknown Driver'),
                      onTap: () async {
                        zelleDirectory[recipient] = driver.id;
                        await _addZellePaymentsToDriver(driver.id, payments);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Skip'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addZellePaymentsToDriver(
      String driverId, List<Map<String, dynamic>> payments) async {
    // Get existing payments for the driver
    final existingPayments =
        await widget.firebaseService.getDriverPaymentsOnce(driverId);

    for (var payment in payments) {
      try {
        final amount =
            double.tryParse(payment['amount']?.toString() ?? '0') ?? 0.0;
        final date = payment['date']?.toString() ?? '';
        final note = payment['note']?.toString() ?? '';

        // Check if a payment with the same amount and date already exists
        final paymentExists = existingPayments.docs.any((doc) {
          final existingData = doc.data() as Map<String, dynamic>;
          return (existingData['amount'] as num? ?? 0.0) == amount &&
              (existingData['date']?.toString() ?? '') == date;
        });

        if (!paymentExists) {
          await widget.firebaseService.addPayment(driverId, {
            'amount': amount,
            'date': date,
            'type': 'zelle_payment',
            'note': note,
            'order_number': 'ZELLE-${DateTime.now().millisecondsSinceEpoch}',
          });
        }
      } catch (e) {
        print('Error adding Zelle payment: $e');
      }
    }
  }

  Future<void> _showAssignEmailDialog(
      String driverId, String driverName) async {
    final _emailController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Email to: $driverName'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            decoration: InputDecoration(labelText: 'Driver Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an email';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await widget.firebaseService
                    .updateDriverEmail(driverId, _emailController.text.trim());
                Navigator.pop(context);
                widget.setStatus('Driver email updated');
              }
            },
            child: Text('Assign'),
          ),
        ],
      ),
    );
  }
}
