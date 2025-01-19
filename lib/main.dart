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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firestore Dynamic Field Adder',
      home: HomePage(), // Use the new HomePage widget
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Main Page')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DynamicFieldAdder()),
                );
              },
              child: Text('Add Template'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ImageProcessorPage()),
                );
              },
              child: Text('Process Image'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PdfOrImageProcessorPage()),
                );
              },
              child: Text('Process PDF or Images'),
            ),
          ],
        ),
      ),
    );
  }
}

class DynamicFieldAdder extends StatefulWidget {
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
  String _geminiApiKey = ''; // Store the API key
  String _geminiModel = ''; // Store the model name

  @override
  void initState() {
    super.initState();
    _loadApiKey(); // Load the API key
    _service = DynamicFieldAdderService(
      formKey: _formKey,
      collectionNameController: _collectionNameController,
      documentNameController: _documentNameController,
      fieldNameControllers: _fieldNameControllers,
      fieldValueControllers: _fieldValueControllers,
      templates: _templates,
      templateNameController: _templateNameController,
      setState: setState,
    );
    _service.addField(); // Add initial field
    _service.loadTemplates();
  }

  Future<void> _loadApiKey() async {
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
    } catch (e) {
      print('Error loading .config file: $e');
    }
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

  Future<void> _processImage() async {
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

        // Build the JSON template string from the fields
        String jsonTemplate = '{';
        for (int i = 0; i < _fieldNameControllers.length; i++) {
          final fieldName = _fieldNameControllers[i].text.trim();
          final fieldValue = _fieldValueControllers[i].text.trim();
          if (fieldName.isNotEmpty) {
            jsonTemplate += '"$fieldName": "$fieldValue",';
          }
        }
        // Remove the trailing comma if it exists
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
            ),
          ),
          ElevatedButton(
            onPressed: _processImage,
            child: Text('Process Image with Gemini'),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Gemini Output:\n$_geminiOutput',
              textAlign: TextAlign.left,
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
          ElevatedButton(
            onPressed: _processImage,
            child: Text('Process Image with Selected Template'),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Gemini Output:\n$_geminiOutput',
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

class PdfOrImageProcessorPage extends StatefulWidget {
  @override
  _PdfOrImageProcessorPageState createState() =>
      _PdfOrImageProcessorPageState();
}

class _PdfOrImageProcessorPageState extends State<PdfOrImageProcessorPage> {
  String _geminiOutput = '';
  String _geminiApiKey = '';
  String _geminiModel = '';
  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _selectedTemplate;
  late DynamicFieldAdderService _service;
  bool _processing = false;
  String _status = '';

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
          final document = syncfusion_pdf.PdfDocument(inputBytes: bytes);
          String pdfText = '';
          for (int i = 0; i < document.pages.count; i++) {
            pdfText +=
                PdfTextExtractor(document).extractText(startPageIndex: i);
          }
          await _processText(pdfText);
          processedCount++;
        } catch (e) {
          setState(() {
            _status = 'Error processing PDF: $e';
            _processing = false;
          });
          return;
        }
      }
      setState(() {
        _status = 'Finished processing PDFs';
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error selecting files: $e';
        _processing = false;
      });
    }
  }

  Future<void> _pickAndProcessImages() async {
    setState(() {
      _processing = true;
      _status = 'Selecting images...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'No images selected';
          _processing = false;
        });
        return;
      }

      int processedCount = 0;
      int totalFiles = result.files.length;

      for (final file in result.files) {
        setState(() => _status =
            'Processing image ${processedCount + 1} of $totalFiles...');
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
        await _processImageBytes(encodedImageBytes);
        processedCount++;
      }
      setState(() {
        _status = 'Finished processing images';
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error selecting images: $e';
        _processing = false;
      });
    }
  }

  Future<void> _pickAndProcessImageFolder() async {
    try {
      setState(() {
        _processing = true;
        _status = 'Selecting folder...';
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'No folder selected';
          _processing = false;
        });
        return;
      }

      String? selectedDirectory;
      if (result.files.isNotEmpty) {
        // Get the directory from the first selected file
        selectedDirectory = path.dirname(result.files.first.path!);
      }

      if (selectedDirectory == null) {
        setState(() {
          _status = 'No folder selected';
          _processing = false;
        });
        return;
      }

      final dir = Directory(selectedDirectory);
      final files = dir.listSync();
      int processedCount = 0;
      int totalFiles = files.length;

      for (final file in files) {
        if (file is File &&
            (file.path.endsWith('.jpg') ||
                file.path.endsWith('.jpeg') ||
                file.path.endsWith('.png'))) {
          setState(() => _status =
              'Processing image ${processedCount + 1} of $totalFiles...');
          final imageBytes = await file.readAsBytes();
          img.Image? image = img.decodeImage(imageBytes);
          if (image == null) {
            setState(() {
              _geminiOutput = 'Error decoding image.';
            });
            return;
          }
          Uint8List encodedImageBytes = img.encodeJpg(image);
          await _processImageBytes(encodedImageBytes);
          processedCount++;
        }
      }
      setState(() {
        _status = 'Finished processing images';
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error selecting folder: $e';
        _processing = false;
      });
    }
  }

  Future<void> _processText(String text) async {
    try {
      final apiKey = _geminiApiKey;
      final model = gen_ai.GenerativeModel(model: _geminiModel, apiKey: apiKey);

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

            The text is:
            $text
            """)
      ];

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
        _geminiOutput = 'Error processing text: $e';
      });
    }
  }

  Future<void> _processImageBytes(Uint8List imageBytes) async {
    try {
      final apiKey = _geminiApiKey;
      final model = gen_ai.GenerativeModel(model: _geminiModel, apiKey: apiKey);

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

      parts.add(gen_ai.DataPart('image/jpeg', imageBytes));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Process PDF or Images')),
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
          ElevatedButton(
            onPressed: _pickAndProcessMultiplePDFs,
            child: Text('Process PDFs'),
          ),
          ElevatedButton(
            onPressed: _pickAndProcessImages,
            child: Text('Process Images'),
          ),
          ElevatedButton(
            onPressed: _pickAndProcessImageFolder,
            child: Text('Process Image Folder'),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Status: $_status',
              textAlign: TextAlign.left,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Gemini Output:\n$_geminiOutput',
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
