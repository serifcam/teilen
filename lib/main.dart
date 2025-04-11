import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:teilen2/screens/authenticate/login_screen.dart';
import 'package:teilen2/screens/settingScreen/settings_screen.dart';
import 'package:teilen2/screens/settingScreen/notification_settings_screen.dart';
import 'package:teilen2/screens/mainScreen/main_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 Arkaplanda mesaj alındı: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _initFirebaseMessaging();
  }

  void _initFirebaseMessaging() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('📱 Bildirim izni verildi');

      String? token = await _firebaseMessaging.getToken();
      print('📬 Kullanıcı FCM Token: $token');

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'notificationsEnabled': true, // ✅ Genel bildirim
          'individualDebtEnabled': true, // ✅ Bireysel borç
          'groupDebtEnabled': true, // ✅ Grup borcu
          'friendRequestEnabled': true, // ✅ Arkadaşlık isteği
          'debtPaidEnabled': true, // ✅ Borç ödendi bildirimi
        }, SetOptions(merge: true));
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📥 Foreground mesaj: ${message.notification?.title}');
        if (message.notification != null) {
          final snackBar = SnackBar(
            content: Text(
              '${message.notification!.title ?? 'Bildirim'} - '
              '${message.notification!.body ?? ''}',
            ),
            duration: Duration(seconds: 5),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      });
    } else {
      print('🚫 Bildirim izni reddedildi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Borç Takip Uygulaması',
      theme: ThemeData(primarySwatch: Colors.teal),
      initialRoute:
          FirebaseAuth.instance.currentUser == null ? '/auth' : '/main',
      routes: {
        '/auth': (context) => LoginScreen(),
        '/main': (context) => MainScreen(),
        '/settings': (context) => SettingsScreen(),
        '/notification-settings': (context) => NotificationSettingsScreen(),
      },
    );
  }
}
