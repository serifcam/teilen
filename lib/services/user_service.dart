// lib/services/user_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Örnek: Kullanıcıyı oturumdan çıkarır.
  Future<void> signOutUser() async {
    await _auth.signOut();
  }

  /// Örnek: Kullanıcı verilerini (profil resmi vb.) Firestore'dan çeker.
  Future<Map<String, dynamic>?> fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Örnek: Yeni profil resmi yükler
  Future<String?> uploadProfileImage(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
    await ref.putFile(imageFile);

    final url = await ref.getDownloadURL();

    // Firestore güncelle
    await _firestore.collection('users').doc(user.uid).update({
      'profileImageUrl': url,
    });
    return url;
  }

  /// Örnek: Var olan profil resmini siler.
  Future<void> deleteProfileImageOnStorage({bool forceDelete = true}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Silme işlemleri...
  }
}
