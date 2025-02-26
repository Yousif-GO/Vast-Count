import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ai_accountant/services/dynamic_field_adder_service.dart';
import 'package:ai_accountant/pdf_or_image_processor_page.dart';

class DynamicFieldAdder extends StatefulWidget {
  // Hardcoded API key and model name
  final String geminiApiKey = 'AIzaSyCQ8sbo-2fr7GHbR9034d0G2oCTF_r4vh0';
  final String geminiModel = 'gemini-1.5-flash';

  DynamicFieldAdder({
    Key? key,
  }) : super(key: key);

  @override
  _DynamicFieldAdderState createState() => _DynamicFieldAdderState();
}

class _DynamicFieldAdderState extends State<DynamicFieldAdder> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}

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
    appBar: AppBar(
      title: Text('Template Builder'),
      elevation: 2,
    ),
    body: Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Template name card
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
                        'Template Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: templateNameController,
                        decoration: InputDecoration(
                          labelText: 'Template Name',
                          hintText: 'Enter a descriptive name',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter template name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text('Save Template'),
                        onPressed: saveTemplate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fields section
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Template Fields',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle, color: Colors.green),
                              tooltip: 'Add Field',
                              onPressed: addField,
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Divider(),
                        Expanded(
                          child: fieldNameControllers.isEmpty
                              ? Center(
                                  child: Text(
                                    'No fields added yet. Add fields manually or generate from a document.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: fieldNameControllers.length,
                                  separatorBuilder: (context, index) =>
                                      Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller:
                                                  fieldNameControllers[index],
                                              decoration: InputDecoration(
                                                labelText: 'Field Name',
                                                hintText:
                                                    'e.g., Invoice Number',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Required';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller:
                                                  fieldValueControllers[index],
                                              decoration: InputDecoration(
                                                labelText: 'Field Value',
                                                hintText: 'e.g., INV-12345',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Required';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete,
                                                color: Colors.red[400]),
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
                      ],
                    ),
                  ),
                ),
              ),

              // Action buttons
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.image),
                      label: Text('Generate template from Image'),
                      onPressed: generateTemplateFromImage,
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
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.picture_as_pdf),
                      label: Text('Generate template from PDF'),
                      onPressed: generateTemplateFromPdf,
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
                icon: Icon(Icons.document_scanner),
                label: Text('Process Using Template'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfOrImageProcessorPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Saved templates section
              if (templates.isNotEmpty) ...[
                SizedBox(height: 16),
                Card(
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
                          'Saved Templates',
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
                          child: ListView.separated(
                            itemCount: templates.length,
                            separatorBuilder: (context, index) =>
                                Divider(height: 1),
                            itemBuilder: (context, index) {
                              return ListTile(
                                leading: Icon(Icons.description,
                                    color: Colors.blue[700]),
                                title: Text(templates[index]['name'] ??
                                    'Unnamed Template'),
                                subtitle: Text(
                                    '${(templates[index].length - 1).toString()} fields'),
                                trailing:
                                    Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => applyTemplate(templates[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
