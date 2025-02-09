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
import 'pdf_or_image_processor_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'view_documents_page.dart'; // Import the new page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart'; // Add this import
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'spaced_repetition.dart';
import 'review_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// The API key to use when accessing the Gemini API.
///
/// To learn how to generate and specify this key,
/// check out the README file of this sample.
const String _apiKey = 'AIzaSyCQ8sbo-2fr7GHbR9034d0G2oCTF_r4vh0';

void main() {
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter + Generative AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 171, 222, 244),
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(title: 'Flutter + Generative AI'),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: const ChatWidget(apiKey: _apiKey, title: 'Flutter + Generative AI'),
    );
  }
}

class ChatWidget extends StatefulWidget {
  final String apiKey;
  final String title;

  const ChatWidget({
    required this.apiKey,
    required this.title,
    super.key,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  List<({Image? image, String? text, bool fromUser})> _generatedContent = [];
  bool _loading = false;
  late FlutterTts flutterTts; // Add TTS instance
  final Scheduler _scheduler = Scheduler();

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: 'AIzaSyCQ8sbo-2fr7GHbR9034d0G2oCTF_r4vh0',
    );
    _chat = _model.startChat();
    flutterTts = FlutterTts(); // Initialize TTS
    _initTts();
    _loadMessages();
    _checkScheduledQuestions();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(1);

    // Set to use Google's high-quality TTS engine
    await flutterTts.setEngine("com.google.android.tts");
    await flutterTts
        .setVoice({"name": "en-us-x-sfg#male_2-local", "locale": "en-US"});
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 750,
        ),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getString('chatHistory');
    if (messagesJson != null) {
      final List<dynamic> jsonList = jsonDecode(messagesJson);
      setState(() {
        _generatedContent = jsonList
            .map((e) => (
                  image: null,
                  text: e['text'] as String,
                  fromUser: e['fromUser'] as bool,
                ))
            .toList();
      });
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _generatedContent
        .map((e) => {
              'text': e.text,
              'fromUser': e.fromUser,
            })
        .toList();
    await prefs.setString('chatHistory', jsonEncode(jsonList));
  }

  Future<void> _checkScheduledQuestions() async {
    final dueQuestions = await _scheduler.getDueQuestions();
    if (dueQuestions.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Review Time!'),
          content: Text('You have ${dueQuestions.length} questions to review'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Later'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startReviewSession(dueQuestions);
              },
              child: Text('Review Now'),
            ),
          ],
        ),
      );
    }
  }

  void _startReviewSession(List<ChatMessage> questions) {
    // Implement review session UI
  }

  void _showUpcomingReviews() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<List<ChatMessage>>(
          future: _scheduler.getDueQuestions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final questions = snapshot.data ?? [];
            return ListView.builder(
              shrinkWrap: true,
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                return ListTile(
                  title: Text(question.text),
                  subtitle:
                      Text('Next review: ${_formatDate(question.nextReview)}'),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'Enter a prompt...',
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: _showUpcomingReviews,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReviewPage(scheduler: _scheduler),
            ),
          );
        },
        child: const Icon(Icons.quiz),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _apiKey.isNotEmpty
                  ? ListView.builder(
                      controller: _scrollController,
                      itemBuilder: (context, idx) {
                        final content = _generatedContent[idx];
                        return MessageWidget(
                          text: content.text,
                          image: content.image,
                          isFromUser: content.fromUser,
                        );
                      },
                      itemCount: _generatedContent.length,
                    )
                  : ListView(
                      children: const [
                        Text(
                          'No API key found. Please provide an API Key using '
                          "'--dart-define' to set the 'API_KEY' declaration.",
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 25,
                horizontal: 15,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: () async {
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null) {
                        final imageBytes = result.files.single.bytes;
                        if (imageBytes != null) {
                          _sendContent('', imageBytes: imageBytes);
                        }
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      focusNode: _textFieldFocus,
                      decoration: textFieldDecoration,
                      controller: _textController,
                      onSubmitted: _sendContent,
                    ),
                  ),
                  const SizedBox.square(dimension: 15),
                  IconButton(
                    onPressed: !_loading
                        ? () async {
                            _sendContent(_textController.text);
                          }
                        : null,
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendContent(String message, {Uint8List? imageBytes}) async {
    setState(() {
      _loading = true;
    });

    try {
      final parts = <Map<String, dynamic>>[];

      // Add text
      if (message.isNotEmpty) parts.add({"text": message});

      // Add image
      if (imageBytes != null) {
        parts.add({
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": base64Encode(imageBytes)
          }
        });
      }

      // HTTP request
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': widget.apiKey,
        },
        body: jsonEncode({
          "contents": [
            {"parts": parts}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text =
            jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        _generatedContent.add((image: null, text: text, fromUser: false));

        if (text == null) {
          _showError('No response from API.');
          return;
        } else {
          setState(() {
            _loading = false;
            _scrollDown();
          });
        }
      } else {
        _showError('API Error: ${response.statusCode}');
      }

      await _scheduler.addQuestion(ChatMessage(
        text: message,
        timestamp: DateTime.now(),
        nextReview: DateTime.now().add(Duration(days: 1)),
        interval: 1,
      ));

      await _saveMessages();
    } catch (e) {
      _showError('Failed to process audio: $e');
      setState(() {
        _loading = false;
      });
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    this.image,
    this.text,
    required this.isFromUser,
  });

  final Image? image;
  final String? text;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
            child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                decoration: BoxDecoration(
                  color: isFromUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(children: [
                  if (text case final text?)
                    Row(
                      children: [
                        Expanded(child: MarkdownBody(data: text)),
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: () {
                            final chatState = context
                                .findAncestorStateOfType<_ChatWidgetState>();
                            chatState?._speak(text);
                          },
                        ),
                      ],
                    ),
                  if (image case final image?) image,
                ]))),
      ],
    );
  }
}
