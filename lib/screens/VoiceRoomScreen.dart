import 'package:flutter/material.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String roomName;
  final int maxUsers;
  final List<String> users;

  const VoiceRoomScreen({
    super.key,
    required this.roomName,
    required this.maxUsers,
    required this.users,
  });

  @override
  _VoiceRoomScreenState createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> with TickerProviderStateMixin {
  late Map<String, AnimationController> _animationControllers;
  late Map<String, Animation<double>> _animations;
  late Map<String, bool> speakingStatus;

  @override
  void initState() {
    super.initState();

    // Initialisiere Animationen und Sprechstatus für jeden Benutzer
    _animationControllers = {};
    _animations = {};
    speakingStatus = {};

    for (var user in widget.users) {
      speakingStatus[user] = false;

      _animationControllers[user] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );

      _animations[user] = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animationControllers[user]!,
          curve: Curves.easeInOut,
        ),
      )..addListener(() {
          setState(() {});
        });
    }
  }

  void _startSpeaking(String user) {
    setState(() {
      speakingStatus[user] = true;
    });
    _animationControllers[user]!.repeat(reverse: true);
  }

  void _stopSpeaking(String user) {
    setState(() {
      speakingStatus[user] = false;
    });
    _animationControllers[user]!.stop();
  }

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Raum: ${widget.roomName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildUserGrid(),
          ),
          _buildSpeakingControls(),
        ],
      ),
    );
  }

  Widget _buildUserGrid() {
    int userCount = widget.users.length;
    int columns = userCount <= 2 ? 1 : 2;
    int rows = (userCount / columns).ceil();

    return GridView.count(
      crossAxisCount: columns,
      childAspectRatio: 1.0,
      children: widget.users.map((user) {
        return _buildUserBox(user, speakingStatus[user] ?? false);
      }).toList(),
    );
  }

  Widget _buildUserBox(String user, bool isSpeaking) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSpeaking)
              AnimatedBuilder(
                animation: _animations[user]!,
                builder: (context, child) {
                  return Container(
                    width: 100 + (_animations[user]!.value * 20),
                    height: 100 + (_animations[user]!.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.5),
                        width: 2 + (_animations[user]!.value * 4),
                      ),
                    ),
                  );
                },
              ),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              child: Text(
                user[0].toUpperCase(),
                style: const TextStyle(fontSize: 30, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 10,
              child: Text(
                user,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakingControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: widget.users.map((user) {
          return ElevatedButton(
            onPressed: () {
              if (speakingStatus[user]!) {
                _stopSpeaking(user);
              } else {
                _startSpeaking(user);
              }
            },
            child: Text(speakingStatus[user]! ? 'Stop $user' : 'Start $user'),
          );
        }).toList(),
      ),
    );
  }
}