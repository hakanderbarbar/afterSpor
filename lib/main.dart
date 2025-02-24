import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/loginScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // WICHTIG: Firebase starten
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'afterSpor',
      debugShowCheckedModeBanner: false,
      home: LoginScreen(), // Login-Seite als Startseite
    );
  }
}
