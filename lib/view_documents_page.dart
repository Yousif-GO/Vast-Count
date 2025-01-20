import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:function_tree/function_tree.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'package:firebase_auth/firebase_auth.dart';

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
  int _filterKey = 0;
  Map<String, double> _savedSums = {};
  String _selectedOperation = 'add';
  Map<String, bool> _isDateColumn = {};
  final TextEditingController _dateFilterController = TextEditingController();
  final TextEditingController _dateFilterController2 = TextEditingController();
  List<FilterCondition> _filterConditions = [];
  String? _selectedFilterColumn;
  String? _selectedFilterOperator;
  final TextEditingController _filterValueController = TextEditingController();
  String? _selectedDateFilterColumn;
  String? _selectedDateFilterOperator;
  String? _selectedGeminiColumn;
  final ScrollController _horizontalScrollController = ScrollController();

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
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirebaseFirestore.instance;
      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (userId != null) {
        snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('data')
            .doc(widget.templateName)
            .collection('entries')
            .get();
      } else {
        snapshot = await firestore
            .collection('data')
            .doc(widget.templateName)
            .collection('entries')
            .get();
      }

      setState(() {
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
      });
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
        if (_filterConditions.isEmpty &&
            (_selectedDateFilterColumn == null ||
                _selectedDateFilterOperator == null ||
                _dateFilterController.text.isEmpty)) {
          return true;
        }
        bool match = true;
        // Apply regular filters
        for (var condition in _filterConditions) {
          final column = condition.column;
          final operator = condition.operator;
          final value = condition.value;
          dynamic docValue;
          if (doc.containsKey(column)) {
            docValue = doc[column];
          } else if (doc.containsKey('fields') && doc['fields'] is Map) {
            final fields = doc['fields'] as Map;
            if (fields.containsKey(column)) {
              docValue = fields[column];
            }
          }
          if (docValue == null) {
            match = false;
            break;
          }
          switch (operator) {
            case 'equals':
              match = docValue.toString() == value;
              break;
            case 'contains':
              match = docValue
                  .toString()
                  .toLowerCase()
                  .contains(value.toLowerCase());
              break;
            case 'greater than':
              match = _parseNumber(docValue.toString()) > _parseNumber(value);
              break;
            case 'less than':
              match = _parseNumber(docValue.toString()) < _parseNumber(value);
              break;
            default:
              match = false;
              break;
          }
          if (!match) {
            break;
          }
        }
        // Apply date filters only if regular filters match
        if (match &&
            _selectedDateFilterColumn != null &&
            _selectedDateFilterOperator != null &&
            _dateFilterController.text.isNotEmpty) {
          final dateColumn = _selectedDateFilterColumn!;
          final dateOperator = _selectedDateFilterOperator!;
          final dateValue = _dateFilterController.text;
          dynamic docDate;
          if (doc.containsKey(dateColumn)) {
            docDate = doc[dateColumn];
          } else if (doc.containsKey('fields') && doc['fields'] is Map) {
            final fields = doc['fields'] as Map;
            if (fields.containsKey(dateColumn)) {
              docDate = fields[dateColumn];
            }
          }
          if (docDate != null) {
            try {
              final parsedDocDate = DateTime.parse(docDate.toString());
              switch (dateOperator) {
                case 'equals':
                  final parsedFilterDate = DateTime.parse(dateValue);
                  match = parsedDocDate == parsedFilterDate;
                  break;
                case 'less than':
                  final parsedFilterDate = DateTime.parse(dateValue);
                  match = parsedDocDate.isBefore(parsedFilterDate);
                  break;
                case 'greater than':
                  final parsedFilterDate = DateTime.parse(dateValue);
                  match = parsedDocDate.isAfter(parsedFilterDate);
                  break;
                case 'between':
                  if (_dateFilterController2.text.isNotEmpty) {
                    final parsedFilterDate1 = DateTime.parse(dateValue);
                    final parsedFilterDate2 =
                        DateTime.parse(_dateFilterController2.text);
                    match = parsedDocDate.isAfter(parsedFilterDate1) &&
                        parsedDocDate.isBefore(parsedFilterDate2);
                  } else {
                    match = false;
                  }
                  break;
                default:
                  match = false;
                  break;
              }
            } catch (e) {
              match = false;
            }
          } else {
            match = false;
          }
        }
        return match;
      }).toList();
      _filterKey++;
    });
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
      _filteredDocuments = List.from(_documents);
      _filterDocuments();
    });
  }

  Future<void> _addNewGeminiColumn() async {
    String? prompt;
    String? newColumnName;
    String? selectedGeminiColumn;

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
                  DropdownButtonFormField<String>(
                    value: selectedGeminiColumn,
                    hint: Text('Select a context column'),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedGeminiColumn = newValue;
                      });
                    },
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('Take All'),
                      ),
                      DropdownMenuItem<String>(
                        value: '__full_row__',
                        child: Text('Take Full Row'),
                      ),
                      ..._columns.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ],
                  ),
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
                  _createGeminiColumn(
                      prompt!, newColumnName!, selectedGeminiColumn);
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

  Future<void> _createGeminiColumn(
      String prompt, String newColumnName, String? selectedGeminiColumn) async {
    setState(() {
      _loading = true;
    });
    try {
      _columns.add(newColumnName);
      _selectedColumns[newColumnName] = false;
      final firestore = FirebaseFirestore.instance;
      for (var doc in _documents) {
        String context = '';
        if (selectedGeminiColumn == '__full_row__') {
          doc.forEach((key, value) {
            if (key != 'id') {
              context += '$key: $value, ';
            }
          });
        } else if (selectedGeminiColumn != null) {
          if (doc.containsKey(selectedGeminiColumn)) {
            context = '$selectedGeminiColumn: ${doc[selectedGeminiColumn]}, ';
          } else if (doc.containsKey('fields') && doc['fields'] is Map) {
            final fields = doc['fields'] as Map;
            if (fields.containsKey(selectedGeminiColumn)) {
              context =
                  '$selectedGeminiColumn: ${fields[selectedGeminiColumn]}, ';
            }
          }
        } else {
          doc.forEach((key, value) {
            if (key != 'id') {
              context += '$key: $value, ';
            }
          });
        }
        final apiKey = widget.geminiApiKey;
        final model =
            gen_ai.GenerativeModel(model: widget.geminiModel, apiKey: apiKey);
        final content = [
          gen_ai.Content.text(
              '$prompt. The context is: $context. Please provide a single value for the new column.')
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

  void _calculateSums() {
    _columnSums = {};
    for (var column in _columns) {
      if (_selectedColumns[column] == true) {
        double sum = 0;
        for (var doc in _filteredDocuments) {
          if (doc.containsKey(column)) {
            sum += _parseNumber(doc[column].toString());
          } else if (doc.containsKey('fields') && doc['fields'] is Map) {
            final fields = doc['fields'] as Map;
            if (fields.containsKey(column)) {
              sum += _parseNumber(fields[column].toString());
            }
          }
        }
        _columnSums[column] = sum;
      }
    }
  }

  void _addFilterCondition() {
    if (_selectedFilterColumn != null &&
        _selectedFilterOperator != null &&
        _filterValueController.text.isNotEmpty) {
      setState(() {
        _filterConditions.add(FilterCondition(
          column: _selectedFilterColumn!,
          operator: _selectedFilterOperator!,
          value: _filterValueController.text,
        ));
        _filterValueController.clear();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterConditions.clear();
      _filteredDocuments = List.from(_documents);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Documents for ${widget.templateName}'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _addNewCalculatedColumn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                                255, 0, 65, 97), // Button color
                            foregroundColor: Colors.white, // Text color
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8), // Rounded corners
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12), // Padding
                          ),
                          child: Text('Add Calculated Column'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addNewGeminiColumn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                                255, 39, 128, 17), // Button color
                            foregroundColor: Colors.white, // Text color
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8), // Rounded corners
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12), // Padding
                          ),
                          child: Text('Add Gemini Column'),
                        ),
                      ],
                    ),
                    // Filter UI
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              DropdownButton<String>(
                                hint: Text('Select Column'),
                                value: _selectedFilterColumn,
                                items: _columns
                                    .map((column) => DropdownMenuItem(
                                          value: column,
                                          child: Text(column),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedFilterColumn = value;
                                  });
                                },
                              ),
                              SizedBox(width: 8),
                              DropdownButton<String>(
                                hint: Text('Select Operator'),
                                value: _selectedFilterOperator,
                                items: [
                                  'equals',
                                  'contains',
                                  'greater than',
                                  'less than',
                                ]
                                    .map((operator) => DropdownMenuItem(
                                          value: operator,
                                          child: Text(operator),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedFilterOperator = value;
                                  });
                                },
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _filterValueController,
                                  decoration: InputDecoration(
                                    labelText: 'Filter Value',
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _addFilterCondition,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.blueGrey, // Button color
                                  foregroundColor: Colors.white, // Text color
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        8), // Rounded corners
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12), // Padding
                                ),
                                child: Text('Add Filter'),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            children: _filterConditions
                                .map((condition) => Chip(
                                      label: Text(
                                          '${condition.column} ${condition.operator} ${condition.value}'),
                                    ))
                                .toList(),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              DropdownButton<String>(
                                hint: Text('Select Date Column'),
                                value: _selectedDateFilterColumn,
                                items: _columns
                                    .map((column) => DropdownMenuItem(
                                          value: column,
                                          child: Text(column),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDateFilterColumn = value;
                                  });
                                },
                              ),
                              SizedBox(width: 8),
                              DropdownButton<String>(
                                hint: Text('Select Date Operator'),
                                value: _selectedDateFilterOperator,
                                items: [
                                  'equals',
                                  'less than',
                                  'greater than',
                                  'between',
                                ]
                                    .map((operator) => DropdownMenuItem(
                                          value: operator,
                                          child: Text(operator),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDateFilterOperator = value;
                                  });
                                },
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _dateFilterController,
                                  decoration: InputDecoration(
                                    labelText: 'Filter by Date',
                                    hintText: 'YYYY-MM-DD',
                                  ),
                                ),
                              ),
                              if (_selectedDateFilterOperator == 'between')
                                SizedBox(width: 8),
                              if (_selectedDateFilterOperator == 'between')
                                Expanded(
                                  child: TextField(
                                    controller: _dateFilterController2,
                                    decoration: InputDecoration(
                                      labelText: 'Filter by Date 2',
                                      hintText: 'YYYY-MM-DD',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: _filterDocuments,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                      255, 1, 58, 52), // Button color
                                  foregroundColor: Colors.white, // Text color
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        8), // Rounded corners
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12), // Padding
                                ),
                                child: Text('Apply Filters'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _clearFilters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                      255, 126, 53, 53), // Button color
                                  foregroundColor: Colors.white, // Text color
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        8), // Rounded corners
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12), // Padding
                                ),
                                child: Text('Clear Filters'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Horizontal Scroll Handle
                    SizedBox(
                      child: Scrollbar(
                        controller: _horizontalScrollController,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: IntrinsicWidth(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                  cardTheme: CardTheme(
                                    color: Colors.grey[100],
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  dataTableTheme: DataTableThemeData(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    headingRowHeight: 40,
                                    dataRowHeight: 60,
                                    headingTextStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  )),
                              child: DataTable(
                                key: ValueKey(_filterKey),
                                columns: _columns
                                    .map((column) => DataColumn(
                                          label: Row(
                                            children: [
                                              Text(column),
                                              Checkbox(
                                                value:
                                                    _selectedColumns[column] ??
                                                        false,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedColumns[column] =
                                                        value!;
                                                    _calculateSums();
                                                  });
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.close),
                                                onPressed: () =>
                                                    _deleteColumn(column),
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
                                                      decoration: TextDecoration
                                                          .underline),
                                                ),
                                                onTap: () =>
                                                    _launchURL(doc[column]),
                                              ),
                                            );
                                          } else if (doc
                                                  .containsKey('fields') &&
                                              doc['fields'] is Map) {
                                            final fields = doc['fields'] as Map;
                                            if (fields.containsKey(column)) {
                                              return DataCell(
                                                TextFormField(
                                                  initialValue: fields[column]
                                                          ?.toString() ??
                                                      '',
                                                  onFieldSubmitted: (newValue) {
                                                    _updateDocument(doc['id'],
                                                        column, newValue);
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
                                                _updateDocument(doc['id'],
                                                    column, newValue);
                                              },
                                            ),
                                          );
                                        }).toList()))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
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
              ),
            ),
    );
  }
}

class FilterCondition {
  String column;
  String operator;
  String value;

  FilterCondition({
    required this.column,
    required this.operator,
    required this.value,
  });
}
