import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chatroom_selection_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _saveTeamAndProceed(BuildContext context, String team) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorite_team', team);

    // Lieblingsmannschaft in Firestore speichern
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'favorite_team': team,
      });
    }

    // Wechsle zur Chatroom-Seite
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ChatRoomSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _saveTeamAndProceed(context, 'Galatasaray'),
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.45,
              color: Colors.red,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/galatasaray.png', width: 150),
                  const SizedBox(height: 10),
                  const Text(
                    "Galatasaray",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _saveTeamAndProceed(context, 'Fenerbahçe'),
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.45,
              color: Colors.blue,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/fenerbahce.png', width: 150),
                  const SizedBox(height: 10),
                  const Text(
                    "Fenerbahçe",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
