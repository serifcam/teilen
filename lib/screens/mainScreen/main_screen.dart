import 'package:flutter/material.dart';
import 'package:teilen2/screens/groupScreen/group_create_screen.dart';
import 'package:teilen2/screens/settingScreen/settings_screen.dart';
import '../individualScreen/individual_debt_screen.dart';
import 'package:teilen2/screens/friendScreen/friends_screen.dart';
import '../notificationScreen/notification_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 2025 style renkler
const _bgDark = Color(0xFF181A20); // Ana arka plan rengi
const _teal = Color(0xFF19D7B6); // Vurgu rengi
const _tealBg = Color(0xFF1F242C); // Kart/menü arka plan
const _yellow = Color(0xFFFFC93C); // Bildirim (badge)
const _textMuted = Color(0xFFA9B8C9); // Soluk yazı

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _hasNotifications = false;

  final List<Widget> _pages = [
    IndividualDebtScreen(),
    GroupCreateScreen(),
    FriendsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkNotifications();
    _registerFcmToken();
  }

  void _registerFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await userRef.get();
        final existingData = doc.data() ?? {};
        await userRef.set({
          'fcmToken': token,
          'XnotificationsEnabled':
              existingData['XnotificationsEnabled'] ?? true,
          'XindividualDebtEnabled':
              existingData['XindividualDebtEnabled'] ?? true,
          'XgroupDebtEnabled': existingData['XgroupDebtEnabled'] ?? true,
          'XfriendRequestEnabled':
              existingData['XfriendRequestEnabled'] ?? true,
          'XdebtPaidEnabled': existingData['XdebtPaidEnabled'] ?? true,
        }, SetOptions(merge: true));
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
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: _bgDark,
        appBar: AppBar(
          backgroundColor: _bgDark,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(7),
                child: Icon(Icons.paid, color: _teal, size: 26),
              ),
              SizedBox(width: 10),
              Text(
                'Teilen',
                style: TextStyle(
                  color: _teal,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontFamily: 'Nunito',
                  shadows: [
                    Shadow(
                      color: _teal.withOpacity(0.15),
                      blurRadius: 8,
                    )
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: _hasNotifications ? _yellow : _teal,
                    size: 28,
                  ),
                  onPressed: _onNotificationTapped,
                  tooltip: "Bildirimler",
                ),
                if (_hasNotifications)
                  Positioned(
                    right: 10,
                    top: 11,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _yellow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _bgDark, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 4),
          ],
        ),
        body: AnimatedSwitcher(
          duration: Duration(milliseconds: 220),
          child: _pages[_selectedIndex],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: _tealBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: _teal,
              unselectedItemColor: _textMuted,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'Borçlar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_rounded),
                  label: 'Gruplar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_rounded),
                  label: 'Arkadaş',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  label: 'Ayarlar',
                ),
              ],
              selectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.3,
                color: _teal,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: _textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
