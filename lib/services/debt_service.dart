import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Kullanıcının arkadaş listesini Firestore'dan getirir
  Future<List<Map<String, dynamic>>> loadFriends() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    List friends = userDoc.data()?['friends'] ?? [];

    if (friends.isNotEmpty) {
      final querySnapshot = await _firestore
          .collection('users')
          .where('uid', whereIn: friends)
          .get();

      return querySnapshot.docs.map((doc) {
        return {
          'uid': doc.id,
          'email': doc.data()['email'] ?? 'Bilinmeyen E-posta',
        };
      }).toList();
    }

    return [];
  }

  /// Yeni borç bildirimi ekler (notification dokümanına yazar)
  Future<void> addDebt({
    required String friendEmail,
    required double amount,
    required String description,
    required String relation,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturum açmamış.');
    }

    // Arkadaşın bilgilerini Firestore'dan al
    final friendDoc = await _firestore
        .collection('users')
        .where('email', isEqualTo: friendEmail)
        .get();

    if (friendDoc.docs.isEmpty) {
      throw Exception('Arkadaş bulunamadı.');
    }

    final friendId = friendDoc.docs.first.id;
    final friendEmailData =
        friendDoc.docs.first.data()['email'] ?? "Bilinmeyen Kullanıcı";

    final userUid = user.uid;
    final userEmail = user.email ?? "Bilinmeyen Kullanıcı";

    final notificationData = {
      'fromUser': userUid,
      'fromUserEmail': userEmail,
      'toUser': friendId,
      'toUserEmail': friendEmailData,
      'amount': amount,
      'description': description,
      'relation': relation,
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'type': 'newDebt',
    };

    await _firestore.collection('notifications').add(notificationData);
  }

  /// Borcun ödendiğini karşı tarafa bildiren fonksiyon
  Future<void> confirmDebtPaid({
    required String debtDocId,
    required Map<String, dynamic> debtData,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Kullanıcı oturum açmamış.');
    }

    final myEmail = currentUser.email ?? '';

    // 1) Karşı tarafın UID'sini bul
    final friendQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: debtData['friendEmail'])
        .limit(1)
        .get();

    if (friendQuery.docs.isEmpty) {
      throw Exception('Borç sahibi (arkadaş) bulunamadı.');
    }

    final friendUid = friendQuery.docs.first.id;

    // 2) Karşı tarafın borç dokümanını bul
    final query = await _firestore
        .collection('individualDebts')
        .where('borrowerId', isNotEqualTo: currentUser.uid)
        .where('friendEmail', isEqualTo: myEmail)
        .where('amount', isEqualTo: debtData['amount'])
        .where('description', isEqualTo: debtData['description'])
        .get();

    String? creditorDebtDocId;
    if (query.docs.isNotEmpty) {
      creditorDebtDocId = query.docs.first.id;
    }

    // 3) "Borç ödendi" bildirimini karşı tarafa gönder
    await _firestore.collection('notifications').add({
      'type': 'debtPaid',
      'status': 'pending',
      'fromUser': currentUser.uid,
      'fromUserEmail': myEmail,
      'toUser': friendUid,
      'toUserEmail': debtData['friendEmail'],
      'amount': debtData['amount'],
      'description': debtData['description'],
      'createdAt': Timestamp.now(),
      'borrowerDebtDocId': debtDocId,
      'creditorDebtDocId': creditorDebtDocId,
    });
  }

  /// Kullanıcının borçlarını dinleyen (Stream) fonksiyon
  Stream<QuerySnapshot> getDebtsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Eğer kullanıcı yoksa boş bir akış döndürelim
      return const Stream.empty();
    }

    return _firestore
        .collection('individualDebts')
        .where('borrowerId', isEqualTo: currentUser.uid)
        .snapshots();
  }
}
