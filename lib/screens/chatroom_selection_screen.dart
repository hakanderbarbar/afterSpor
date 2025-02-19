import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart'; // Importiere das OnboardingScreen

class ChatRoomSelectionScreen extends StatefulWidget {
  const ChatRoomSelectionScreen({super.key});

  @override
  _ChatRoomSelectionScreenState createState() =>
      _ChatRoomSelectionScreenState();
}

class _ChatRoomSelectionScreenState extends State<ChatRoomSelectionScreen> {
  String? favoriteTeam;
  List<Map<String, dynamic>> chatRooms = [
    {
      'name': 'Gala Aslanlar',
      'team': 'Galatasaray',
      'admin': 'User5',
      'currentUsers': 4,
      'maxUsers': 4,
    },
    {
      'name': 'Fenerbahçe Söhbet',
      'team': 'Fenerbahçe',
      'admin': 'User6',
      'currentUsers': 2,
      'maxUsers': 6,
    },
  ];

  List<Map<String, dynamic>> filteredChatRooms = [];
  String? currentUser; // Der aktuelle Benutzer, der die App verwendet
  bool isAdmin = false; // Gibt an, ob der Benutzer bereits Admin ist

  @override
  void initState() {
    super.initState();
    _loadFavoriteTeam();
    _loadCurrentUser();
    _checkAdminStatus();
  }

  Future<void> _loadFavoriteTeam() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteTeam = prefs.getString('favorite_team');
      filteredChatRooms =
          chatRooms.where((room) => room['team'] == favoriteTeam).toList();
    });
  }

  Future<void> _loadCurrentUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUser = prefs.getString('current_user');
    });
  }

  Future<void> _checkAdminStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isAdmin = prefs.getBool('is_admin') ?? false;
    });
  }

  void _createNewChatRoom() async {
    if (isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du bist bereits Admin in einem Raum.')),
      );
      return;
    }

    TextEditingController _nameController = TextEditingController();
    TextEditingController _maxUsersController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Neuen Chatraum erstellen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Raumnamen eingeben',
                ),
              ),
              TextField(
                controller: _maxUsersController,
                decoration: const InputDecoration(
                  hintText: 'Maximale Benutzeranzahl',
                ),
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
                if (_nameController.text.isNotEmpty &&
                    _maxUsersController.text.isNotEmpty) {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setBool('is_admin', true);

                  setState(() {
                    chatRooms.add({
                      'name': _nameController.text,
                      'team': favoriteTeam!,
                      'admin': currentUser,
                      'currentUsers': 1, // Der Ersteller ist der erste Benutzer
                      'maxUsers': int.parse(_maxUsersController.text),
                    });
                    filteredChatRooms.add({
                      'name': _nameController.text,
                      'team': favoriteTeam!,
                      'admin': currentUser,
                      'currentUsers': 1,
                      'maxUsers': int.parse(_maxUsersController.text),
                    });
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

  Future<void> _goBackToOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('favorite_team');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  void _leaveRoom() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_admin', false);

    setState(() {
      isAdmin = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Du hast den Raum verlassen und bist nicht mehr Admin.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chatrooms für $favoriteTeam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackToOnboarding,
            tooltip: 'Zurück zum Onboarding',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: filteredChatRooms.length,
              itemBuilder: (context, index) {
                final room = filteredChatRooms[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    title: Text(room['name']!),
                    subtitle: Text('Admin: ${room['admin']}'),
                    trailing: Text(
                      '${room['currentUsers']}/${room['maxUsers']}',
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FloatingActionButton(
              onPressed: isAdmin ? null : _createNewChatRoom,
              child: const Icon(Icons.add, size: 40),
              tooltip: 'Neuen Chatraum erstellen',
            ),
          ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _leaveRoom,
                child: const Text('Raum verlassen'),
              ),
            ),
        ],
      ),
    );
  }
}
