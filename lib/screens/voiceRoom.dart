import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:after_spor/webRTC/WebRTCManager.dart';


class VoiceRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final int maxUsers;

  const VoiceRoomScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.maxUsers,
  }) : super(key: key);

  @override
  _VoiceRoomScreenState createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, RTCPeerConnection> _peerConnections = {}; // Verbindungen zu anderen Benutzern
  final Map<String, MediaStream> _remoteStreams = {}; // Remote-Streams anderer Benutzer
  MediaStream? _localStream; // Lokaler Audio-Stream
  String? currentUserId;
  String? currentUsername;
  List<String> users = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeWebRTC();
    _loadUsers();
    _listenForSignals();
  }

  // Benutzerdaten laden
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

  // WebRTC initialisieren
  Future<void> _initializeWebRTC() async {
    // Lokalen Audio-Stream erstellen
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
    setState(() {});
  }

  // Benutzerliste aus Firestore laden
  void _loadUsers() {
    _firestore.collection('chatrooms').doc(widget.roomId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        List<dynamic> userList = snapshot.get('users') ?? [];
        setState(() {
          users = List<String>.from(userList);
        });

        // Neue Peer-Verbindungen für neue Benutzer erstellen
        for (var user in userList) {
          if (user != currentUserId && !_peerConnections.containsKey(user)) {
            _createPeerConnection(user);
          }
        }
      }
    });
  }

  // Neue Peer-Verbindung erstellen
  Future<void> _createPeerConnection(String remoteUserId) async {
    final peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    // Lokalen Stream hinzufügen
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        peerConnection.addTrack(track, _localStream!);
      });
    }

    // ICE-Kandidaten empfangen und an Firestore senden
    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      _firestore.collection('chatrooms').doc(widget.roomId).collection('signals').add({
        'type': 'ice',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'senderId': currentUserId,
        'receiverId': remoteUserId,
      });
    };

    // Remote-Stream empfangen
    peerConnection.onAddStream = (MediaStream stream) {
      setState(() {
        _remoteStreams[remoteUserId] = stream;
      });
    };

    // Offer erstellen und an Firestore senden
    final offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    _firestore.collection('chatrooms').doc(widget.roomId).collection('signals').add({
      'type': 'offer',
      'sdp': offer.sdp,
      'senderId': currentUserId,
      'receiverId': remoteUserId,
    });

    // PeerConnection speichern
    _peerConnections[remoteUserId] = peerConnection;
  }

  // Signalisierung über Firestore
  void _listenForSignals() {
    _firestore.collection('chatrooms').doc(widget.roomId).collection('signals').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];

        // Ignoriere eigene Signale und Signale, die nicht für diesen Benutzer bestimmt sind
        if (senderId != currentUserId && (receiverId == currentUserId || receiverId == null)) {
          if (data['type'] == 'offer') {
            _handleOffer(senderId, data['sdp']);
          } else if (data['type'] == 'answer') {
            _handleAnswer(senderId, data['sdp']);
          } else if (data['type'] == 'ice') {
            _handleIceCandidate(senderId, RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ));
          }
        }
      }
    });
  }

  // Offer verarbeiten
  Future<void> _handleOffer(String remoteUserId, String sdp) async {
    final peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    // Lokalen Stream hinzufügen
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        peerConnection.addTrack(track, _localStream!);
      });
    }

    // Remote-Description setzen
    await peerConnection.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

    // Answer erstellen und an Firestore senden
    final answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    _firestore.collection('chatrooms').doc(widget.roomId).collection('signals').add({
      'type': 'answer',
      'sdp': answer.sdp,
      'senderId': currentUserId,
      'receiverId': remoteUserId,
    });

    // PeerConnection speichern
    _peerConnections[remoteUserId] = peerConnection;
  }

  // Answer verarbeiten
  Future<void> _handleAnswer(String remoteUserId, String sdp) async {
    final peerConnection = _peerConnections[remoteUserId];
    if (peerConnection != null) {
      await peerConnection.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    }
  }

  // ICE-Kandidaten verarbeiten
  Future<void> _handleIceCandidate(String remoteUserId, RTCIceCandidate candidate) async {
    final peerConnection = _peerConnections[remoteUserId];
    if (peerConnection != null) {
      await peerConnection.addCandidate(candidate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Lokaler Stream (dein Mikrofon)
            if (_localStream != null)
              Text("Du bist verbunden"),

            // Remote-Streams anderer Benutzer
            for (var entry in _remoteStreams.entries)
              Text("${entry.key} ist verbunden"),

            // Benutzerliste anzeigen
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
    );
  }

  @override
  void dispose() {
    // Verbindungen und Streams schließen
    for (var pc in _peerConnections.values) {
      pc.close();
    }
    _localStream?.dispose();
    super.dispose();
  }
}