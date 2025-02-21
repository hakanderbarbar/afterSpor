import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName; // Füge dies hinzu
  final int maxUsers;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName, // Füge dies hinzu
    required this.maxUsers,
  });

  @override
  _VoiceRoomScreenState createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    _firestore.collection('chatrooms').doc(widget.roomId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        List<dynamic> userList = snapshot.get('users') ?? [];
        setState(() {
          users = List<String>.from(userList);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int columnCount = (widget.maxUsers / 2).ceil();
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: widget.maxUsers,
          itemBuilder: (context, index) {
            String? username = index < users.length ? users[index] : null;
            return Container(
              decoration: BoxDecoration(
                color: username != null ? Colors.blueAccent : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: username != null
                    ? Text(
                        username[0].toUpperCase(),
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    : const Icon(Icons.person_outline, size: 40, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }
}
