// lib/main.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firebase_service.dart';
import 'services/template_manager.dart';
import 'screens/user_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firebaseService = FirebaseService();
  final templateManager = TemplateManager(firebaseService);

  runApp(MyApp(templateManager));
}

class MyApp extends StatelessWidget {
  final TemplateManager templateManager;

  MyApp(this.templateManager);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: UserDashboardScreen(templateManager),
    );
  }
}
