import 'package:cloud_firestore/cloud_firestore.dart';

class GroupDetailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Grup kurucusunun UID'sini getirir.
  Future<String?> fetchGroupCreator(String groupId) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (groupDoc.exists && groupDoc.data() != null) {
      return groupDoc.data()!['createdBy'] as String?;
    }
    return null;
  }

  /// Belirtilen userId'ye ait borcun durumunu (paid <-> pending) değiştirir.
  Future<void> toggleDebtStatus(String groupId, String userId) async {
    final querySnapshot = await _firestore
        .collection('debts')
        .where('groupId', isEqualTo: groupId)
        .where('fromUser', isEqualTo: userId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final currentStatus = doc['status'];
      final newStatus = currentStatus == 'paid' ? 'pending' : 'paid';

      await _firestore.collection('debts').doc(doc.id).update({
        'status': newStatus,
      });
    } else {
      throw Exception('Seçilen kullanıcı için borç bulunamadı.');
    }
  }

  /// Verilen UID'ye sahip kullanıcının e-postasını getirir.
  Future<String> getUserEmail(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      return userDoc.data()!['email'] ?? 'Bilinmeyen Kullanıcı';
    } else {
      return 'Bilinmeyen Kullanıcı';
    }
  }

  /// Grup ve ilgili borçları (debts) Firestore'dan siler.
  Future<void> deleteGroup(String groupId) async {
    // Önce grup dokümanını sil
    await _firestore.collection('groups').doc(groupId).delete();

    // Ardından bu gruba bağlı borç dokümanlarını sil
    final debtsSnapshot = await _firestore
        .collection('debts')
        .where('groupId', isEqualTo: groupId)
        .get();

    for (var debtDoc in debtsSnapshot.docs) {
      await _firestore.collection('debts').doc(debtDoc.id).delete();
    }
  }
}
