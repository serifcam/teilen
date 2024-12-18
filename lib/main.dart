import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/group_expense_screen.dart'; // Yeni ekran eklendi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Debug yazısını kaldırır
      title: 'Borç Takip Uygulaması',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: AuthWrapper(),
      routes: {
        '/auth': (context) => AuthScreen(),
        '/group-expense': (context) => GroupExpenseScreen(), // Yeni route
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasData) {
          return MainScreen(); // Navigation Bar'lı Ana Sayfa
        } else {
          return AuthScreen(); // Giriş ekranına yönlendir
        }
      },
    );
  }
}
