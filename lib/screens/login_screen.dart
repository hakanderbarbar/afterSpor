import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'voiceroom_selection.dart';
import 'UsernameScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatRoomSelectionScreen()),
      );
    } catch (e) {
      setState(() {
        errorMessage = "Login fehlgeschlagen: ${e.toString()}";
      });
    }
  }

Future<void> _register() async {
  try {
    await _auth.createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => UsernameScreen()),
    );
  } catch (e) {
    setState(() {
      errorMessage = "Registrierung fehlgeschlagen: ${e.toString()}";
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Passwort"),
              obscureText: true,
            ),
            SizedBox(height: 10),
            Text(errorMessage, style: TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _login, child: Text("Login")),
            ElevatedButton(onPressed: _register, child: Text("Registrieren")),
          ],
        ),
      ),
    );
  }
}
