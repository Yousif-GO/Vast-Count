import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

Widget buildDynamicFieldAdderUI(
  BuildContext context,
  GlobalKey<FormState> formKey,
  TextEditingController collectionNameController,
  TextEditingController? documentNameController,
  TextEditingController templateNameController,
  List<TextEditingController> fieldNameControllers,
  List<TextEditingController> fieldValueControllers,
  List<Map<String, dynamic>> templates,
  VoidCallback addField,
  Future<void> Function() addDynamicFields,
  Future<void> Function() saveTemplate,
  void Function(Map<String, dynamic>) applyTemplate,
  Future<void> Function() generateTemplateFromImage,
  Future<void> Function() generateTemplateFromPdf,
  void Function(int) removeField,
) {
  return Scaffold(
    appBar: AppBar(title: Text('Add Dynamic Fields')),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              controller: templateNameController,
              decoration: InputDecoration(labelText: 'Template Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter template name';
                }
                return null;
              },
            ),
            Expanded(
              child: ListView.builder(
                itemCount: fieldNameControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: fieldNameControllers[index],
                            decoration:
                                InputDecoration(labelText: 'Field Name'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter field name';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: fieldValueControllers[index],
                            decoration:
                                InputDecoration(labelText: 'Field Value'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter field value';
                              }
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            removeField(index);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: addField,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text('Add Field manually'),
                ],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveTemplate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text('Save Template'),
                ],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                );
                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  final fileBytes = file.bytes;
                  if (fileBytes != null) {
                    await generateTemplateFromImage();
                  }
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image),
                  SizedBox(width: 8),
                  Text('Generate Template From Image'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  final fileBytes = file.bytes;
                  if (fileBytes != null) {
                    await generateTemplateFromPdf();
                  }
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf),
                  SizedBox(width: 8),
                  Text('Generate Template From PDF'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(templates[index]['name']),
                    onTap: () => applyTemplate(templates[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
