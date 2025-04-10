import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Bildirim durumunu günceller ve gerekli işlemleri yapar
  Future<void> updateNotificationStatus({
    required String notificationId,
    required String status,
    required Map<String, dynamic> data,
  }) async {
    if (status == 'approved') {
      if (data['type'] == null || data['type'] == 'newDebt') {
        // Bireysel borç ekleme işlemi
        String borrowerId = data['relation'] == 'friend_to_me'
            ? data['toUser']
            : data['fromUser'];
        String creditorId = data['relation'] == 'friend_to_me'
            ? data['fromUser']
            : data['toUser'];

        String borrowerEmail = data['relation'] == 'friend_to_me'
            ? data['toUserEmail'] ?? "Bilinmeyen Kullanıcı"
            : data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı";
        String creditorEmail = data['relation'] == 'friend_to_me'
            ? data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı"
            : data['toUserEmail'] ?? "Bilinmeyen Kullanıcı";

        await _firestore.collection('individualDebts').add({
          'borrowerId': borrowerId,
          'friendEmail': creditorEmail,
          'amount': data['amount'] ?? 0.0,
          'relation': 'me_to_friend',
          'description': data['description'] ?? "Açıklama yok",
          'createdAt': Timestamp.now(),
        });

        await _firestore.collection('individualDebts').add({
          'borrowerId': creditorId,
          'friendEmail': borrowerEmail,
          'amount': data['amount'] ?? 0.0,
          'relation': 'friend_to_me',
          'description': data['description'] ?? "Açıklama yok",
          'createdAt': Timestamp.now(),
        });
      } else if (data['type'] == 'debtPaid') {
        // Borç ödeme işlemi: ilgili dokümanları sil
        String? borrowerDebtDocId = data['borrowerDebtDocId'];
        String? creditorDebtDocId = data['creditorDebtDocId'];

        if (borrowerDebtDocId != null && borrowerDebtDocId.isNotEmpty) {
          await _firestore
              .collection('individualDebts')
              .doc(borrowerDebtDocId)
              .delete();
        }

        if (creditorDebtDocId != null && creditorDebtDocId.isNotEmpty) {
          await _firestore
              .collection('individualDebts')
              .doc(creditorDebtDocId)
              .delete();
        }
      } else if (data['type'] == 'groupDebt') {
        // Grup borcu bildirimi onaylandı → sadece bildirimi sil
        print("Group debt bildirimi onaylandı: $notificationId");
      }

      // Bildirimi sil
      await _firestore.collection('notifications').doc(notificationId).delete();
    } else if (status == 'rejected') {
      // Reddedildiyse bildirimi sil
      await _firestore.collection('notifications').doc(notificationId).delete();
    } else {
      // Diğer statü durumları varsa sadece güncelle
      await _firestore.collection('notifications').doc(notificationId).update({
        'status': status,
      });
    }
  }

  /// Kullanıcının bekleyen bildirimlerini dinler
  Stream<QuerySnapshot> getPendingNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('toUser', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}
