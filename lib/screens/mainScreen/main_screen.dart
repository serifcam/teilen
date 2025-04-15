import 'package:flutter/material.dart';
import 'package:teilen2/screens/settingScreen/settings_screen.dart';
import '../individualScreen/individual_debt_screen.dart';
import 'package:teilen2/screens/friendScreen/friends_screen.dart';
import '../groupScreen/group_expense_screen.dart';
import '../notificationScreen/notification_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Ana ekran: Alt menüyle gezilebilen, sayfalar arası geçiş sağlayan yapı
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Alt menüde hangi sayfanın seçili olduğunu tutar
  bool _hasNotifications =
      false; // Bekleyen bildirim olup olmadığını kontrol eder

  // Alt menüde gösterilecek ekranlar listesi
  final List<Widget> _pages = [
    IndividualDebtScreen(),
    GroupExpenseScreen(),
    FriendsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkNotifications(); // Bildirim olup olmadığını kontrol et
    _registerFcmToken(); // FCM token'ını alıp Firestore'a kaydet
  }

  // Kullanıcının FCM token'ını alır ve bildirim ayarlarıyla birlikte Firestore'a kaydeder
  void _registerFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await FirebaseMessaging.instance
          .getToken(); // 🔑 Kullanıcıya ait token alınır
      if (token != null) {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        // Kullanıcının mevcut ayarları çekilir
        final doc = await userRef.get();
        final existingData = doc.data() ?? {};

        // Bildirim ayarları ve token Firestore'a güncellenerek kaydedilir
        await userRef.set({
          'fcmToken': token,
          'XnotificationsEnabled':
              existingData.containsKey('XnotificationsEnabled')
                  ? existingData['XnotificationsEnabled']
                  : true,
          'XindividualDebtEnabled':
              existingData.containsKey('XindividualDebtEnabled')
                  ? existingData['XindividualDebtEnabled']
                  : true,
          'XgroupDebtEnabled': existingData.containsKey('XgroupDebtEnabled')
              ? existingData['XgroupDebtEnabled']
              : true,
          'XfriendRequestEnabled':
              existingData.containsKey('XfriendRequestEnabled')
                  ? existingData['XfriendRequestEnabled']
                  : true,
          'XdebtPaidEnabled': existingData.containsKey('XdebtPaidEnabled')
              ? existingData['XdebtPaidEnabled']
              : true,
        }, SetOptions(merge: true));

        print('📬 Tüm bildirim ayarları ve token Firestore\'a kaydedildi');
      }
    }
  }

  // Bekleyen bildirimleri kontrol eder ve varsa simgede sarı ikon gösterir
  void _checkNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .where('toUser', isEqualTo: user.uid) // Kullanıcıya ait
          .where('status', isEqualTo: 'pending') // Bekleyen bildirim
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _hasNotifications =
              snapshot.docs.isNotEmpty; // Bildirim varsa simgede göster
        });
      });
    }
  }

  // Bildirim simgesine tıklanınca bildirimi sıfırla ve ekrana git
  void _onNotificationTapped() {
    setState(() {
      _hasNotifications = false;
    });
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => NotificationScreen()),
    );
  }

  // Alt menüde gezinmeyi sağlayan metod
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 🔒 Geri tuşu devre dışı bırakıldı
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(Icons.paid, color: Colors.tealAccent, size: 28),
              SizedBox(width: 8),
              Text(
                'Teilen', // Uygulama ismi
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
                // Bekleyen bildirim varsa sarı ikon, yoksa varsayılan
                color: _hasNotifications ? Colors.yellow : Colors.tealAccent,
              ),
              onPressed: _onNotificationTapped,
            ),
          ],
        ),

        // Seçilen sayfayı gövdeye yerleştir
        body: _pages[_selectedIndex],

        // Alt gezinme menüsü
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
      ),
    );
  }
}
