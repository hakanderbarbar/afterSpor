import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:after_spor/webRTC/WebRTCManager.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final int maxUsers;
  final bool isAdmin;

  const VoiceRoomScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.maxUsers,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _VoiceRoomScreenState createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  MediaStream? _localStream;
  String? currentUserId;
  String? currentUsername;
  List<String> users = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeWebRTC();
    _loadUsers();
    _listenForRoomDeletion();  // 👈 NEU: Überwacht, ob der Raum gelöscht wird

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
          currentUsername = userDoc['username'];
        });
      }
    }
  }

  Future<void> _initializeWebRTC() async {
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
    setState(() {});
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

  void _listenForRoomDeletion() {
  _firestore.collection('chatrooms').doc(widget.roomId).snapshots().listen((snapshot) {
    if (!snapshot.exists) {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst); // Bringt User zur RoomList zurück
      }
    }
  });
}


Future<void> _leaveRoom() async {
  if (currentUsername == null) return;

  DocumentReference roomRef = _firestore.collection('chatrooms').doc(widget.roomId);

  await roomRef.update({
    'users': FieldValue.arrayRemove([currentUsername]),
    'currentUsers': FieldValue.increment(-1), 
  });

  if (mounted) {
    Navigator.pop(context); 
  }
}


Future<void> _closeRoom() async {
  DocumentReference roomRef = _firestore.collection('chatrooms').doc(widget.roomId);

  // Hole alle Nutzer aus dem Raum
  DocumentSnapshot roomSnapshot = await roomRef.get();
  if (roomSnapshot.exists) {
    List<dynamic> userList = roomSnapshot.get('users') ?? [];

    // Entferne alle Nutzer
    for (String user in userList) {
      await _firestore.collection('users').doc(user).update({
        'currentRoom': null, 
      });
    }
  }

  // Raum löschen
  await roomRef.delete();
}



  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!widget.isAdmin) {
          await _leaveRoom();
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.roomName),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: widget.isAdmin
              ? [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () async {
                      await _closeRoom();
                      Navigator.pop(context);
                    },
                  ),
                ]
              : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              if (_localStream != null) Text("Du bist verbunden"),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(users[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!widget.isAdmin) {
      _leaveRoom();
    }
    _localStream?.dispose();
    super.dispose();
  }
}
