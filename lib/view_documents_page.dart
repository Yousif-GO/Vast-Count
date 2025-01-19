import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ViewDocumentsPage extends StatefulWidget {
  final String templateName;

  ViewDocumentsPage({required this.templateName});

  @override
  _ViewDocumentsPageState createState() => _ViewDocumentsPageState();
}

class _ViewDocumentsPageState extends State<ViewDocumentsPage> {
  List<Map<String, dynamic>> _documents = [];
  List<String> _columns = [];
  bool _loading = true;
  Map<String, bool> _selectedColumns = {};
  Map<String, double> _columnSums = {};

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection(widget.templateName).get();
      if (snapshot.docs.isNotEmpty) {
        _documents = snapshot.docs.map((doc) => doc.data()).toList();
        if (_documents.isNotEmpty) {
          // Collect all unique keys from all documents, including nested fields
          Set<String> allKeys = {};
          for (var doc in _documents) {
            doc.forEach((key, value) {
              if (key == 'fields' && value is Map) {
                value.forEach((fieldKey, fieldValue) {
                  allKeys.add(fieldKey);
                });
              } else {
                allKeys.add(key);
              }
            });
          }
          _columns = allKeys.toList();
          _selectedColumns = {for (var column in _columns) column: false};
          _calculateSums();
        }
      }
    } catch (e) {
      print('Error loading documents: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _calculateSums() {
    _columnSums = {};
    for (var column in _columns) {
      if (_selectedColumns[column] == true) {
        double sum = 0;
        for (var doc in _documents) {
          if (doc.containsKey('fields') && doc['fields'] is Map) {
            final fields = doc['fields'] as Map;
            if (fields.containsKey(column)) {
              final value = fields[column];
              if (value is String) {
                try {
                  sum += double.parse(value.replaceAll(',', ''));
                } catch (e) {
                  // Ignore non-numeric values
                }
              } else if (value is num) {
                sum += value.toDouble();
              }
            }
          } else if (doc.containsKey(column)) {
            final value = doc[column];
            if (value is String) {
              try {
                sum += double.parse(value.replaceAll(',', ''));
              } catch (e) {
                // Ignore non-numeric values
              }
            } else if (value is num) {
              sum += value.toDouble();
            }
          }
        }
        _columnSums[column] = sum;
      }
    }
  }

  String _formatNumber(double number) {
    final formatter = NumberFormat('#,###.00');
    return formatter.format(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Documents for ${widget.templateName}'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(child: Text('No documents found.'))
              : Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: _columns
                            .map((column) => DataColumn(
                                  label: Row(
                                    children: [
                                      Text(column),
                                      Checkbox(
                                        value:
                                            _selectedColumns[column] ?? false,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedColumns[column] = value!;
                                            _calculateSums();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        rows: _documents
                            .map((doc) => DataRow(
                                    cells: _columns.map((column) {
                                  if (column == 'fileUrl' &&
                                      doc[column] != null) {
                                    return DataCell(
                                      InkWell(
                                        child: Text(
                                          'View File',
                                          style: TextStyle(
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline),
                                        ),
                                        onTap: () => _launchURL(doc[column]),
                                      ),
                                    );
                                  } else if (doc.containsKey('fields') &&
                                      doc['fields'] is Map) {
                                    final fields = doc['fields'] as Map;
                                    if (fields.containsKey(column)) {
                                      return DataCell(Text(
                                          fields[column]?.toString() ?? ''));
                                    }
                                  }
                                  return DataCell(
                                      Text(doc[column]?.toString() ?? ''));
                                }).toList()))
                            .toList(),
                      ),
                    ),
                    if (_columnSums.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _columnSums.entries
                              .map((entry) => Text(
                                  'Sum of ${entry.key}: ${_formatNumber(entry.value)}'))
                              .toList(),
                        ),
                      ),
                  ],
                ),
    );
  }
}
