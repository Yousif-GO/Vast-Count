import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'dart:convert';

class ChatMessage {
  final String text;
  final DateTime timestamp;
  DateTime nextReview;
  int interval;

  ChatMessage({
    required this.text,
    required this.timestamp,
    required this.nextReview,
    this.interval = 1,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'nextReview': nextReview.toIso8601String(),
        'interval': interval,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        timestamp: DateTime.parse(json['timestamp']),
        nextReview: DateTime.parse(json['nextReview']),
        interval: json['interval'],
      );
}

class Scheduler {
  static final Scheduler _instance = Scheduler._internal();
  factory Scheduler() => _instance;
  Scheduler._internal();

  final List<ChatMessage> _scheduledItems = [];
  static const _prefsKey = 'scheduledQuestions';

  Future<void> addQuestion(ChatMessage question) async {
    _scheduledItems.add(question);
    await _saveToPrefs();
  }

  Future<void> scheduleRepetition(ChatMessage question) async {
    question.interval *= 2;
    question.nextReview = DateTime.now().add(Duration(days: question.interval));
    await _saveToPrefs();
  }

  Future<List<ChatMessage>> getDueQuestions() async {
    await _loadFromPrefs();
    final now = DateTime.now();
    return _scheduledItems.where((q) => q.nextReview.isBefore(now)).toList();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      _scheduledItems.addAll(
        jsonList.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)),
      );
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _scheduledItems.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }
}
