import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'dart:convert';
import 'dart:typed_data';

class DynamicFieldAdderService {
  final GlobalKey<FormState> formKey;
  final TextEditingController collectionNameController;
  final TextEditingController? documentNameController;
  final List<TextEditingController> fieldNameControllers;
  final List<TextEditingController> fieldValueControllers;
  final List<Map<String, dynamic>> templates;
  final TextEditingController templateNameController;
  final void Function(void Function()) setState;

  DynamicFieldAdderService({
    required this.formKey,
    required this.collectionNameController,
    required this.documentNameController,
    required this.fieldNameControllers,
    required this.fieldValueControllers,
    required this.templates,
    required this.templateNameController,
    required this.setState,
  });

  void addField() {
    setState(() {
      fieldNameControllers.add(TextEditingController());
      fieldValueControllers.add(TextEditingController());
    });
  }

  Future<void> addDynamicFields() async {
    if (formKey.currentState!.validate()) {
      final collectionName = collectionNameController.text.trim();
      final documentName = documentNameController?.text.trim() ?? '';
      Map<String, dynamic> fields = {};
      final userId = FirebaseAuth.instance.currentUser?.uid;

      for (int i = 0; i < fieldNameControllers.length; i++) {
        final fieldName = fieldNameControllers[i].text.trim();
        final fieldValue = fieldValueControllers[i].text.trim();
        if (fieldName.isNotEmpty && fieldValue.isNotEmpty) {
          fields[fieldName] = fieldValue;
        }
      }

      try {
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('documents')
              .doc(collectionName)
              .collection('entries')
              .add(fields);
        } else {
          await FirebaseFirestore.instance
              .collection(collectionName)
              .doc(documentName)
              .set(fields, SetOptions(merge: true));
        }

        ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
          SnackBar(content: Text('Fields added successfully!')),
        );
        clearForm();
      } catch (e) {
        ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
          SnackBar(content: Text('Error adding fields: $e')),
        );
      }
    }
  }

  Future<void> saveTemplate() async {
    if (formKey.currentState!.validate()) {
      final templateName = templateNameController.text.trim();
      Map<String, dynamic> fields = {};
      final userId = FirebaseAuth.instance.currentUser?.uid;

      for (int i = 0; i < fieldNameControllers.length; i++) {
        final fieldName = fieldNameControllers[i].text.trim();
        final fieldValue = fieldValueControllers[i].text.trim();
        if (fieldName.isNotEmpty && fieldValue.isNotEmpty) {
          fields[fieldName] = fieldValue;
        }
      }

      try {
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('templates')
              .doc(templateName)
              .set({'fields': fields});
        } else {
          await FirebaseFirestore.instance
              .collection('templates')
              .doc(templateName)
              .set({'fields': fields});
        }

        ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
          SnackBar(content: Text('Template saved successfully!')),
        );
        loadTemplates();
      } catch (e) {
        ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
        );
      }
    }
  }

  Future<void> loadTemplates() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (userId != null) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('templates')
            .get();
      } else {
        snapshot =
            await FirebaseFirestore.instance.collection('templates').get();
      }

      setState(() {
        templates.clear();
        templates.addAll(snapshot.docs.map((doc) {
          return {
            'name': doc.id,
            'fields': doc.data()['fields'] as Map<String, dynamic>,
          };
        }).toList());
      });
    } catch (e) {
      ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
        SnackBar(content: Text('Error loading templates: $e')),
      );
    }
  }

  void applyTemplate(Map<String, dynamic> template) {
    setState(() {
      fieldNameControllers.clear();
      fieldValueControllers.clear();
      Map<String, dynamic> fields = template['fields'];
      fields.forEach((key, value) {
        fieldNameControllers.add(TextEditingController(text: key));
        fieldValueControllers.add(TextEditingController(text: value));
      });
    });
  }

  void clearForm() {
    collectionNameController.clear();
    templateNameController.clear();
    for (var controller in fieldNameControllers) {
      controller.clear();
    }
    for (var controller in fieldValueControllers) {
      controller.clear();
    }
  }

  Future<void> generateTemplateFromImage(
      Uint8List imageBytes, String geminiApiKey, String geminiModel) async {
    showDialog(
      context: formKey.currentContext!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Generating template..."),
            ],
          ),
        );
      },
    );
    try {
      final model =
          gen_ai.GenerativeModel(model: geminiModel, apiKey: geminiApiKey);

      List<gen_ai.Part> parts = [
        gen_ai.TextPart(
            """Analyze this image and determine the fields that are present in it. Return a JSON object with the field names as keys and empty strings as values.
            
            Example:
            {
              "field1": "",
              "field2": "",
              "field3": ""
            }
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
          ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
            SnackBar(content: Text('Error decoding JSON: $e')),
          );
          Navigator.of(formKey.currentContext!).pop();
          return;
        }
      }

      setState(() {
        fieldNameControllers.clear();
        fieldValueControllers.clear();
        jsonOutput.forEach((key, value) {
          fieldNameControllers.add(TextEditingController(text: key));
          fieldValueControllers
              .add(TextEditingController(text: "get the " + key));
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
        SnackBar(content: Text('Error generating template: $e')),
      );
    } finally {
      Navigator.of(formKey.currentContext!).pop();
    }
  }

  Future<void> generateTemplateFromPdf(
      Uint8List pdfBytes, String geminiApiKey, String geminiModel) async {
    showDialog(
      context: formKey.currentContext!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Generating template..."),
            ],
          ),
        );
      },
    );
    try {
      final model =
          gen_ai.GenerativeModel(model: geminiModel, apiKey: geminiApiKey);

      List<gen_ai.Part> parts = [
        gen_ai.TextPart(
            """Analyze this PDF and determine the fields that are present in it. Return a JSON object with the field names as keys and empty strings as values.
            
            Example:
            {
              "field1": "",
              "field2": "",
              "field3": ""
            }
            """)
      ];

      parts.add(gen_ai.DataPart('application/pdf', pdfBytes));

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
          ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
            SnackBar(content: Text('Error decoding JSON: $e')),
          );
          Navigator.of(formKey.currentContext!).pop();
          return;
        }
      }

      setState(() {
        fieldNameControllers.clear();
        fieldValueControllers.clear();
        jsonOutput.forEach((key, value) {
          fieldNameControllers.add(TextEditingController(text: key));
          fieldValueControllers
              .add(TextEditingController(text: "get the " + key));
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(formKey.currentContext!).showSnackBar(
        SnackBar(content: Text('Error generating template: $e')),
      );
    } finally {
      Navigator.of(formKey.currentContext!).pop();
    }
  }

  void removeField(int index) {
    if (index >= 0 && index < fieldNameControllers.length) {
      fieldNameControllers.removeAt(index);
      fieldValueControllers.removeAt(index);
      setState(() {}); // Trigger a rebuild of the UI
    }
  }
}
