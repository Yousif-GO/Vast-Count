// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'package:image/image.dart' as img;
import 'firebase_options.dart';
import 'ui/dynamic_field_adder_ui.dart';
import 'services/dynamic_field_adder_service.dart'; // Import the service file
import 'package:flutter/services.dart' show rootBundle; // Import rootBundle
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart' as pdf;
import 'package:syncfusion_flutter_pdf/pdf.dart'
    as syncfusion_pdf; // Import with alias
import 'pdf_or_image_processor_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'view_documents_page.dart'; // Import the new page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class Config {
  String apiKey = '';
  String modelName = '';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  // Hardcoded API key and model name
  String _geminiApiKey = 'AIzaSyCQ8sbo-2fr7GHbR9034d0G2oCTF_r4vh0';
  String _geminiModel = 'gemini-1.5-flash';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    // No need to load API key here
  }

  Future<void> _checkLoginStatus() async {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _isLoggedIn = user != null;
      });
    });
  }

  Future<bool> _isEmailVerified() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      return user.emailVerified;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.light,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey[700],
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[700],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: TextStyle(fontSize: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue),
          ),
          labelStyle: TextStyle(color: Colors.grey[600]),
          floatingLabelStyle: TextStyle(color: Colors.blue),
        ),
        iconTheme: IconThemeData(color: Colors.blueGrey[700]),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey[900],
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: TextStyle(fontSize: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue),
          ),
          labelStyle: TextStyle(color: Colors.grey[400]),
          floatingLabelStyle: TextStyle(color: Colors.blue),
        ),
        iconTheme: IconThemeData(color: Colors.blueGrey[900]),
      ),
      themeMode: ThemeMode.system,
      home: _isLoggedIn
          ? FutureBuilder<bool>(
              future: _isEmailVerified(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasData && snapshot.data == true) {
                  return HomePage(
                    geminiApiKey: _geminiApiKey,
                    geminiModel: _geminiModel,
                  );
                } else {
                  return EmailVerificationPage();
                }
              },
            )
          : LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';

  Future<void> _signInWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'An error occurred';
        });
      }
    }
  }

  Future<void> _signUpWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'An error occurred';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.blueGrey[700],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _signInWithEmailAndPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text('Login'),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signUpWithEmailAndPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text('Sign Up'),
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String geminiApiKey;
  final String geminiModel;

  HomePage({
    required this.geminiApiKey,
    required this.geminiModel,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _geminiOutput = '';
  String _selectedTemplate = '';
  List<Map<String, dynamic>> _templates = [];
  late DynamicFieldAdderService _service;

  @override
  void initState() {
    super.initState();
    _service = DynamicFieldAdderService(
      formKey: GlobalKey<FormState>(),
      collectionNameController: TextEditingController(),
      documentNameController: null,
      fieldNameControllers: [],
      fieldValueControllers: [],
      templates: _templates,
      templateNameController: TextEditingController(),
      setState: setState,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    await _service.loadTemplates();
    setState(() {
      _templates = _service.templates;
    });
  }

  void _processImage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PdfOrImageProcessorPage()),
    );
  }

  void _viewDocuments(String templateName) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ViewDocumentsPage(
                templateName: templateName,
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Accountant'),
        backgroundColor: Colors.blueGrey[700], // AppBar background color
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => DynamicFieldAdder(
                              geminiApiKey: widget.geminiApiKey,
                              geminiModel: widget.geminiModel,
                            )),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Button color
                  foregroundColor: Colors.white, // Text color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12), // Padding
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('Add Template'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _processImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Button color
                  foregroundColor: Colors.white, // Text color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12), // Padding
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image),
                    SizedBox(width: 8),
                    Text('Process Image or PDF'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              DropdownButton<String>(
                value: _selectedTemplate.isEmpty ? null : _selectedTemplate,
                hint: Text('Select a template to view documents'),
                items: _templates.map((template) {
                  return DropdownMenuItem<String>(
                    value: template['name'],
                    child: Text(template['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTemplate = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              if (_selectedTemplate.isNotEmpty)
                ElevatedButton(
                  onPressed: () => _viewDocuments(_selectedTemplate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, // Button color
                    foregroundColor: Colors.white, // Text color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12), // Padding
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility),
                      SizedBox(width: 8),
                      Text('View Documents'),
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}

class DynamicFieldAdder extends StatefulWidget {
  final String geminiApiKey;
  final String geminiModel;

  DynamicFieldAdder({
    required this.geminiApiKey,
    required this.geminiModel,
  });

  @override
  _DynamicFieldAdderState createState() => _DynamicFieldAdderState();
}

class _DynamicFieldAdderState extends State<DynamicFieldAdder> {
  final _formKey = GlobalKey<FormState>();
  final _collectionNameController = TextEditingController();
  final _documentNameController = TextEditingController();
  List<TextEditingController> _fieldNameControllers = [];
  List<TextEditingController> _fieldValueControllers = [];
  List<Map<String, dynamic>> _templates = [];
  final _templateNameController = TextEditingController();
  late DynamicFieldAdderService _service;
  String _geminiOutput = '';

  @override
  void initState() {
    super.initState();
    _service = DynamicFieldAdderService(
      formKey: _formKey,
      collectionNameController: _collectionNameController,
      documentNameController: null,
      fieldNameControllers: _fieldNameControllers,
      fieldValueControllers: _fieldValueControllers,
      templates: _templates,
      templateNameController: _templateNameController,
      setState: setState,
    );
    _service.addField(); // Add initial field
    _service.loadTemplates();
  }

  @override
  void dispose() {
    _collectionNameController.dispose();
    _documentNameController.dispose();
    _templateNameController.dispose();
    for (var controller in _fieldNameControllers) {
      controller.dispose();
    }
    for (var controller in _fieldValueControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: buildDynamicFieldAdderUI(
              context,
              _formKey,
              _collectionNameController,
              _documentNameController,
              _templateNameController,
              _fieldNameControllers,
              _fieldValueControllers,
              _templates,
              _service.addField,
              _service.addDynamicFields,
              _service.saveTemplate,
              _service.applyTemplate,
              () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                );
                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  final fileBytes = file.bytes;
                  if (fileBytes != null) {
                    await _service.generateTemplateFromImage(
                        fileBytes, widget.geminiApiKey, widget.geminiModel);
                  }
                }
              },
              () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  final fileBytes = file.bytes;
                  if (fileBytes != null) {
                    await _service.generateTemplateFromPdf(
                        fileBytes, widget.geminiApiKey, widget.geminiModel);
                  }
                }
              },
              _service.removeField,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageProcessorPage extends StatefulWidget {
  @override
  _ImageProcessorPageState createState() => _ImageProcessorPageState();
}

class _ImageProcessorPageState extends State<ImageProcessorPage> {
  String _geminiOutput = '';
  String _geminiApiKey = '';
  String _geminiModel = '';
  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _selectedTemplate;
  late DynamicFieldAdderService _service;

  @override
  void initState() {
    super.initState();
    _loadApiKeyAndModel();
    _service = DynamicFieldAdderService(
      formKey: GlobalKey<FormState>(),
      collectionNameController: TextEditingController(),
      documentNameController: TextEditingController(),
      fieldNameControllers: [],
      fieldValueControllers: [],
      templates: _templates,
      templateNameController: TextEditingController(),
      setState: setState,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTemplates();
  }

  Future<void> _loadApiKeyAndModel() async {
    try {
      final configString = await rootBundle.loadString('assets/.config');
      final lines = configString.split('\n');
      for (final line in lines) {
        if (line.startsWith('GEMINI_API_KEY=')) {
          _geminiApiKey = line.substring('GEMINI_API_KEY='.length).trim();
        } else if (line.startsWith('MODEL_NAME=')) {
          _geminiModel = line.substring('MODEL_NAME='.length).trim();
        }
      }
      if (_geminiApiKey.isEmpty) {
        print('GEMINI_API_KEY not found in .config file');
      }
      if (_geminiModel.isEmpty) {
        print('MODEL_NAME not found in .config file');
      }
    } catch (e) {
      print('Error loading .config file: $e');
    }
  }

  Future<void> _loadTemplates() async {
    await _service.loadTemplates();
    setState(() {
      _templates = _service.templates;
    });
  }

  Future<void> _processImage() async {
    if (_selectedTemplate == null) {
      setState(() {
        _geminiOutput = 'Please select a template.';
      });
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _geminiOutput = 'Processing Images...';
      });
      try {
        final apiKey = _geminiApiKey;
        final model =
            gen_ai.GenerativeModel(model: _geminiModel, apiKey: apiKey);

        // Build the JSON template string from the selected template
        String jsonTemplate = '{';
        for (final entry in _selectedTemplate!.entries) {
          if (entry.key != 'name') {
            jsonTemplate += '"${entry.key}": "${entry.value}",';
          }
        }
        if (jsonTemplate.endsWith(',')) {
          jsonTemplate = jsonTemplate.substring(0, jsonTemplate.length - 1);
        }
        jsonTemplate += '}';

        List<gen_ai.Part> parts = [
          gen_ai.TextPart(
              """Extract the following information from this invoice and format it exactly as shown in the JSON template below:

            $jsonTemplate
            """)
        ];

        for (final file in result.files) {
          final imageBytes = file.bytes;
          if (imageBytes == null) {
            setState(() {
              _geminiOutput = 'Error reading image bytes.';
            });
            return;
          }
          img.Image? image = img.decodeImage(imageBytes);
          if (image == null) {
            setState(() {
              _geminiOutput = 'Error decoding image.';
            });
            return;
          }
          Uint8List encodedImageBytes = img.encodeJpg(image);
          parts.add(gen_ai.DataPart('image/jpeg', encodedImageBytes));
        }

        final content = [gen_ai.Content.multi(parts)];

        final response = await model.generateContent(content);
        String responseText = response.text ?? '';
        responseText = responseText.trim();
        responseText =
            responseText.replaceAll('```json', '').replaceAll('```', '');
        int startIdx = responseText.indexOf('{');
        int endIdx = responseText.lastIndexOf('}') + 1;
        if (startIdx != -1 && endIdx != -1) {
          responseText = responseText.substring(startIdx, endIdx);
        }
        final jsonOutput = json.decode(responseText);
        setState(() {
          _geminiOutput = JsonEncoder.withIndent('  ').convert(jsonOutput);
        });
      } catch (e) {
        setState(() {
          _geminiOutput = 'Error processing image: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Process Image')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return ListTile(
                  title: Text(template['name'] ?? 'Unnamed Template'),
                  onTap: () {
                    setState(() {
                      _selectedTemplate = template;
                    });
                  },
                  trailing: _selectedTemplate == template
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EmailVerificationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify Email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Please verify your email address. A verification link has been sent to your email.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.currentUser?.reload();
                  if (FirebaseAuth.instance.currentUser?.emailVerified ==
                      true) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(
                          geminiApiKey: '',
                          geminiModel: '',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Email not verified yet. Please check your email and try again.')),
                    );
                  }
                },
                child: Text('Check Verification Status'),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.currentUser
                      ?.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'A new verification email has been sent to your email address.')),
                  );
                },
                child: Text('Resend Verification Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
