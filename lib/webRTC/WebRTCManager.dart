import 'dart:async'; // Für Timer
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebRTCManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String roomId;
  Map<String, RTCPeerConnection> _peerConnections = {};
  Map<String, MediaStream> remoteStreams =
      {}; // Öffentliche Map für Remote-Streams
  MediaStream? localStream; // Von _localStream zu localStream geändert

  // Timer für die Überwachung der Audio-Level
  Timer? _audioLevelTimer;

  WebRTCManager({required this.roomId});

  Future<void> initialize() async {
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      print('Lokaler Stream erstellt: Audio aktiv');
      _listenForWebRTCSignals();
      _startAudioLevelMonitoring(); // Audio-Level-Überwachung starten
    } catch (e) {
      print('Fehler beim Erstellen des lokalen Streams: $e');
    }
  }

  // Methode zur Überwachung der Audio-Level
  void _startAudioLevelMonitoring() {
    _audioLevelTimer = Timer.periodic(Duration(milliseconds: 500), (
      timer,
    ) async {
      await _checkAudioLevels();
    });
  }

  // Methode zur Überprüfung der Audio-Level
  Future<void> _checkAudioLevels() async {
    // Lokale Audio-Level überprüfen
    if (localStream != null) {
      for (var track in localStream!.getAudioTracks()) {
        var stats = await getTrackStats(track);
        if (stats != null && stats.containsKey('audioLevel')) {
          double audioLevel = stats['audioLevel'];
          print('Lokaler Audio-Level: $audioLevel');
        }
      }
    }

    // Remote Audio-Level überprüfen
    remoteStreams.forEach((userId, stream) {
      for (var track in stream.getAudioTracks()) {
        getTrackStats(track).then((stats) {
          if (stats != null && stats.containsKey('audioLevel')) {
            double audioLevel = stats['audioLevel'];
            print('Remote Audio-Level von $userId: $audioLevel');
          }
        });
      }
    });
  }

  Future<Map<String, dynamic>?> getTrackStats(MediaStreamTrack track) async {
    try {
      // Verwenden Sie die PeerConnection, um die Statistiken abzurufen
      for (var pc in _peerConnections.values) {
        var stats = await pc.getStats();
        for (var report in stats) {
          if (report.type == 'track' && report.id == track.id) {
            // Umwandeln der values-Map in Map<String, dynamic>
            return report.values.cast<String, dynamic>();
          }
        }
      }
    } catch (e) {
      print('Fehler beim Abrufen der Statistiken: $e');
    }
    return null;
  }

  Future<RTCPeerConnection> _createPeerConnection(String userId) async {
    try {
      Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

      final peerConnection = await createPeerConnection(configuration);
      print('PeerConnection für $userId erstellt');

      peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
        print('ICE-Kandidat für $userId gefunden: ${candidate.toMap()}');
        _sendIceCandidate(userId, candidate);
      };

      peerConnection.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          remoteStreams[userId] = event.streams[0]; // Remote-Stream speichern
          print('Remote Stream von $userId empfangen: Audio aktiv');
        }
      };

      peerConnection.onIceConnectionState = (RTCIceConnectionState state) {
        print('ICE-Verbindungsstatus für $userId: $state');
      };

      peerConnection.onConnectionState = (RTCPeerConnectionState state) {
        print('Peer-Verbindungsstatus für $userId: $state');
      };

      if (localStream != null) {
        localStream!.getTracks().forEach((track) {
          peerConnection.addTrack(track, localStream!);
          print('Lokaler Track zu PeerConnection für $userId hinzugefügt');
        });
      }

      _peerConnections[userId] = peerConnection;
      return peerConnection;
    } catch (e) {
      print('Fehler beim Erstellen der PeerConnection für $userId: $e');
      rethrow;
    }
  }

  void _sendIceCandidate(String userId, RTCIceCandidate candidate) {
    try {
      _firestore
          .collection('chatrooms')
          .doc(roomId)
          .collection('candidates')
          .add({'userId': userId, 'candidate': candidate.toMap()});
      print('ICE-Kandidat für $userId an Firestore gesendet');
    } catch (e) {
      print('Fehler beim Senden des ICE-Kandidaten für $userId: $e');
    }
  }

  Future<MediaStream> getUserMedia() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      print('Lokaler Stream erfolgreich abgerufen');
      return stream;
    } catch (e) {
      print('Fehler beim Abrufen des lokalen Streams: $e');
      rethrow;
    }
  }

  Future<void> createAndSendOffer(String userId) async {
    try {
      final peerConnection = await _createPeerConnection(userId);
      RTCSessionDescription offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      print('Offer für $userId erstellt und lokal gesetzt');

      _firestore.collection('chatrooms').doc(roomId).collection('offers').add({
        'userId': userId,
        'offer': offer.toMap(),
      });
      print('Offer für $userId an Firestore gesendet');
    } catch (e) {
      print('Fehler beim Erstellen und Senden des Offers für $userId: $e');
    }
  }

  Future<void> createAndSendAnswer(
    String userId,
    RTCSessionDescription offer,
  ) async {
    try {
      final peerConnection = await _createPeerConnection(userId);
      await peerConnection.setRemoteDescription(offer);
      RTCSessionDescription answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      print('Answer für $userId erstellt und lokal gesetzt');

      _firestore.collection('chatrooms').doc(roomId).collection('answers').add({
        'userId': userId,
        'answer': answer.toMap(),
      });
      print('Answer für $userId an Firestore gesendet');
    } catch (e) {
      print('Fehler beim Erstellen und Senden des Answers für $userId: $e');
    }
  }

  Future<void> handleOffer(
    String senderId,
    Map<String, dynamic> offerData,
  ) async {
    try {
      RTCSessionDescription offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );
      print('Offer von $senderId empfangen: ${offer.toMap()}');

      final peerConnection = await _createPeerConnection(senderId);
      await peerConnection.setRemoteDescription(offer);
      print('Remote Description für $senderId gesetzt');

      RTCSessionDescription answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      print('Answer für $senderId erstellt und lokal gesetzt');

      _firestore.collection('chatrooms').doc(roomId).collection('answers').add({
        'userId': senderId,
        'answer': answer.toMap(),
      });
      print('Answer für $senderId an Firestore gesendet');
    } catch (e) {
      print('Fehler beim Verarbeiten des Offers von $senderId: $e');
    }
  }

  Future<void> handleAnswer(
    String senderId,
    Map<String, dynamic> answerData,
  ) async {
    try {
      RTCSessionDescription answer = RTCSessionDescription(
        answerData['sdp'],
        answerData['type'],
      );
      print('Answer von $senderId empfangen: ${answer.toMap()}');

      if (_peerConnections.containsKey(senderId)) {
        await _peerConnections[senderId]?.setRemoteDescription(answer);
        print('Remote Description für $senderId gesetzt');
      }
    } catch (e) {
      print('Fehler beim Verarbeiten des Answers von $senderId: $e');
    }
  }

  Future<void> addCandidate(
    String senderId,
    Map<String, dynamic> candidateData,
  ) async {
    try {
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      print('ICE-Kandidat von $senderId empfangen: ${candidate.toMap()}');

      if (_peerConnections.containsKey(senderId)) {
        await _peerConnections[senderId]?.addCandidate(candidate);
        print('ICE-Kandidat für $senderId hinzugefügt');
      }
    } catch (e) {
      print('Fehler beim Hinzufügen des ICE-Kandidaten von $senderId: $e');
    }
  }

  Future<void> closeConnection(String userId) async {
    try {
      if (_peerConnections.containsKey(userId)) {
        await _peerConnections[userId]?.close();
        _peerConnections.remove(userId);
        remoteStreams.remove(userId);
        print('Verbindung zu $userId geschlossen');
      }
    } catch (e) {
      print('Fehler beim Schließen der Verbindung zu $userId: $e');
    }
  }

  void _listenForWebRTCSignals() {
    _firestore
        .collection('chatrooms')
        .doc(roomId)
        .collection('offers')
        .snapshots()
        .listen((snapshot) {
          for (var doc in snapshot.docs) {
            String senderId = doc['userId'];
            if (!_peerConnections.containsKey(senderId)) {
              RTCSessionDescription offer = RTCSessionDescription(
                doc['offer']['sdp'],
                doc['offer']['type'],
              );
              createAndSendAnswer(senderId, offer);
            }
          }
        });

    _firestore
        .collection('chatrooms')
        .doc(roomId)
        .collection('answers')
        .snapshots()
        .listen((snapshot) {
          for (var doc in snapshot.docs) {
            String senderId = doc['userId'];
            if (_peerConnections.containsKey(senderId)) {
              RTCSessionDescription answer = RTCSessionDescription(
                doc['answer']['sdp'],
                doc['answer']['type'],
              );
              _peerConnections[senderId]?.setRemoteDescription(answer);
            }
          }
        });

    _firestore
        .collection('chatrooms')
        .doc(roomId)
        .collection('candidates')
        .snapshots()
        .listen((snapshot) {
          for (var doc in snapshot.docs) {
            String senderId = doc['userId'];
            if (_peerConnections.containsKey(senderId)) {
              RTCIceCandidate candidate = RTCIceCandidate(
                doc['candidate']['candidate'],
                doc['candidate']['sdpMid'],
                doc['candidate']['sdpMLineIndex'],
              );
              _peerConnections[senderId]?.addCandidate(candidate);
            }
          }
        });

    void dispose() {
      _audioLevelTimer?.cancel(); // Timer beenden
      _peerConnections.forEach((key, pc) async {
        await pc.close();
      });
      _peerConnections.clear();
      remoteStreams.clear();
      localStream?.dispose();
      print('WebRTCManager disposed');
    }
  }
}
