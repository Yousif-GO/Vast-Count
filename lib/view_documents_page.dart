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
  List<Map<String, dynamic>> _filteredDocuments = [];
  List<String> _columns = [];
  bool _loading = true;
  Map<String, bool> _selectedColumns = {};
  Map<String, double> _columnSums = {};
  final TextEditingController _filterController = TextEditingController();
  String _filterColumn = '';

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
        _documents = snapshot.docs.map((doc) {
          var data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _filteredDocuments = List.from(_documents);
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
        for (var doc in _filteredDocuments) {
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

  Future<void> _updateDocument(
      String docId, String column, dynamic newValue) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection(widget.templateName).doc(docId);

      if (column == 'fileUrl') {
        await docRef.update({column: newValue});
      } else {
        final doc = await docRef.get();
        if (doc.exists &&
            doc.data()!.containsKey('fields') &&
            doc.data()!['fields'] is Map) {
          await docRef.update({'fields.$column': newValue});
        } else {
          await docRef.update({column: newValue});
        }
      }
      // Refresh the data
      _loadDocuments();
    } catch (e) {
      print('Error updating document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating document: $e')),
      );
    }
  }

  void _filterDocuments() {
    String filterText = _filterController.text.toLowerCase();
    if (filterText.isEmpty || _filterColumn.isEmpty) {
      setState(() {
        _filteredDocuments = List.from(_documents);
      });
      return;
    }

    setState(() {
      _filteredDocuments = _documents.where((doc) {
        if (doc.containsKey('fields') && doc['fields'] is Map) {
          final fields = doc['fields'] as Map;
          if (fields.containsKey(_filterColumn)) {
            return fields[_filterColumn]
                .toString()
                .toLowerCase()
                .contains(filterText);
          }
        }
        if (doc.containsKey(_filterColumn)) {
          return doc[_filterColumn]
              .toString()
              .toLowerCase()
              .contains(filterText);
        }
        return false;
      }).toList();
    });
    _calculateSums();
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
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _filterController,
                              decoration: InputDecoration(
                                  labelText: 'Filter by $_filterColumn'),
                              onChanged: (_) => _filterDocuments(),
                            ),
                          ),
                          DropdownButton<String>(
                            value: _filterColumn.isEmpty ? null : _filterColumn,
                            hint: Text('Select a column'),
                            onChanged: (String? newValue) {
                              setState(() {
                                _filterColumn = newValue ?? '';
                                _filterDocuments();
                              });
                            },
                            items: _columns
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
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
                        rows: _filteredDocuments
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
                                      return DataCell(
                                        TextFormField(
                                          initialValue:
                                              fields[column]?.toString() ?? '',
                                          onFieldSubmitted: (newValue) {
                                            _updateDocument(
                                                doc['id'], column, newValue);
                                          },
                                        ),
                                      );
                                    }
                                  }
                                  return DataCell(
                                    TextFormField(
                                      initialValue:
                                          doc[column]?.toString() ?? '',
                                      onFieldSubmitted: (newValue) {
                                        _updateDocument(
                                            doc['id'], column, newValue);
                                      },
                                    ),
                                  );
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
