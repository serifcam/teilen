import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Arkadaş listesini çeker
  Future<List<Map<String, dynamic>>> loadFriends() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    List friends = userDoc.data()?['friends'] ?? [];

    if (friends.isEmpty) return [];

    final querySnapshot = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: friends)
        .get();

    return querySnapshot.docs.map((doc) {
      return {
        'uid': doc.id,
        'email': doc.data()['email'] ?? 'Bilinmeyen E-posta',
      };
    }).toList();
  }

  /// Yeni bir grup oluşturur ve ilgili borç kayıtlarını ekler
  Future<void> createGroup({
    required String groupDescription,
    required double totalAmount,
    required List<String> selectedFriendsUids,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturum açmamış.');
    }

    // Grup en az 3 kişi olmalı: (kullanıcı + en az 2 arkadaş)
    if (selectedFriendsUids.length < 2) {
      throw Exception('Grup en az 3 kişi olmalıdır!');
    }

    final userUid = user.uid;
    final allMembers = [...selectedFriendsUids, userUid];
    double splitAmount = totalAmount / allMembers.length;

    try {
      // 1) Grup dokümanı ekle
      DocumentReference groupRef = await _firestore.collection('groups').add({
        'groupName': groupDescription,
        'createdBy': userUid,
        'members': allMembers,
        'createdAt': Timestamp.now(),
      });

      print('Grup oluşturuldu: ${groupRef.id}');

      // 2) Her bir üye için borç dokümanı ekle
      for (var memberId in allMembers) {
        DocumentReference debtRef = await _firestore.collection('debts').add({
          'groupId': groupRef.id,
          'fromUser': memberId,
          'toUser': userUid,
          'amount': splitAmount,
          'status': 'pending',
        });
        print('Borç oluşturuldu: ${debtRef.id}');
      }
    } catch (e) {
      print('Grup oluşturma hatası: $e');
      throw e;
    }
  }

  /// Kullanıcının içinde bulunduğu grupları dinleyen bir Stream döndürür
  Stream<QuerySnapshot> getUserGroups() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .snapshots();
  }
}
