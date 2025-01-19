import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:function_tree/function_tree.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;

class ViewDocumentsPage extends StatefulWidget {
  final String templateName;
  final String geminiApiKey;
  final String geminiModel;

  ViewDocumentsPage({
    required this.templateName,
    required this.geminiApiKey,
    required this.geminiModel,
  });

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
  Map<String, bool> _isDateColumn = {};
  int _filterKey = 0;
  Map<String, double> _savedSums = {};
  String _selectedOperation = 'add';
  String _filterDate = '';
  final TextEditingController _dateFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _loadSavedSums();
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
          _isDateColumn = {for (var column in _columns) column: false};
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

  double _parseNumber(String value) {
    // Remove all non-numeric characters except dots, commas, and minus signs
    String cleanedValue = value.replaceAll(RegExp(r'[^\d.,-]'), '');

    // Remove dollar signs and spaces
    cleanedValue = cleanedValue.replaceAll('\$', '').trim();

    // // Replace dots with empty string if there are commas
    // if (cleanedValue.contains(',')) {
    //   cleanedValue = cleanedValue.replaceAll('.', '');
    // }
    // Replace commas with dots
    cleanedValue = cleanedValue.replaceAll(',', '');

    try {
      return double.parse(cleanedValue);
    } catch (e) {
      return 0.0; // Return 0 if parsing fails
    }
  }

  void _calculateSums() {
    _columnSums = {};
    for (var column in _columns) {
      if (_selectedColumns[column] == true) {
        double sum = 0;
        for (var doc in _filteredDocuments) {
          dynamic value;
          if (doc.containsKey('fields') && doc['fields'] is Map) {
            final fields = doc['fields'] as Map;
            value = fields[column];
          } else {
            value = doc[column];
          }
          if (value != null) {
            if (value is String) {
              sum += _parseNumber(value);
            } else if (value is num) {
              sum += value.toDouble();
            }
          }
        }
        _columnSums[column] = sum;
      }
    }
    setState(() {});
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
    setState(() {
      _filteredDocuments = _documents.where((doc) {
        if (_filterColumn.isEmpty) {
          return true; // Show all documents if no filter column is selected
        }

        final filterValue = _filterController.text.toLowerCase();
        dynamic docValue;

        if (doc.containsKey('fields') && doc['fields'] is Map) {
          final fields = doc['fields'] as Map;
          docValue = fields[_filterColumn];
        } else {
          docValue = doc[_filterColumn];
        }

        if (docValue == null) {
          return false; // Skip documents that don't have the filter column
        }

        return docValue.toString().toLowerCase().contains(filterValue);
      }).toList();
      _calculateSums();
      _filterKey++;
    });
  }

  Future<void> _saveSums() async {
    final firestore = FirebaseFirestore.instance;
    for (var entry in _columnSums.entries) {
      await firestore.collection('sums').add({
        'templateName': widget.templateName,
        'column': entry.key,
        'sum': entry.value,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    _loadSavedSums();
  }

  Future<void> _loadSavedSums() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('sums')
        .where('templateName', isEqualTo: widget.templateName)
        .get();
    _savedSums = {};
    for (var doc in snapshot.docs) {
      _savedSums[doc['column']] = doc['sum'];
    }
    setState(() {});
  }

  double _performOperation(double currentSum, double savedSum) {
    switch (_selectedOperation) {
      case 'add':
        return currentSum + savedSum;
      case 'subtract':
        return currentSum - savedSum;
      case 'multiply':
        return currentSum * savedSum;
      default:
        return currentSum + savedSum;
    }
  }

  Future<void> _addNewCalculatedColumn() async {
    String? selectedColumn;
    String? operation;
    String? newColumnName;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Calculated Column'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedColumn,
                    hint: Text('Select a column'),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedColumn = newValue;
                      });
                    },
                    items:
                        _columns.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  TextFormField(
                    decoration:
                        InputDecoration(labelText: 'Operation (e.g., * 0.15)'),
                    onChanged: (value) => operation = value,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'New Column Name'),
                    onChanged: (value) => newColumnName = value,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (selectedColumn != null &&
                    operation != null &&
                    newColumnName != null) {
                  Navigator.pop(context);
                  _createCalculatedColumn(
                      selectedColumn!, operation!, newColumnName!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Please select a column, enter an operation, and a new column name.')),
                  );
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _createCalculatedColumn(
      String selectedColumn, String operation, String newColumnName) {
    setState(() {
      _columns.add(newColumnName);
      _selectedColumns[newColumnName] = false;

      for (var doc in _documents) {
        dynamic value;
        if (doc.containsKey('fields') && doc['fields'] is Map) {
          final fields = doc['fields'] as Map;
          value = fields[selectedColumn];
        } else {
          value = doc[selectedColumn];
        }

        if (value != null) {
          try {
            final parsedValue = _parseNumber(value.toString());
            final result = (parsedValue.toString() + operation).interpret();
            if (doc.containsKey('fields') && doc['fields'] is Map) {
              doc['fields'][newColumnName] = result;
            } else {
              doc[newColumnName] = result;
            }
          } catch (e) {
            if (doc.containsKey('fields') && doc['fields'] is Map) {
              doc['fields'][newColumnName] = 'Error';
            } else {
              doc[newColumnName] = 'Error';
            }
          }
        } else {
          if (doc.containsKey('fields') && doc['fields'] is Map) {
            doc['fields'][newColumnName] = null;
          } else {
            doc[newColumnName] = null;
          }
        }
      }
      _filterDocuments();
    });
  }

  Future<void> _addNewGeminiColumn() async {
    String? prompt;
    String? newColumnName;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Gemini Column'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Gemini Prompt'),
                    onChanged: (value) => prompt = value,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'New Column Name'),
                    onChanged: (value) => newColumnName = value,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (prompt != null && newColumnName != null) {
                  Navigator.pop(context);
                  _createGeminiColumn(prompt!, newColumnName!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Please enter a prompt and a new column name.')),
                  );
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createGeminiColumn(String prompt, String newColumnName) async {
    setState(() {
      _loading = true;
    });
    try {
      _columns.add(newColumnName);
      _selectedColumns[newColumnName] = false;
      final firestore = FirebaseFirestore.instance;
      for (var doc in _documents) {
        String context = '';
        doc.forEach((key, value) {
          if (key != 'id') {
            context += '$key: $value, ';
          }
        });
        final apiKey = widget.geminiApiKey;
        final model =
            gen_ai.GenerativeModel(model: widget.geminiModel, apiKey: apiKey);
        final content = [
          gen_ai.Content.text(
              '$prompt. The context is: $context. Please provide a single value for the new column.give clean output(no explanation) for a column similar to excel operartion')
        ];
        final response = await model.generateContent(content);
        final geminiResponse = response.text?.trim() ?? '';
        // Update Firestore
        final docRef = firestore.collection(widget.templateName).doc(doc['id']);
        Map<String, dynamic> updatedFields = {};
        if (doc.containsKey('fields') && doc['fields'] is Map) {
          updatedFields = Map<String, dynamic>.from(doc['fields']);
        }
        updatedFields[newColumnName] = geminiResponse;
        await docRef.update({'fields': updatedFields});
        // Update local document
        if (doc.containsKey('fields')) {
          doc['fields'][newColumnName] = geminiResponse;
        } else {
          doc['fields'] = {newColumnName: geminiResponse};
        }
      }
      _filteredDocuments = List.from(_documents);
      _calculateSums();
    } catch (e) {
      print('Error creating Gemini column: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
    _loadDocuments();
  }

  Future<void> _deleteColumn(String column) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Column'),
          content: Text('Are you sure you want to delete column "$column"?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _columns.remove(column);
                  _selectedColumns.remove(column);
                  for (var doc in _documents) {
                    if (doc.containsKey('fields')) {
                      doc['fields'].remove(column);
                    }
                  }
                  _filteredDocuments = List.from(_documents);
                  _calculateSums();
                });
                // Delete from Firestore
                final firestore = FirebaseFirestore.instance;
                for (var doc in _documents) {
                  final docRef =
                      firestore.collection(widget.templateName).doc(doc['id']);
                  if (doc.containsKey('fields')) {
                    await docRef.update({
                      'fields': doc['fields'],
                    });
                  }
                }
                _loadDocuments();
              },
            ),
          ],
        );
      },
    );
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
                        key: ValueKey(_filterKey),
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
                                      IconButton(
                                        icon: Icon(Icons.close),
                                        onPressed: () => _deleteColumn(column),
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
                          children: [
                            ..._columnSums.entries
                                .map((entry) => Text(
                                    'Sum of ${entry.key}: ${_formatNumber(entry.value)}'))
                                .toList(),
                            SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _saveSums,
                              child: Text('Save Sums'),
                            ),
                            if (_savedSums.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 10),
                                  Text('Saved Sums:'),
                                  ..._savedSums.entries.map((entry) {
                                    final currentSum =
                                        _columnSums[entry.key] ?? 0;
                                    final operatedSum = _performOperation(
                                        currentSum, entry.value);
                                    return Text(
                                        '${entry.key}: ${_formatNumber(entry.value)} (Current: ${_formatNumber(currentSum)}, Operated: ${_formatNumber(operatedSum)})');
                                  }).toList(),
                                  DropdownButton<String>(
                                    value: _selectedOperation,
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedOperation = newValue;
                                        });
                                      }
                                    },
                                    items: <String>[
                                      'add',
                                      'subtract',
                                      'multiply'
                                    ].map<DropdownMenuItem<String>>(
                                        (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _addNewCalculatedColumn,
                      child: Text('Add Calculated Column'),
                    ),
                    ElevatedButton(
                      onPressed: _addNewGeminiColumn,
                      child: Text('Add Gemini Column'),
                    ),
                  ],
                ),
    );
  }
}
