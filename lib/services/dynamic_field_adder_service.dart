import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DynamicFieldAdderService {
  final GlobalKey<FormState> formKey;
  final TextEditingController collectionNameController;
  final TextEditingController documentNameController;
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
      final documentName = documentNameController.text.trim();
      Map<String, dynamic> fields = {};

      for (int i = 0; i < fieldNameControllers.length; i++) {
        final fieldName = fieldNameControllers[i].text.trim();
        final fieldValue = fieldValueControllers[i].text.trim();
        if (fieldName.isNotEmpty && fieldValue.isNotEmpty) {
          fields[fieldName] = fieldValue;
        }
      }

      try {
        await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(documentName)
            .set(fields, SetOptions(merge: true));

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

      for (int i = 0; i < fieldNameControllers.length; i++) {
        final fieldName = fieldNameControllers[i].text.trim();
        final fieldValue = fieldValueControllers[i].text.trim();
        if (fieldName.isNotEmpty && fieldValue.isNotEmpty) {
          fields[fieldName] = fieldValue;
        }
      }

      try {
        await FirebaseFirestore.instance
            .collection('templates')
            .doc(templateName)
            .set({'fields': fields});

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
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('templates').get();

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
    documentNameController.clear();
    templateNameController.clear();
    for (var controller in fieldNameControllers) {
      controller.clear();
    }
    for (var controller in fieldValueControllers) {
      controller.clear();
    }
  }
}
