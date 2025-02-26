import 'package:flutter/material.dart';
import 'dart:async'; // Für Timer

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:after_spor/webRTC/WebRTCManager.dart';
import 'package:permission_handler/permission_handler.dart'; // Permission Handler importieren

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
  late final WebRTCManager _webRTCManager;

  String? currentUserId;
  String? currentUsername;
  List<String> users = [];
  bool isConnected = false;
  bool _isSpeaking = false; // Lokaler Benutzer spricht
  Map<String, bool> _remoteSpeakingStatus = {}; // Remote-Benutzer sprechen

  @override
  void initState() {
    super.initState();
    _webRTCManager = WebRTCManager(roomId: widget.roomId);
    _loadUserData();
    _initializeWebRTC();
    _listenForRoomDeletion();
    _startAudioLevelMonitoring(); // Audio-Level-Überwachung starten
  }

  // Methode zur Anforderung der Mikrofon-Berechtigung
  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (status.isDenied) {
      throw Exception('Mikrofon-Berechtigung wurde verweigert');
    }
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
    try {
      // Berechtigung anfordern, bevor getUserMedia aufgerufen wird
      await _requestMicrophonePermission();

      await _webRTCManager.initialize(); // WebRTC initialisieren
      setState(() {
        isConnected = true;
      });
      print('WebRTC erfolgreich initialisiert');

      // Signalisierungslistener starten
      _firestore.collection('chatrooms').doc(widget.roomId).collection('calls')
        .snapshots().listen((snapshot) {
          for (var doc in snapshot.docs) {
            String userId = doc.id;
            if (userId != currentUserId) {
              Map<String, dynamic> data = doc.data();
              if (data.containsKey('offer')) {
                _webRTCManager.handleOffer(userId, data['offer']);
              }
              if (data.containsKey('answer')) {
                _webRTCManager.handleAnswer(userId, data['answer']);
              }
            }
          }
        });

      // ICE-Kandidaten Listener
      _firestore.collection('chatrooms').doc(widget.roomId).collection('calls')
        .get().then((querySnapshot) {
          for (var doc in querySnapshot.docs) {
            String userId = doc.id;
            _firestore.collection('chatrooms').doc(widget.roomId)
                .collection('calls').doc(userId)
                .collection('iceCandidates').snapshots().listen((candidateSnapshot) {
                  for (var candidateDoc in candidateSnapshot.docs) {
                    _webRTCManager.addCandidate(userId, candidateDoc.data());
                  }
                });
          }
        });
    } catch (e) {
      print('Fehler bei der WebRTC-Initialisierung: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Mikrofon-Zugriff: $e')),
      );
    }
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
    print('Raum verlassen: $currentUsername');

    DocumentReference roomRef = _firestore.collection('chatrooms').doc(widget.roomId);

    await roomRef.update({
      'users': FieldValue.arrayRemove([currentUsername]),
      'currentUsers': FieldValue.increment(-1),
    });

    // Beende die WebRTC Verbindung
    _webRTCManager.closeConnection(currentUserId!);
    _webRTCManager.localStream?.dispose();

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

      // Entferne alle Nutzer aus ihren aktuellen Räumen
      for (String user in userList) {
        await _firestore.collection('users').doc(user).update({
          'currentRoom': null,
        });
      }
    }

    // Raum löschen
    await roomRef.delete();
  }

  // Methode zur Überwachung der Sprachaktivität
  void _startAudioLevelMonitoring() {
    Timer.periodic(Duration(milliseconds: 500), (timer) async {
      await _checkAudioLevels();
    });
  }

  // Methode zur Überprüfung der Audio-Level
  Future<void> _checkAudioLevels() async {
    // Lokale Audio-Level überprüfen
    if (_webRTCManager.localStream != null) {
      for (var track in _webRTCManager.localStream!.getAudioTracks()) {
        var stats = await _webRTCManager.getTrackStats(track);
        if (stats != null && stats.containsKey('audioLevel')) {
          double audioLevel = stats['audioLevel'];
          setState(() {
            _isSpeaking = audioLevel > 0.1; // Schwellenwert für Sprachaktivität
          });
        }
      }
    }

    // Remote Audio-Level überprüfen
    _webRTCManager.remoteStreams.forEach((userId, stream) {
      for (var track in stream.getAudioTracks()) {
        _webRTCManager.getTrackStats(track).then((stats) {
          if (stats != null && stats.containsKey('audioLevel')) {
            double audioLevel = stats['audioLevel'];
            setState(() {
              _remoteSpeakingStatus[userId] = audioLevel > 0.1; // Schwellenwert für Sprachaktivität
            });
          }
        });
      }
    });
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
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _leaveRoom();
            },
          ),
          actions: widget.isAdmin
              ? [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await _closeRoom();
                    },
                  ),
                ]
              : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              if (_webRTCManager.localStream != null && isConnected)
                const Text("Du bist verbunden", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _firestore.collection('chatrooms').doc(widget.roomId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var data = snapshot.data!;
                    List<dynamic> userList = data['users'] ?? [];

                    return ListView.builder(
                      itemCount: userList.length,
                      itemBuilder: (context, index) {
                        final userId = userList[index];
                        final isRemoteSpeaking = _remoteSpeakingStatus[userId] ?? false;
                        final isLocalUser = userId == currentUserId;

                        return ListTile(
                          title: Text(userList[index], style: const TextStyle(fontSize: 18)),
                          leading: Icon(
                            isLocalUser ? Icons.mic : Icons.volume_up,
                            color: (isLocalUser && _isSpeaking) || (!isLocalUser && isRemoteSpeaking)
                                ? Colors.green
                                : Colors.grey,
                          ),
                        );
                      },
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
}