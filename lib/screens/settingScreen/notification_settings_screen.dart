import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  @override
  _NotificationSettingsScreenState createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _individualDebtEnabled = true;
  bool _groupDebtEnabled = true;
  bool _friendRequestEnabled = true;
  bool _debtPaidEnabled = true;
  bool _isLoading = true;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

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

  void _toggleMasterSwitch(bool value) {
    setState(() {
      _notificationsEnabled = value;
      _individualDebtEnabled = value;
      _groupDebtEnabled = value;
      _friendRequestEnabled = value;
      _debtPaidEnabled = value;
    });
    _updateSettingsOnFirestore();
  }

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

  Widget buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
    IconData? icon,
    Color? color,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 7, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: ListTile(
        leading: icon != null
            ? Container(
                decoration: BoxDecoration(
                  color: (color ?? Colors.teal).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: EdgeInsets.all(8),
                child: Icon(icon, color: color ?? Colors.teal, size: 28),
              )
            : null,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: value,
          activeColor: color ?? Colors.teal,
          inactiveThumbColor: Colors.redAccent,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.grey.shade100;
    final mainTeal = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(
          "Bildirim Ayarları",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.2,
            fontFamily: 'Nunito',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: mainTeal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              children: [
                // Ana bildirim aç/kapa
                buildSwitchCard(
                  title: "Uygulama Bildirimleri",
                  subtitle: "Tüm bildirimleri genel olarak aç/kapat",
                  value: _notificationsEnabled,
                  onChanged: _toggleMasterSwitch,
                  icon: Icons.notifications_active_rounded,
                  color: Colors.blueAccent,
                ),
                SizedBox(height: 6),

                // Alt ayarlar başlığı
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 2.0, vertical: 9.0),
                  child: Text(
                    "Alt Bildirim Ayarları",
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: Colors.teal.shade700),
                  ),
                ),

                buildSwitchCard(
                  title: "Bireysel Borç Bildirimleri",
                  subtitle: "Bireysel borç bildirimlerini al",
                  value: _individualDebtEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) => _toggleSubSwitch('individual', val)
                      : null,
                  icon: Icons.account_circle_rounded,
                  color: Colors.teal.shade600,
                ),
                buildSwitchCard(
                  title: "Grup Borcu Bildirimleri",
                  subtitle: "Grup borcu bildirimlerini al",
                  value: _groupDebtEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) => _toggleSubSwitch('group', val)
                      : null,
                  icon: Icons.groups_2_rounded,
                  color: Colors.orange.shade400,
                ),
                buildSwitchCard(
                  title: "Arkadaşlık İsteği Bildirimleri",
                  subtitle: "Yeni arkadaşlık isteği bildirimlerini al",
                  value: _friendRequestEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) => _toggleSubSwitch('friend', val)
                      : null,
                  icon: Icons.person_add_alt_1_rounded,
                  color: Colors.purple.shade400,
                ),
                buildSwitchCard(
                  title: "Borç Ödendi Bildirimleri",
                  subtitle: "Borç ödendiğinde bildirim al",
                  value: _debtPaidEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) => _toggleSubSwitch('paid', val)
                      : null,
                  icon: Icons.verified_rounded,
                  color: Colors.green,
                ),
              ],
            ),
    );
  }
}
