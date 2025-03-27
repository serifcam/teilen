import 'package:flutter/material.dart';
import 'package:teilen2/screens/settingScreen/settings_screen.dart';
import '../individualScreen/individual_debt_screen.dart';
import 'package:teilen2/screens/friendScreen/friends_screen.dart';
import '../groupScreen/group_expense_screen.dart';
import '../notificationScreen/notification_screen.dart'; // Bildirim ekranını import ettim
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🔥 FCM eklendi

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _hasNotifications = false; // Yeni bildirim durumu

  final List<Widget> _pages = [
    IndividualDebtScreen(), // Bireysel Borç Takibi
    GroupExpenseScreen(), // Grup Harcamaları
    FriendsScreen(), // Arkadaşlarım
    SettingsScreen(), // Ayarlar
  ];

  @override
  void initState() {
    super.initState();
    _checkNotifications();
    _registerFcmToken(); // ✅ Token'ı Firestore'a kaydet
  }

  // 🔐 FCM token'ı al ve Firestore'a kaydet
  void _registerFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        print('📬 Token Firestore\'a kaydedildi: $token');
      }
    }
  }

  void _checkNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .where('toUser', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _hasNotifications = snapshot.docs.isNotEmpty;
        });
      });
    }
  }

  void _onNotificationTapped() {
    setState(() {
      _hasNotifications = false;
    });
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => NotificationScreen()),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.paid, color: Colors.tealAccent, size: 28),
            SizedBox(width: 8),
            Text(
              'Teilen',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications,
              color: _hasNotifications ? Colors.yellow : Colors.tealAccent,
            ),
            onPressed: _onNotificationTapped,
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.grey[900],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Borç Takibi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Grup Harcamaları',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Arkadaşlarım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
