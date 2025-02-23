import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'VoiceRoomScreen.dart';

class ChatRoomSelectionScreen extends StatefulWidget {
  const ChatRoomSelectionScreen({super.key});

  @override
  _ChatRoomSelectionScreenState createState() => _ChatRoomSelectionScreenState();
}

class _ChatRoomSelectionScreenState extends State<ChatRoomSelectionScreen> {
  String? favoriteTeam;
  String? currentUserId;
  String? currentUsername;
  bool isAdmin = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        currentUserId = user.uid;
      });
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          favoriteTeam = userDoc['favorite_team'];
          currentUsername = userDoc['username'];
        });
      }
      _checkAdminStatus();
    }
  }

  Future<void> _checkAdminStatus() async {
    QuerySnapshot roomSnapshot = await _firestore
        .collection('chatrooms')
        .where('adminId', isEqualTo: currentUserId)
        .get();
    setState(() {
      isAdmin = roomSnapshot.docs.isNotEmpty;
    });
  }

  void _createNewChatRoom() async {
    if (isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du bist bereits Admin in einem Raum.')),
      );
      return;
    }

    TextEditingController nameController = TextEditingController();
    TextEditingController maxUsersController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Neuen VoiceRoom erstellen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Raumnamen eingeben'),
              ),
              TextField(
                controller: maxUsersController,
                decoration: const InputDecoration(hintText: 'Max. Benutzeranzahl'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && maxUsersController.text.isNotEmpty) {
                  await _firestore.collection('chatrooms').add({
                    'name': nameController.text,
                    'team': favoriteTeam,
                    'admin': currentUsername,
                    'adminId': currentUserId,
                    'currentUsers': 1,
                    'maxUsers': int.parse(maxUsersController.text),
                    'users': [currentUsername], // Admin wird als erster Nutzer hinzugefügt
                  });
                  setState(() {
                    isAdmin = true;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );
  }

Future<bool> _joinRoom(String roomId) async {
  User? user = _auth.currentUser;
  if (user == null) return false;

  DocumentReference roomRef = _firestore.collection('chatrooms').doc(roomId);

  try {
    return await _firestore.runTransaction((transaction) async {
      DocumentSnapshot roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) return false;

      List<dynamic> userList = List.from(roomSnapshot.get('users') ?? []);
      int currentUsers = roomSnapshot.get('currentUsers');
      int maxUsers = roomSnapshot.get('maxUsers');

      if (currentUsers >= maxUsers) {
        return false; // ❌ Raum ist voll, Abbruch!
      }

      if (!userList.contains(currentUsername)) {
        userList.add(currentUsername);
        transaction.update(roomRef, {
          'users': userList,
          'currentUsers': userList.length,
        });
      }
      return true; // ✅ Erfolgreich beigetreten!
    });
  } catch (error) {
    return false;
  }
}





  void _leaveRoom() async {
    QuerySnapshot roomSnapshot = await _firestore
        .collection('chatrooms')
        .where('adminId', isEqualTo: currentUserId)
        .get();

    for (var doc in roomSnapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      isAdmin = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Du hast den Raum verlassen und bist nicht mehr Admin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chatrooms für $favoriteTeam'),
      ),
      body: StreamBuilder(
        stream: _firestore.collection('chatrooms').where('team', isEqualTo: favoriteTeam).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var chatRooms = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              var room = chatRooms[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(room['name']),
                  subtitle: Text('Admin: ${room['admin']}'),
                  trailing: Text('${room['currentUsers']}/${room['maxUsers']}'),
onTap: () async {
  bool joined = await _joinRoom(room.id);
  if (joined) {  // Nur navigieren, wenn erfolgreich beigetreten
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceRoomScreen(
          roomId: room.id,
          roomName: room['name'],
          maxUsers: room['maxUsers'],
        ),
      ),
    );
  }
}
,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isAdmin ? null : _createNewChatRoom,
        tooltip: 'Neuen VoiceRoom erstellen',
        child: const Icon(Icons.add, size: 40),
      ),
      bottomNavigationBar: isAdmin
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _leaveRoom,
                child: const Text('Raum verlassen'),
              ),
            )
          : null,
    );
  }
}
