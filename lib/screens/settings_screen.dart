import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart'; // Profil fotoğrafı paketi

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context)
          .pushReplacementNamed('/auth'); // Giriş ekranına yönlendir
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış yapılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // Mevcut kullanıcıyı al

    return Scaffold(
      appBar: AppBar(
        title: Text('Ayarlar'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profil Fotoğrafı ve E-Posta
            CircleAvatar(
              radius: 60,
              child: ProfilePicture(
                name: user?.email ??
                    'Kullanıcı', // E-posta kullanarak avatar oluştur
                radius: 60,
                fontsize: 30,
                random: true, // Rastgele temsili avatar
              ),
            ),
            SizedBox(height: 12),
            Text(
              user?.email ?? 'Bilinmeyen Kullanıcı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _signOut(context),
              icon: Icon(Icons.exit_to_app),
              label: Text('Hesaptan Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
