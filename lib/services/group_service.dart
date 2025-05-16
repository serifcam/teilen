import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Grup oluşturur, kurucuya otomatik onay verir ve tüm üyeler için borç dokümanları ekler!
  Future<void> createGroup({
    required String groupName,
    required List<String> memberIds,
    required double totalAmount,
    required String description,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Kullanıcı oturum açmamış.');
    }

    try {
      // Kurucunun adı lazım olursa çekiyoruz
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Bir kullanıcı';

      // Grup oluştur, kurucu otomatik onaylı
      final groupRef = await _firestore.collection('groups').add({
        'name': groupName,
        'creatorId': currentUser.uid,
        'totalAmount': totalAmount,
        'description': description,
        'memberIds': memberIds,
        'approvedMemberIds': [currentUser.uid],
        'createdAt': Timestamp.now(),
      });

      // Her üye için borç dokümanını ekle (kurucu: otomatik paid & approved)
      final perPersonAmount = totalAmount / memberIds.length;
      for (final memberId in memberIds) {
        await _firestore.collection('groupDebts').add({
          'fromUser': memberId,
          'toUser': currentUser.uid,
          'amount': memberId == currentUser.uid ? 0 : perPersonAmount,
          'status': memberId == currentUser.uid ? 'paid' : 'pending',
          'isApproved': memberId == currentUser.uid ? true : false,
          'groupId': groupRef.id,
          'groupName': groupName,
          'description': description,
          'createdAt': Timestamp.now(),
        });
      }

      // Diğer üyeler için davet bildirimi gönderiyoruz
      for (final memberId in memberIds) {
        if (memberId != currentUser.uid) {
          final userDoc =
              await _firestore.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            final userEmail =
                userDoc.data()?['email'] ?? 'Bilinmeyen Kullanıcı';

            await _firestore.collection('notifications').add({
              'type': 'groupRequest',
              'fromUser': currentUser.uid,
              'fromUserEmail': currentUser.email ?? '',
              'fromUserName': currentUserName,
              'toUser': memberId,
              'toUserEmail': userEmail,
              'groupId': groupRef.id,
              'groupName': groupName,
              'amount': totalAmount,
              'description': description,
              'memberIds': memberIds, // kişi başı hesap için!
              'status': 'pending',
              'createdAt': Timestamp.now(),
            });
          }
        }
      }
    } catch (e) {
      print('Grup oluşturulurken hata: $e');
      rethrow;
    }
  }

  /// Grup davetini kabul eden kullanıcıyı onaylar, borç dokümanını aktif eder ve bildirimi günceller
  Future<void> approveGroupRequest({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Kullanıcıyı approvedMemberIds'ye ekle
      await _firestore.collection('groups').doc(groupId).update({
        'approvedMemberIds': FieldValue.arrayUnion([userId]),
      });

      // Kullanıcının borç dokümanında isApproved'u true yap!
      final debtQuery = await _firestore
          .collection('groupDebts')
          .where('groupId', isEqualTo: groupId)
          .where('fromUser', isEqualTo: userId)
          .get();
      for (final doc in debtQuery.docs) {
        await doc.reference.update({'isApproved': true});
      }

      // Kullanıcıya ait davet bildirimlerini "accepted" yap
      final notificationQuery = await _firestore
          .collection('notifications')
          .where('groupId', isEqualTo: groupId)
          .where('toUser', isEqualTo: userId)
          .where('type', isEqualTo: 'groupRequest')
          .get();

      for (final doc in notificationQuery.docs) {
        await doc.reference.update({'status': 'accepted'});
      }
    } catch (e) {
      print('Grup isteği onaylanırken hata: $e');
      rethrow;
    }
  }

  /// Kullanıcının onayladığı (approvedMemberIds'de olduğu) tüm grupları getirir
  Stream<QuerySnapshot> getUserGroups() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Garantiye al, null gelirse boş stream
      return const Stream.empty();
    }
    return _firestore
        .collection('groups')
        .where('approvedMemberIds', arrayContains: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
