import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
  }

  Future<void> _fetchProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(); // Firestore'dan kullanıcı bilgilerini çek
      if (doc.exists) {
        setState(() {
          _profileImageUrl = doc['profileImageUrl'];
        });
      }
    } catch (e) {
      print('Profil resmi yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
      await ref.putFile(File(pickedFile.path));

      final url = await ref.getDownloadURL();

      setState(() {
        _profileImageUrl = url;
      });

      // Firestore'da `profileImageUrl` alanını güncelle
      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': url,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Profil resmi başarıyla yüklendi ve kaydedildi!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim yüklenemedi: $e')),
      );
    }
  }

  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth', // LoginScreen'e yönlendirme
        (Route<dynamic> route) => false, // Önceki rotaları temizle
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış yapılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ayarlar'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? Icon(Icons.camera_alt, size: 40)
                    : null,
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
