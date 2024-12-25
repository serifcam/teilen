import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Arkadaşlık isteğini günceller (kabul veya reddetme)
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    required String senderId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Kullanıcı oturum açmamış.');

    await _firestore.collection('friendRequests').doc(requestId).update({
      'status': status,
    });

    if (status == 'accepted') {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'friends': FieldValue.arrayUnion([senderId]),
      });

      await _firestore.collection('users').doc(senderId).update({
        'friends': FieldValue.arrayUnion([currentUser.uid]),
      });
    }
  }

  /// Kullanıcının bilgilerini alır
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc.data();
  }

  /// Kullanıcının aldığı bekleyen arkadaşlık isteklerini dinler
  Stream<QuerySnapshot> getPendingFriendRequestsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('friendRequests')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}
