import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatroom_selection_screen.dart';
import 'onboarding_screen.dart';

class UsernameScreen extends StatefulWidget {
  @override
  _UsernameScreenState createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController usernameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

Future<void> _saveUsername() async {
  String username = usernameController.text.trim();
  if (username.isNotEmpty) {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'username': username,
        'email': user.email,
        'uid': user.uid,
        'favorite_team': null, // Lieblingsmannschaft wird später gesetzt
      });

      // Weiterleitung zur Onboarding-Seite
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Benutzername eingeben")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: "Benutzername"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUsername,
              child: Text("Speichern"),
            ),
          ],
        ),
      ),
    );
  }
}
