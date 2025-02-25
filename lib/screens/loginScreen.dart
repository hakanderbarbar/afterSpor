import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'roomList.dart';
import 'userName.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';
  bool isLoading = false;

  Future<void> _login() async {
    setState(() => isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatRoomSelectionScreen()),
      );
    } catch (e) {
      setState(() => errorMessage = "Login fehlgeschlagen: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _register() async {
    setState(() => isLoading = true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => UsernameScreen()),
      );
    } catch (e) {
      setState(() => errorMessage = "Registrierung fehlgeschlagen: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/login.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset("assets/login.png", height: 80),
                  SizedBox(height: 10),
                  Text(
                    "Fußballfans vereint!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Passwort",
                      prefixIcon: Icon(Icons.lock, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (errorMessage.isNotEmpty)
                    AnimatedOpacity(
                      opacity: errorMessage.isNotEmpty ? 1.0 : 0.0,
                      duration: Duration(milliseconds: 500),
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  SizedBox(height: 10),
                  isLoading
                      ? SpinKitFadingCircle(color: Colors.green, size: 50)
                      : Column(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 50),
                              ),
                              onPressed: _login,
                              child: Text("Login", style: TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                            SizedBox(height: 10),
                            TextButton(
                              onPressed: _register,
                              child: Text("Noch kein Konto? Registrieren", style: TextStyle(color: Colors.green)),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
