import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Grup oluşturur ve katılım taleplerini gönderir
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
      // ✨ Kurucunun kullanıcı adını çekelim
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Bir kullanıcı';

      // 🔥 Grup verisini oluştur
      final groupRef = await _firestore.collection('groups').add({
        'name': groupName,
        'creatorId': currentUser.uid,
        'totalAmount': totalAmount,
        'description': description,
        'memberIds': memberIds,
        'approvedMemberIds': [currentUser.uid],
        'createdAt': Timestamp.now(),
        'isGroupFormed': false,
      });

      // 🔥 Üyelere bildirim gönderiyoruz
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
              'fromUserName':
                  currentUserName, // ✨ Kullanıcı adını BURAYA ekledik
              'toUser': memberId,
              'toUserEmail': userEmail,
              'groupId': groupRef.id,
              'groupName': groupName,
              'amount': totalAmount,
              'description': description,
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

  /// Gruptaki borçları oluşturur (herkes onayladıysa)
  Future<void> createDebtsForGroup(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data();
      if (groupData == null) return;

      final memberIds = List<String>.from(groupData['memberIds']);
      final creatorId = groupData['creatorId'];
      final totalAmount = (groupData['totalAmount'] as num).toDouble();
      final groupName = groupData['name'];
      final description = groupData['description'] ?? '';

      if (memberIds.isEmpty || creatorId == null) {
        throw Exception('Grup verileri eksik.');
      }

      final perPersonAmount = (totalAmount / memberIds.length);

      for (final memberId in memberIds) {
        if (memberId != creatorId) {
          // ✅ Normal üyelerin borç kaydı (pending)
          await _firestore.collection('debts').add({
            'fromUser': memberId,
            'toUser': creatorId,
            'amount': perPersonAmount,
            'status': 'pending',
            'groupId': groupId,
            'groupName': groupName,
            'description': description,
            'createdAt': Timestamp.now(),
          });
        } else {
          // ✅ Kurucunun kendisine borç kaydı (direkt ödendi)
          await _firestore.collection('debts').add({
            'fromUser': creatorId,
            'toUser': creatorId,
            'amount': 0,
            'status': 'paid',
            'groupId': groupId,
            'groupName': groupName,
            'description': 'Kurucu - tüm borç ödendi.',
            'createdAt': Timestamp.now(),
          });
        }
      }

      // 🔥 Grup artık tamamen kurulmuş oluyor
      await _firestore.collection('groups').doc(groupId).update({
        'isGroupFormed': true,
      });
    } catch (e) {
      print('Grup borçları oluşturulurken hata: $e');
      rethrow;
    }
  }

  /// 🔥 Kullanıcının katıldığı grupları listeler
  Stream<QuerySnapshot> getUserGroups() {
    final currentUser = _auth.currentUser;
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: currentUser?.uid)
        .where('isGroupFormed', isEqualTo: true) // 🔥 SADECE TAMAMLANAN GRUPLAR
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
