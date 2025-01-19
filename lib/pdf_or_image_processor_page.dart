import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import 'services/dynamic_field_adder_service.dart';
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
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'view_documents_page.dart';

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
  int _linesPerBatch = 10; // Default value
  bool _showLinesPerBatch = false; // Control visibility
  File? _selectedFile;
  String? _selectedFileName;
  Map<String, TextEditingController> _fieldControllers = {};
  List<Map<String, dynamic>> _fields = [];
  bool _loading = false;
  File? _originalFile; // Add this at the class level

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
    _loadTemplates();
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
    setState(() {
      _processing = true;
    });
    try {
      await _service.loadTemplates();
      setState(() {
        _templates = _service.templates;
      });
    } catch (e) {
      print('Error loading templates: $e');
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  Future<void> _pickAndProcessMultiplePDFs() async {
    setState(() {
      _showLinesPerBatch = false;
      _processing = true;
      _status = 'Selecting PDFs...';
    });

    try {
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

      final firestore = FirebaseFirestore.instance;
      final processedDoc =
          await firestore.collection('processed').doc('files').get();
      final processedFiles = processedDoc.exists
          ? List<String>.from(processedDoc.data()?['files'] ?? [])
          : <String>[];

      int processedCount = 0;
      int totalFiles = result.files.length;

      for (PlatformFile file in result.files) {
        if (processedFiles.contains(file.name)) {
          print('Skipping already processed file: ${file.name}');
          continue; // Skip if already processed
        }

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
          await _processText(pdfText, file.name);
          processedCount++;

          // Add the file name to the processed list
          processedFiles.add(file.name);
          await firestore
              .collection('processed')
              .doc('files')
              .set({'files': processedFiles});
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
      _showLinesPerBatch = false;
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

      final firestore = FirebaseFirestore.instance;
      final processedDoc =
          await firestore.collection('processed').doc('files').get();
      final processedFiles = processedDoc.exists
          ? List<String>.from(processedDoc.data()?['files'] ?? [])
          : <String>[];

      int processedCount = 0;
      int totalFiles = result.files.length;

      for (final file in result.files) {
        if (processedFiles.contains(file.name)) {
          print('Skipping already processed file: ${file.name}');
          continue; // Skip if already processed
        }

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
        await _processImageBytes(encodedImageBytes, file.name);
        processedCount++;

        // Add the file name to the processed list
        processedFiles.add(file.name);
        await firestore
            .collection('processed')
            .doc('files')
            .set({'files': processedFiles});
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
    setState(() {
      _showLinesPerBatch = false;
      _processing = true;
      _status = 'Selecting folder...';
    });

    try {
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
      final firestore = FirebaseFirestore.instance;
      final processedDoc =
          await firestore.collection('processed').doc('files').get();
      final processedFiles = processedDoc.exists
          ? List<String>.from(processedDoc.data()?['files'] ?? [])
          : <String>[];

      for (final file in files) {
        if (file is File &&
            (file.path.endsWith('.jpg') ||
                file.path.endsWith('.jpeg') ||
                file.path.endsWith('.png'))) {
          if (processedFiles.contains(file.path)) {
            print('Skipping already processed file: ${file.path}');
            continue; // Skip if already processed
          }

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
          await _processImageBytes(encodedImageBytes, file.path);
          processedCount++;

          // Add the file name to the processed list
          processedFiles.add(file.path);
          await firestore
              .collection('processed')
              .doc('files')
              .set({'files': processedFiles});
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

  Future<void> _pickAndProcessTextFile() async {
    setState(() {
      _showLinesPerBatch = true;
      _processing = true;
      _status = 'Selecting text file...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'No text file selected';
          _processing = false;
        });
        return;
      }

      final file = result.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        setState(() {
          _status = 'Error reading file bytes';
          _processing = false;
        });
        return;
      }

      final fileString = utf8.decode(fileBytes);
      final lines = fileString.split('\n');
      int processedLines = 0;
      final firestore = FirebaseFirestore.instance;
      final processedDoc =
          await firestore.collection('processed').doc('files').get();
      final processedFiles = processedDoc.exists
          ? List<String>.from(processedDoc.data()?['files'] ?? [])
          : <String>[];

      while (processedLines < lines.length) {
        final batch = lines.sublist(
            processedLines,
            processedLines + _linesPerBatch > lines.length
                ? lines.length
                : processedLines + _linesPerBatch);
        final textBatch = batch.join('\n');
        if (processedFiles.contains(file.name + processedLines.toString())) {
          print('Skipping already processed batch of lines: $textBatch');
          processedLines += batch.length;
          continue; // Skip if already processed
        }

        setState(() {
          _status =
              'Processing lines ${processedLines + 1}-${processedLines + batch.length} of ${lines.length}...';
        });
        await _processText(textBatch, file.name + processedLines.toString());
        processedLines += batch.length;

        // Add the file name and line number to the processed list
        processedFiles.add(file.name + processedLines.toString());
        await firestore
            .collection('processed')
            .doc('files')
            .set({'files': processedFiles});
      }

      setState(() {
        _status = 'Finished processing text file';
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error processing text file: $e';
        _processing = false;
      });
    }
  }

  Future<void> _processText(String text, String fileName) async {
    int retries = 0;
    while (retries < 3) {
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
        dynamic jsonOutput;
        try {
          jsonOutput = json.decode(responseText);
        } catch (e) {
          try {
            jsonOutput = json.decode(responseText);
          } catch (e) {
            setState(() {
              _geminiOutput =
                  'Error decoding JSON: $e\nRaw Response: $responseText';
            });
            return;
          }
        }
        setState(() {
          _geminiOutput = JsonEncoder.withIndent('  ').convert(jsonOutput);
        });

        // Upload to Firebase Storage
        final storageRef =
            FirebaseStorage.instance.ref().child('files/$fileName');
        final storageUploadTask = storageRef.putString(text);
        final storageSnapshot = await storageUploadTask;
        final downloadUrl = await storageSnapshot.ref.getDownloadURL();

        // Save to Firestore
        final collectionName = _selectedTemplate!['name'] as String;
        final firestore = FirebaseFirestore.instance;
        await firestore
            .collection(collectionName)
            .add({...jsonOutput, 'fileUrl': downloadUrl});
        return; // Exit the loop if successful
      } catch (e) {
        retries++;
        if (retries == 3) {
          setState(() {
            _geminiOutput = 'Error processing text after 3 retries: $e';
          });
        } else {
          print('Retrying Gemini API call ($retries/3) after error: $e');
          await Future.delayed(Duration(seconds: 1)); // Optional delay
        }
      }
    }
  }

  Future<void> _processImageBytes(Uint8List imageBytes, String fileName) async {
    int retries = 0;
    while (retries < 3) {
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
        dynamic jsonOutput;
        try {
          jsonOutput = json.decode(responseText);
        } catch (e) {
          try {
            jsonOutput = json.decode(responseText);
          } catch (e) {
            setState(() {
              _geminiOutput =
                  'Error decoding JSON: $e\nRaw Response: $responseText';
            });
            return;
          }
        }
        setState(() {
          _geminiOutput = JsonEncoder.withIndent('  ').convert(jsonOutput);
        });

        // Upload to Firebase Storage
        final storageRef =
            FirebaseStorage.instance.ref().child('files/$fileName');
        final storageUploadTask = storageRef.putData(imageBytes);
        final storageSnapshot = await storageUploadTask;
        final downloadUrl = await storageSnapshot.ref.getDownloadURL();

        // Save to Firestore
        final collectionName = _selectedTemplate!['name'] as String;
        final firestore = FirebaseFirestore.instance;
        await firestore
            .collection(collectionName)
            .add({...jsonOutput, 'fileUrl': downloadUrl});
        return; // Exit the loop if successful
      } catch (e) {
        retries++;
        if (retries == 3) {
          setState(() {
            _geminiOutput = 'Error processing image after 3 retries: $e';
          });
        } else {
          print('Retrying Gemini API call ($retries/3) after error: $e');
          await Future.delayed(Duration(seconds: 1)); // Optional delay
        }
      }
    }
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        _originalFile = File(result.files.single.path!); // Store original file
        _selectedFile =
            File(result.files.single.path!); // Use copy for processing
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_originalFile == null || _selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a file and a template')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final storage = FirebaseStorage.instance;
      final fileName = path.basename(_originalFile!.path);
      final storageRef = storage.ref().child('files/$fileName');

      // Upload the original unaltered file with correct metadata
      String? mimeType = lookupMimeType(_originalFile!.path);

      await storageRef.putFile(
          _originalFile!, SettableMetadata(contentType: mimeType));

      final fileUrl = await storageRef.getDownloadURL();

      final firestore = FirebaseFirestore.instance;
      final docRef = firestore
          .collection(_selectedTemplate!['name'])
          .doc(_selectedFileName);

      Map<String, dynamic> data = {
        'fileUrl': fileUrl,
        'date': DateTime.now().toIso8601String(),
      };

      if (_fields.isNotEmpty) {
        Map<String, dynamic> fieldsData = {};
        for (var field in _fields) {
          final controller = _fieldControllers[field['name']];
          if (controller != null) {
            fieldsData[field['name']] = controller.text;
          }
        }
        data['fields'] = fieldsData;
      }

      await docRef.set(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File uploaded successfully')),
      );
    } catch (e) {
      print('Error uploading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file')),
      );
    } finally {
      setState(() {
        _loading = false;
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
          if (_showLinesPerBatch)
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Lines per batch'),
              onChanged: (value) {
                setState(() {
                  _linesPerBatch = int.tryParse(value) ?? 10;
                });
              },
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
          ElevatedButton(
            onPressed: _pickAndProcessTextFile,
            child: Text('Process Text File'),
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
