import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'teamSelection.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  _UsernameScreenState createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController usernameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = false;
  String errorMessage = '';

  Future<void> _saveUsername() async {
    setState(() => isLoading = true);
    String username = usernameController.text.trim();
    if (username.isNotEmpty) {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'username': username,
          'email': user.email,
          'uid': user.uid,
          'favorite_team': null,
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OnboardingScreen()),
        );
      }
    } else {
      setState(() => errorMessage = 'Bitte gib einen Benutzernamen ein.');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/login.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset("assets/login.png", height: 80),
                  SizedBox(height: 10),
                  Text(
                    "Wähle deinen Spielernamen!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: "Benutzername",
                      prefixIcon: Icon(Icons.person, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (errorMessage.isNotEmpty)
                    Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  SizedBox(height: 10),
                  isLoading
                      ? CircularProgressIndicator(color: Colors.green)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 50),
                          ),
                          onPressed: _saveUsername,
                          child: Text("Speichern", style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
