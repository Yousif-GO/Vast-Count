import 'package:flutter/material.dart';
import 'spaced_repetition.dart';

class ReviewPage extends StatefulWidget {
  final Scheduler scheduler;

  const ReviewPage({super.key, required this.scheduler});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<ChatMessage> _dueQuestions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDueQuestions();
  }

  Future<void> _loadDueQuestions() async {
    final questions = await widget.scheduler.getDueQuestions();
    setState(() {
      _dueQuestions = questions;
      _loading = false;
    });
  }

  Future<void> _handleReview(ChatMessage question, bool remembered) async {
    if (remembered) {
      await widget.scheduler.scheduleRepetition(question);
    } else {
      question.nextReview = DateTime.now().add(const Duration(days: 1));
      await widget.scheduler.scheduleRepetition(question);
    }

    setState(() {
      _dueQuestions.remove(question);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Questions'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dueQuestions.isEmpty
              ? const Center(child: Text('No questions to review!'))
              : ListView.builder(
                  itemCount: _dueQuestions.length,
                  itemBuilder: (context, index) {
                    final question = _dueQuestions[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(question.text),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () => _handleReview(question, true),
                              color: Colors.green,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _handleReview(question, false),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
