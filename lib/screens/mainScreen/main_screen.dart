import 'package:flutter/material.dart';
import 'package:teilen2/screens/settingScreen/settings_screen.dart';
import '../individualScreen/individual_debt_screen.dart';
import 'package:teilen2/screens/friendScreen/friends_screen.dart';
import '../groupScreen/group_expense_screen.dart';
import '../notificationScreen/notification_screen.dart'; // Bildirim ekranını import ettim
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    FriendsScreen(), // Arkadaşlarım (FriendsScreen olarak güncellendi)
    SettingsScreen(), // Ayarlar
  ];

  @override
  void initState() {
    super.initState();
    _checkNotifications();
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
      _hasNotifications = false; // Bildirime tıklandığında renk normale döner
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
        backgroundColor: Colors.grey[900], // Navigation bar rengini ayarla
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
        selectedItemColor: Colors.tealAccent, // Seçili ikonun rengi
        unselectedItemColor: Colors.white70, // Seçili olmayan ikonların rengi
        type: BottomNavigationBarType.fixed, // Düzgün görünmesi için sabit tür
      ),
    );
  }
}
