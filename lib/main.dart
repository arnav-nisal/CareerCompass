import 'package:adaptive_career_roadmap_builder/auth_gate.dart';
import 'package:adaptive_career_roadmap_builder/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// Import the Supabase package
import 'package:supabase_flutter/supabase_flutter.dart';
// Import the Firebase App Check package
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for authentication.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Activate Firebase App Check to secure your authentication service.
  await FirebaseAppCheck.instance.activate(
    // Use the debug provider in debug mode for testing.
    androidProvider: AndroidProvider.debug,
    // You must provide your own reCAPTCHA v3 site key for web.
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key-placeholder'),
  );

  // Initialize Supabase for the Edge Function.
  // You MUST replace these with your actual Supabase URL and Anon Key.
  await Supabase.initialize(
    url: 'https://ukzgwwmxuqremyqrcczy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVremd3d214dXFyZW15cXJjY3p5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2NTAwMzQsImV4cCI6MjA3NTIyNjAzNH0.tdYtF5sPDq__awLHyG6-LpW0AY6V2AqnCqehjW_uDuI',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive Career Roadmap Builder',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.purple,
        fontFamily: 'Inter',
      ),
      home: const AuthGate(),
    );
  }
}
