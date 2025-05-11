import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teilen2/services/group_service.dart'; // ✅ Bunu da ekliyoruz

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
        // ✅ KİŞİSEL BORÇ: Borç bildirimi onaylandı → bireysel borç oluştur
        String borrowerId = data['relation'] == 'friend_to_me'
            ? data['toUser']
            : data['fromUser'];

        String lenderId = data['relation'] == 'friend_to_me'
            ? data['fromUser']
            : data['toUser'];

        String borrowerEmail = data['relation'] == 'friend_to_me'
            ? data['toUserEmail'] ?? 'Bilinmeyen Kullanıcı'
            : data['fromUserEmail'] ?? 'Bilinmeyen Kullanıcı';

        String lenderEmail = data['relation'] == 'friend_to_me'
            ? data['fromUserEmail'] ?? 'Bilinmeyen Kullanıcı'
            : data['toUserEmail'] ?? 'Bilinmeyen Kullanıcı';

        await _firestore.collection('individualDebts').add({
          'borrowerId': borrowerId,
          'lenderId': lenderId,
          'friendEmail': lenderEmail,
          'amount': data['amount'] ?? 0.0,
          'description': data['description'] ?? 'Açıklama yok',
          'relation': 'me_to_friend',
          'status': 'pending',
          'createdAt': Timestamp.now(),
        });

        await _firestore.collection('individualDebts').add({
          'borrowerId': lenderId,
          'lenderId': borrowerId,
          'friendEmail': borrowerEmail,
          'amount': data['amount'] ?? 0.0,
          'description': data['description'] ?? 'Açıklama yok',
          'relation': 'friend_to_me',
          'status': 'pending',
          'createdAt': Timestamp.now(),
        });
      } else if (data['type'] == 'debtPaid') {
        // ✅ KİŞİSEL BORÇ: Borç ödeme bildirimi onaylandı → borçları sil
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
      } else if (data['type'] == 'groupRequest') {
        // ✅ GRUP BORÇ: Grup oluşturma talebi onaylandıysa
        final groupId = data['groupId'];
        final userId = data['toUser'];

        // 🔥 approvedMemberIds dizisine kullanıcıyı ekliyoruz
        await _firestore.collection('groups').doc(groupId).update({
          'approvedMemberIds': FieldValue.arrayUnion([userId])
        });

        // 🔥 ŞİMDİ KONTROL EDİYORUZ: Herkes onayladı mı?
        final groupDoc =
            await _firestore.collection('groups').doc(groupId).get();
        final groupData = groupDoc.data();

        if (groupData != null) {
          List<dynamic> memberIds = groupData['memberIds'] ?? [];
          List<dynamic> approvedMemberIds =
              groupData['approvedMemberIds'] ?? [];

          if (memberIds.length == approvedMemberIds.length) {
            // ✅ Herkes onayladı ➔ Grup kurulacak
            final GroupService _groupService = GroupService();
            await _groupService.createDebtsForGroup(groupId);
            await _firestore.collection('groups').doc(groupId).update({
              'isGroupFormed': true,
            });
            print('✅ Grup tamamlandı ve borçlar oluşturuldu.');
          }
        }
      }

      // 🔥 Bildirimi tamamen siliyoruz
      await _firestore.collection('notifications').doc(notificationId).delete();
    } else if (status == 'rejected') {
      // ❌ Reddedildiyse bildirimi sil
      await _firestore.collection('notifications').doc(notificationId).delete();
    } else {
      // ⚡ Diğer statüler için sadece statü güncelle
      await _firestore.collection('notifications').doc(notificationId).update({
        'status': status,
      });
    }
  }

  /// Bekleyen (pending) bireysel borç bildirimlerini getirir
  Stream<QuerySnapshot> getPendingNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('toUser', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// ✅ Borç ödeme bildirimini kurucuya gönderir
  Future<void> sendDebtPaymentNotification({
    required String fromUserId,
    required String toUserId,
    required String groupId,
    required String groupName,
    required double amount,
  }) async {
    await _firestore.collection('notifications').add({
      'type': 'debtPayment', // Bildirim tipi
      'fromUser': fromUserId,
      'toUser': toUserId,
      'groupId': groupId,
      'groupName': groupName,
      'amount': amount,
      'status': 'pending', // İstersen 'unread' da yapabiliriz
      'createdAt': Timestamp.now(),
    });
  }

  /// 🔥 Tüm bildirimleri getirir
  Stream<QuerySnapshot> getAllNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('toUser', isEqualTo: userId)
        .snapshots();
  }

  /// Belirli bir bildirimi siler
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}
