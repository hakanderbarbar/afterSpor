import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Erstelle eine Peer-Verbindung
Future<RTCPeerConnection> createPeerConnection() async {
  // Konfiguration für den Peer-Connection-Builder
  Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}, // STUN-Server für NAT-Traversal
    ]
  };

  // Erstelle eine Peer-Verbindung
  _peerConnection = await createPeerConnection();

  // ICE-Kandidaten empfangen und an den anderen Peer senden
  _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
    print("ICE-Kandidat empfangen: ${candidate.candidate}");
    // Hier den Kandidaten an den anderen Peer senden (z. B. über Firestore)
  };

  // Remote-Stream empfangen
  _peerConnection!.onAddStream = (MediaStream stream) {
    _remoteStream = stream;
    print("Remote-Stream empfangen");
  };

  return _peerConnection!;
}



  // Erstelle ein Angebot (Offer) für die Verbindung
  Future<RTCSessionDescription> createOffer(RTCPeerConnection peerConnection) async {
    final offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    print("Offer erstellt: ${offer.sdp}");
    return offer;
  }

  // Erstelle eine Antwort (Answer) auf ein Offer
  Future<RTCSessionDescription> createAnswer(RTCPeerConnection peerConnection) async {
    final answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    print("Answer erstellt: ${answer.sdp}");
    return answer;
  }

  // Setze das Remote-Description (Offer oder Answer)
  Future<void> setRemoteDescription(RTCPeerConnection peerConnection, RTCSessionDescription description) async {
    await peerConnection.setRemoteDescription(description);
    print("Remote-Description gesetzt");
  }

  // Füge ICE-Kandidaten hinzu
  Future<void> addIceCandidate(RTCPeerConnection peerConnection, RTCIceCandidate candidate) async {
    await peerConnection.addCandidate(candidate);
    print("ICE-Kandidat hinzugefügt");
  }

  // Mikrofonzugriff anfordern
  Future<MediaStream> getUserMedia() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true, // Nur Audio (kein Video)
    });
    print("Lokaler Stream erstellt");
    return _localStream!;
  }

  // Getter für die Streams
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  // Verbindung schließen
  void dispose() {
    _peerConnection?.close();
    _localStream?.dispose();
    _remoteStream?.dispose();
  }
}