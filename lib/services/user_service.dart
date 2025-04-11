import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Mevcut kullanıcı bilgisini getirir.
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Kullanıcı verilerini Firestore'dan çeker (Örn. profil resmi, isim, e-posta).
  Future<Map<String, dynamic>?> fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Yeni profil resmi yükler. Var olanı silmek için önce `_deleteOldImage` çağırıyoruz.
  Future<String?> uploadProfileImage(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Eski resmi sil
    await deleteProfileImageOnStorage(forceDelete: false);

    final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
    await ref.putFile(imageFile);
    final url = await ref.getDownloadURL();

    // Firestore'da güncelle
    await _firestore.collection('users').doc(user.uid).update({
      'profileImageUrl': url,
    });

    return url;
  }

  /// Eski profil resmini hem Storage'dan hem Firestore'dan siler.
  /// forceDelete = true ise, direkt siler. false ise var olan resim varsa siler.
  Future<void> deleteProfileImageOnStorage({bool forceDelete = true}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Kullanıcının Firestore'da kayıtlı resmi var mı?
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final profileImageUrl = userDoc.data()?['profileImageUrl'];

    // Eğer forceDelete = false ve Firestore kaydı yoksa silme işlemi yapma
    if (!forceDelete && (profileImageUrl == null || profileImageUrl.isEmpty)) {
      return;
    }

    // Storage'daki resmi sil
    final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
    await ref.delete();

    // Firestore'da null olarak güncelle
    await _firestore.collection('users').doc(user.uid).update({
      'profileImageUrl': null,
    });
  }

  /// Firebase Auth üzerinden kullanıcıyı çıkış yaptırır, tokeni siler.
  Future<void> signOutUser() async {
    final user = _auth.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': FieldValue.delete()}); // 🔥 Token silinir
    }

    await _auth.signOut(); // 🔒 Oturum kapatılır
  }
}
