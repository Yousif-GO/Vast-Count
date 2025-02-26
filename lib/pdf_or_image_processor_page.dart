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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'view_documents_page.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'services/api_key_service.dart';

class Config {
  String apiKey = '';
  String modelName = '';
}

class PdfOrImageProcessorPage extends StatefulWidget {
  @override
  _PdfOrImageProcessorPageState createState() =>
      _PdfOrImageProcessorPageState();
}
// ... existing code ...

class _PdfOrImageProcessorPageState extends State<PdfOrImageProcessorPage> {
  // Hardcoded API key and model name
  String _geminiApiKey = ApiKeyService.getGeminiApiKey();
  String _geminiModel = 'gemini-1.5-flash';
  // No need to load API key here
  String _geminiOutput = '';
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
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a template first')),
      );
      return;
    }
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

      // Check if user is anonymous
      final user = FirebaseAuth.instance.currentUser;
      final isAnonymous = user?.isAnonymous ?? false;
      List<String> processedFiles = [];

      // Only track processed files for non-anonymous users
      if (!isAnonymous && user != null) {
        final firestore = FirebaseFirestore.instance;
        final processedDoc = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('processed')
            .doc('files')
            .get();

        processedFiles = processedDoc.exists
            ? List<String>.from(processedDoc.data()?['files'] ?? [])
            : <String>[];
      }

      int processedCount = 0;
      int totalFiles = result.files.length;

      for (PlatformFile file in result.files) {
        // Skip already processed files only for non-anonymous users
        if (!isAnonymous && processedFiles.contains(file.name)) {
          print('Skipping already processed file: ${file.name}');
          continue;
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

          // Add the file name to the processed list for non-anonymous users
          if (!isAnonymous && user != null) {
            processedFiles.add(file.name);
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('processed')
                .doc('files')
                .set({'files': processedFiles});
          }
        } catch (e) {
          setState(() {
            _status = 'Error processing PDF: $e';
            _processing = false;
          });
          return;
        }
      }
      setState(() {
        _status = processedCount > 0
            ? 'Finished processing $processedCount PDFs'
            : 'All PDFs were already processed';
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
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a template first')),
      );
      return;
    }
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

      // Check if user is anonymous
      final user = FirebaseAuth.instance.currentUser;
      final isAnonymous = user?.isAnonymous ?? false;
      List<String> processedFiles = [];

      // Only track processed files for non-anonymous users
      if (!isAnonymous && user != null) {
        final firestore = FirebaseFirestore.instance;
        final processedDoc = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('processed')
            .doc('files')
            .get();

        processedFiles = processedDoc.exists
            ? List<String>.from(processedDoc.data()?['files'] ?? [])
            : <String>[];
      }

      int processedCount = 0;
      int totalFiles = result.files.length;

      for (final file in result.files) {
        // Skip already processed files only for non-anonymous users
        if (!isAnonymous && processedFiles.contains(file.name)) {
          print('Skipping already processed file: ${file.name}');
          continue;
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

        // Add the file name to the processed list for non-anonymous users
        if (!isAnonymous && user != null) {
          processedFiles.add(file.name);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('processed')
              .doc('files')
              .set({'files': processedFiles});
        }
      }
      setState(() {
        _status = processedCount > 0
            ? 'Finished processing $processedCount images'
            : 'All images were already processed';
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
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a template first')),
      );
      return;
    }
    setState(() {
      _showLinesPerBatch = false;
      _processing = true;
      _status = 'Selecting image folder...';
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
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a template first')),
      );
      return;
    }
    int? linesPerBatch;
    await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Lines Per Batch'),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              linesPerBatch = int.tryParse(value);
            },
            decoration: InputDecoration(hintText: 'Number of lines'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(linesPerBatch);
              },
            ),
          ],
        );
      },
    );

    if (linesPerBatch == null) {
      return; // User cancelled or entered invalid input
    }

    setState(() {
      _showLinesPerBatch = true;
      _linesPerBatch = linesPerBatch!;
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
        final model = gen_ai.GenerativeModel(
            model: _geminiModel,
            apiKey: apiKey,
            generationConfig:
                GenerationConfig(responseMimeType: 'application/json'));

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
              """Extract all instances of the following information from this document and format it as a JSON array of objects. Each object should follow this template:

                $jsonTemplate

                If there are multiple entries/rows in the document, extract each one as a separate object in the array. If there is only one entry, still return it as an array with a single object.

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

        // Check if the response is an array or a single object
        int startArrayIdx = responseText.indexOf('[');
        int endArrayIdx = responseText.lastIndexOf(']') + 1;
        int startObjIdx = responseText.indexOf('{');
        int endObjIdx = responseText.lastIndexOf('}') + 1;

        dynamic jsonOutput;

        try {
          if (startArrayIdx != -1 &&
              endArrayIdx != -1 &&
              startArrayIdx < endArrayIdx) {
            // It's an array format
            String jsonArrayStr =
                responseText.substring(startArrayIdx, endArrayIdx);
            jsonOutput = json.decode(jsonArrayStr);
          } else if (startObjIdx != -1 && endObjIdx != -1) {
            // It's a single object, wrap it in an array
            String jsonObjStr = responseText.substring(startObjIdx, endObjIdx);
            jsonOutput = [json.decode(jsonObjStr)];
          } else {
            throw FormatException('Could not find valid JSON in response');
          }
        } catch (e) {
          setState(() {
            _geminiOutput =
                'Error decoding JSON: $e\nRaw Response: $responseText';
          });
          retries++;
          if (retries < 3) {
            await Future.delayed(Duration(seconds: 1));
            continue;
          }
          return;
        }

        // Ensure jsonOutput is a List
        List<dynamic> jsonList = jsonOutput is List ? jsonOutput : [jsonOutput];

        setState(() {
          _geminiOutput = 'Found ${jsonList.length} entries:\n\n' +
              JsonEncoder.withIndent('  ').convert(jsonList);
        });

        // Upload to Firebase Storage
        final userId = FirebaseAuth.instance.currentUser?.uid;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('files/${userId != null ? userId + '/' : ''}$fileName');
        final storageUploadTask = storageRef.putString(text);
        final storageSnapshot = await storageUploadTask;
        final downloadUrl = await storageSnapshot.ref.getDownloadURL();

        // Save to Firestore - now save each entry separately
        final collectionName = _selectedTemplate!['name'] as String;
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        for (var entry in jsonList) {
          if (entry is Map<String, dynamic>) {
            // Add file URL to each entry
            entry['fileUrl'] = downloadUrl;

            // Create a reference for a new document
            DocumentReference docRef;
            if (userId != null) {
              docRef = firestore
                  .collection('users')
                  .doc(userId)
                  .collection('data')
                  .doc(collectionName)
                  .collection('entries')
                  .doc(); // Auto-generate ID
            } else {
              docRef = firestore
                  .collection('data')
                  .doc(collectionName)
                  .collection('entries')
                  .doc(); // Auto-generate ID
            }

            // Add to batch
            batch.set(docRef, entry);
          }
        }

        // Commit the batch
        await batch.commit();

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
        final model = gen_ai.GenerativeModel(
            model: _geminiModel,
            apiKey: apiKey,
            generationConfig:
                GenerationConfig(responseMimeType: 'application/json'));

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
              """Extract all instances of the following information from this document and format it as a JSON array of objects. Each object should follow this template:

                $jsonTemplate

                If there are multiple entries/rows in the document, extract each one as a separate object in the array. If there is only one entry, still return it as an array with a single object.
                """)
        ];

        parts.add(gen_ai.DataPart('image/jpeg', imageBytes));

        final content = [gen_ai.Content.multi(parts)];

        final response = await model.generateContent(content);
        String responseText = response.text ?? '';
        responseText = responseText.trim();
        responseText =
            responseText.replaceAll('```json', '').replaceAll('```', '');

        // Check if the response is an array or a single object
        int startArrayIdx = responseText.indexOf('[');
        int endArrayIdx = responseText.lastIndexOf(']') + 1;
        int startObjIdx = responseText.indexOf('{');
        int endObjIdx = responseText.lastIndexOf('}') + 1;

        dynamic jsonOutput;

        try {
          if (startArrayIdx != -1 &&
              endArrayIdx != -1 &&
              startArrayIdx < endArrayIdx) {
            // It's an array format
            String jsonArrayStr =
                responseText.substring(startArrayIdx, endArrayIdx);
            jsonOutput = json.decode(jsonArrayStr);
          } else if (startObjIdx != -1 && endObjIdx != -1) {
            // It's a single object, wrap it in an array
            String jsonObjStr = responseText.substring(startObjIdx, endObjIdx);
            jsonOutput = [json.decode(jsonObjStr)];
          } else {
            throw FormatException('Could not find valid JSON in response');
          }
        } catch (e) {
          setState(() {
            _geminiOutput =
                'Error decoding JSON: $e\nRaw Response: $responseText';
          });
          retries++;
          if (retries < 3) {
            await Future.delayed(Duration(seconds: 1));
            continue;
          }
          return;
        }

        // Ensure jsonOutput is a List
        List<dynamic> jsonList = jsonOutput is List ? jsonOutput : [jsonOutput];

        setState(() {
          _geminiOutput = 'Found ${jsonList.length} entries:\n\n' +
              JsonEncoder.withIndent('  ').convert(jsonList);
        });

        // Upload to Firebase Storage
        final userId = FirebaseAuth.instance.currentUser?.uid;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('files/${userId != null ? userId + '/' : ''}$fileName');
        final storageUploadTask = storageRef.putData(imageBytes);
        final storageSnapshot = await storageUploadTask;
        final downloadUrl = await storageSnapshot.ref.getDownloadURL();

        // Save to Firestore - now save each entry separately
        final collectionName = _selectedTemplate!['name'] as String;
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        for (var entry in jsonList) {
          if (entry is Map<String, dynamic>) {
            // Add file URL to each entry
            entry['fileUrl'] = downloadUrl;

            // Create a reference for a new document
            DocumentReference docRef;
            if (userId != null) {
              docRef = firestore
                  .collection('users')
                  .doc(userId)
                  .collection('data')
                  .doc(collectionName)
                  .collection('entries')
                  .doc(); // Auto-generate ID
            } else {
              docRef = firestore
                  .collection('data')
                  .doc(collectionName)
                  .collection('entries')
                  .doc(); // Auto-generate ID
            }

            // Add to batch
            batch.set(docRef, entry);
          }
        }

        // Commit the batch
        await batch.commit();

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
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final storageRef = storage
          .ref()
          .child('files/${userId != null ? userId + '/' : ''}$fileName');

      // Upload the original unaltered file with correct metadata
      String? mimeType = lookupMimeType(_originalFile!.path);

      await storageRef.putFile(
          _originalFile!, SettableMetadata(contentType: mimeType));

      final fileUrl = await storageRef.getDownloadURL();

      final firestore = FirebaseFirestore.instance;
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('data')
          .doc(_selectedTemplate!['name'])
          .collection('entries')
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
      appBar: AppBar(
        title: Text('Process Documents'),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.view_list),
            tooltip: 'View Documents',
            onPressed: () {
              if (_selectedTemplate != null &&
                  _selectedTemplate!['name'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewDocumentsPage(
                        templateName: _selectedTemplate!['name']),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select a template first')),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Template selection card
              Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Template',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Divider(),
                      Container(
                        height: 150,
                        child: _templates.isEmpty
                            ? Center(
                                child: Text(
                                  'No templates available. Create a template first.',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _templates.length,
                                separatorBuilder: (context, index) =>
                                    Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final template = _templates[index];
                                  return ListTile(
                                    leading: Icon(
                                      Icons.description,
                                      color: _selectedTemplate == template
                                          ? Colors.green
                                          : Colors.blue[700],
                                    ),
                                    title: Text(
                                        template['name'] ?? 'Unnamed Template'),
                                    subtitle: Text(
                                        '${(template.length - 1).toString()} fields'),
                                    trailing: _selectedTemplate == template
                                        ? Icon(Icons.check_circle,
                                            color: Colors.green)
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedTemplate = template;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Processing options card
              Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Process Documents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.picture_as_pdf),
                              label: Text('Process PDFs'),
                              onPressed:
                                  _selectedTemplate == null || _processing
                                      ? null
                                      : _pickAndProcessMultiplePDFs,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.image),
                              label: Text('Process Images'),
                              onPressed:
                                  _selectedTemplate == null || _processing
                                      ? null
                                      : _pickAndProcessImages,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: Icon(Icons.text_snippet),
                        label: Text('Process Text File'),
                        onPressed: _selectedTemplate == null || _processing
                            ? null
                            : _pickAndProcessTextFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Status and output card
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Processing Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Divider(),
                        if (_processing)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  _status,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.blueGrey[700],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _status.contains('Error')
                                            ? Icons.error
                                            : _status.contains('Finished')
                                                ? Icons.check_circle
                                                : Icons.info,
                                        color: _status.contains('Error')
                                            ? Colors.red
                                            : _status.contains('Finished')
                                                ? Colors.green
                                                : Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _status.isEmpty
                                              ? 'Ready to process'
                                              : _status,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.blueGrey[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'AI Output:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        _geminiOutput.isEmpty
                                            ? 'Processed data will appear here'
                                            : _geminiOutput,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
