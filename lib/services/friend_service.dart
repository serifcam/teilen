import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Arkadaşlık isteği gönderir.
  Future<void> sendFriendRequest(String email) async {
    final currentUser = _auth.currentUser;

    if (email.isEmpty) {
      throw Exception('E-posta adresi boş olamaz.');
    }

    if (email == currentUser!.email) {
      throw Exception('Kendinize arkadaşlık isteği gönderemezsiniz.');
    }

    final querySnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Kullanıcı bulunamadı.');
    }

    final receiverId = querySnapshot.docs.first.id;

    final existingRequest = await _firestore
        .collection('friendRequests')
        .where('senderId', isEqualTo: currentUser.uid)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Zaten bu kullanıcıya arkadaşlık isteği gönderdiniz.');
    }

    final currentUserDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    List friends = currentUserDoc['friends'] ?? [];

    if (friends.contains(receiverId)) {
      throw Exception('Zaten bu kişiyle arkadaşsınız.');
    }

    await _firestore.collection('friendRequests').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'status': 'pending',
    });
  }

  /// Bir kullanıcıyı arkadaş listesinden çıkarır.
  Future<void> removeFriend(String friendId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Kullanıcı oturum açmamış.');
    }

    final currentUserId = currentUser.uid;

    await _firestore.collection('users').doc(currentUserId).update({
      'friends': FieldValue.arrayRemove([friendId])
    });

    await _firestore.collection('users').doc(friendId).update({
      'friends': FieldValue.arrayRemove([currentUserId])
    });
  }

  /// Kullanıcının arkadaşlarını dinler.
  Stream<List<Map<String, dynamic>>> getFriendsStream() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    final userStream = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .map((doc) => doc.data()?['friends'] ?? []);

    await for (final friends in userStream) {
      if (friends.isEmpty) {
        yield [];
        continue;
      }

      final friendsQuery = await _firestore
          .collection('users')
          .where('uid', whereIn: friends)
          .get();

      final friendList = friendsQuery.docs.map((doc) {
        return {
          'uid': doc.id,
          'name': doc.data()['name'] ?? '',
          'email': doc.data()['email'] ?? '',
          'profileImageUrl': doc.data()['profileImageUrl'],
        };
      }).toList();

      yield friendList;
    }
  }

  /// Belirli bir arkadaşla okunmamış mesaj var mı kontrolü
  Future<bool> hasUnreadMessage(String friendId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final chatKey = _generateChatKey(currentUser.uid, friendId);

    final unread = await _firestore
        .collection('quickMessages')
        .where('chatKey', isEqualTo: chatKey)
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .limit(1)
        .get();

    return unread.docs.isNotEmpty;
  }

  /// ChatKey üretici
  String _generateChatKey(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
