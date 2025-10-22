import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:mindlink/screens/welcome_screen.dart';
import 'package:mindlink/screens/login_screen.dart';
import 'package:mindlink/screens/registration_screen.dart';
import 'package:mindlink/screens/chat_screen.dart';
import 'package:mindlink/screens/focus_mode_screen.dart';
import 'package:mindlink/services/focus_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize notifications

  runApp(MindLink());
}

class MindLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FocusService(),
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.black54),
          ),
        ),
        initialRoute: WelcomeScreen.id,
        routes: {
          WelcomeScreen.id: (context) => WelcomeScreen(),
          LoginScreen.id: (context) => LoginScreen(),
          RegistrationScreen.id: (context) => RegistrationScreen(),
          ChatScreen.id: (context) => ChatScreen(),
          FocusModeScreen.id: (context) => FocusModeScreen(),
        },
      ),
    );
  }
}
