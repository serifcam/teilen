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
}