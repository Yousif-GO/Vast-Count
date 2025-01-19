import 'package:flutter/material.dart';

Widget buildDynamicFieldAdderUI(
  BuildContext context,
  GlobalKey<FormState> formKey,
  TextEditingController collectionNameController,
  TextEditingController documentNameController,
  TextEditingController templateNameController,
  List<TextEditingController> fieldNameControllers,
  List<TextEditingController> fieldValueControllers,
  List<Map<String, dynamic>> templates,
  void Function() addField,
  Future<void> Function() addDynamicFields,
  Future<void> Function() saveTemplate,
  void Function(Map<String, dynamic>) applyTemplate,
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
              controller: collectionNameController,
              decoration: InputDecoration(labelText: 'Collection Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter collection name';
                }
                return null;
              },
            ),
            TextFormField(
              controller: documentNameController,
              decoration: InputDecoration(labelText: 'Document Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter document name';
                }
                return null;
              },
            ),
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
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: addField,
              child: Text('Add Field'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: addDynamicFields,
              child: Text('Add Fields'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveTemplate,
              child: Text('Save Template'),
            ),
            SizedBox(height: 20),
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
