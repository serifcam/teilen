import 'package:flutter/material.dart';
import 'individual_debt_screen.dart';
import 'add_friend_screen.dart';
import 'settings_screen.dart';
import 'group_expense_screen.dart';
import 'notification_screen.dart'; // Bildirim ekranını import ettim

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    IndividualDebtScreen(), // Bireysel Borç Takibi
    GroupExpenseScreen(), // Grup Harcamaları
    AddFriendScreen(), // Arkadaş Ekleme
    SettingsScreen(), // Ayarlar
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        actions: [
          // Bildirim Butonu
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => NotificationScreen()),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
            label: 'Arkadaş Ekle',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
