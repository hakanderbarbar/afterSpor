import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'screens/chatroom_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? favoriteTeam = prefs.getString('favorite_team');

  runApp(MyApp(startScreen: favoriteTeam == null ? const OnboardingScreen() : const ChatRoomSelectionScreen()));
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'After Spor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: startScreen,
    );
  }
}
