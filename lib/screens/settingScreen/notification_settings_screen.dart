import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Bildirim ayarlarının yönetildiği ekran
class NotificationSettingsScreen extends StatefulWidget {
  @override
  _NotificationSettingsScreenState createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Ana bildirim ve alt bildirim ayarlarını tutan değişkenler
  bool _notificationsEnabled = true;
  bool _individualDebtEnabled = true;
  bool _groupDebtEnabled = true;
  bool _friendRequestEnabled = true;
  bool _debtPaidEnabled = true; // ✅ Borç ödendi bildirimi
  bool _isLoading = true; // Sayfa yükleniyor mu

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences(); // Firestore'dan ayarları yükle
  }

  // Kullanıcının Firestore'daki bildirim ayarlarını yükler
  Future<void> _loadNotificationPreferences() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      setState(() {
        _notificationsEnabled = data?['XnotificationsEnabled'] ?? true;
        _individualDebtEnabled = data?['XindividualDebtEnabled'] ?? true;
        _groupDebtEnabled = data?['XgroupDebtEnabled'] ?? true;
        _friendRequestEnabled = data?['XfriendRequestEnabled'] ?? true;
        _debtPaidEnabled = data?['XdebtPaidEnabled'] ?? true;
        _isLoading = false;
      });
    }
  }

  // Değişiklikleri Firestore'a kaydeder
  Future<void> _updateSettingsOnFirestore() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'XnotificationsEnabled': _notificationsEnabled,
        'XindividualDebtEnabled': _individualDebtEnabled,
        'XgroupDebtEnabled': _groupDebtEnabled,
        'XfriendRequestEnabled': _friendRequestEnabled,
        'XdebtPaidEnabled': _debtPaidEnabled,
      });
    }
  }

  // Ana switch (Uygulama Bildirimleri) kontrol edildiğinde tüm alt ayarları da etkiler
  void _toggleMasterSwitch(bool value) {
    setState(() {
      _notificationsEnabled = value;
      _individualDebtEnabled = value;
      _groupDebtEnabled = value;
      _friendRequestEnabled = value;
      _debtPaidEnabled = value;
    });
    _updateSettingsOnFirestore(); // Firestore'a güncelle
  }

  // Alt bildirim türlerinden biri değiştirildiğinde çağrılır
  void _toggleSubSwitch(String type, bool value) {
    setState(() {
      if (type == 'individual') {
        _individualDebtEnabled = value;
      } else if (type == 'group') {
        _groupDebtEnabled = value;
      } else if (type == 'friend') {
        _friendRequestEnabled = value;
      } else if (type == 'paid') {
        _debtPaidEnabled = value;
      }
    });
    _updateSettingsOnFirestore();
  }

  // Switch bileşeni oluşturan yardımcı metod
  Widget buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
    Color? activeColor,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        activeColor: activeColor ?? Colors.green,
        inactiveThumbColor: Colors.red,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bildirim Ayarları")),
      body: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator()) // Ayarlar yüklenene kadar spinner göster
          : ListView(
              children: [
                // Ana bildirim aç/kapa
                buildSwitchTile(
                  title: "Uygulama Bildirimleri",
                  subtitle: "Tüm bildirimleri genel olarak aç/kapat",
                  value: _notificationsEnabled,
                  onChanged: _toggleMasterSwitch,
                ),
                Divider(thickness: 1),

                // Alt ayarlar başlığı
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Alt Bildirim Ayarları",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),

                // Bireysel borç bildirimi
                buildSwitchTile(
                  title: "Bireysel Borç Bildirimleri",
                  subtitle: "Bireysel borç bildirimlerini al",
                  value: _individualDebtEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) => _toggleSubSwitch('individual', val)
                      : null, // Ana switch kapalıysa devre dışı
                ),

                // Grup borcu bildirimi
                buildSwitchTile(
                  title: "Grup Borcu Bildirimleri",
                  subtitle: "Grup borcu bildirimlerini al",
                  value: _groupDebtEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) => _toggleSubSwitch('group', val)
                      : null,
                ),

                // Arkadaşlık isteği bildirimi
                buildSwitchTile(
                  title: "Arkadaşlık İsteği Bildirimleri",
                  subtitle: "Yeni arkadaşlık isteği bildirimlerini al",
                  value: _friendRequestEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) => _toggleSubSwitch('friend', val)
                      : null,
                ),

                // Borç ödendi bildirimi
                buildSwitchTile(
                  title: "Borç Ödendi Bildirimleri",
                  subtitle: "Borç ödendiğinde bildirim al",
                  value: _debtPaidEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) => _toggleSubSwitch('paid', val)
                      : null,
                ),
              ],
            ),
    );
  }
}
