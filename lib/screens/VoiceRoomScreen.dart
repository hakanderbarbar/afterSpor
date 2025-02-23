import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final int maxUsers;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
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
  //_joinRoom(widget.roomId);  // Nutzer zum Raum hinzufügen
  _loadUsers(); // Nutzerliste aus Firestore laden
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

void _joinRoom(String roomId) async {
  User? user = _auth.currentUser;
  if (user != null) {
    // Stelle sicher, dass der Username geladen wird
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    String? username = userDoc.exists ? userDoc['username'] : null;

    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler: Username konnte nicht geladen werden.')),
      );
      return;
    }

    DocumentReference roomRef = _firestore.collection('chatrooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot roomSnapshot = await transaction.get(roomRef);
      if (roomSnapshot.exists) {
        List<dynamic> userList = roomSnapshot.get('users') ?? [];
        if (!userList.contains(username)) {
          userList.add(username);
          transaction.update(roomRef, {'users': userList, 'currentUsers': userList.length});
        }
      }
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = users.length <= 2
                ? 2
                : users.length <= 4
                    ? 2
                    : 3;

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: users.length > 4 ? 1 : 1.2,
              ),
              itemCount: users.length,
              itemBuilder: (context, index) {
                return _buildUserTile(users[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserTile(String username) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              username[0].toUpperCase(),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            username,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
