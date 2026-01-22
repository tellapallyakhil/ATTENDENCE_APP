import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
     // Enable offline persistence explicitly
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    print('Error initializing Firebase: $e');
    // Continue running app even if Firebase fails (e.g. on Web without full config)
  }
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance App',
      theme: ThemeData(
        useMaterial3: true,

        // ✅ FORCE FONT (KEY FIX)
        fontFamily: 'Roboto',

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF), // Cyan/Teal Seed
          brightness: Brightness.dark, // Default to dark for this theme
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: 'Roboto', // ✅ reinforce
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
