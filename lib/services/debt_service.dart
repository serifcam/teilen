import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Kullanıcının arkadaş listesini getirir
  /// Kullanıcının arkadaş listesini getirir
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
          'name': doc.data()['name'] ?? 'Bilinmeyen Kullanıcı',
        };
      }).toList();
    }

    return [];
  }

  /// 🔥 Borç isteği bildirimi gönderir (notification'a kaydeder)
  Future<void> sendDebtNotification({
    required String friendEmail,
    required double amount,
    required String description,
    required String relation,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturum açmamış.');
    }

    // Arkadaşın bilgilerini çekiyoruz
    final friendDoc = await _firestore
        .collection('users')
        .where('email', isEqualTo: friendEmail)
        .limit(1)
        .get();

    if (friendDoc.docs.isEmpty) {
      throw Exception('Arkadaş bulunamadı.');
    }

    final friendUid = friendDoc.docs.first.id;
    final friendEmailData =
        friendDoc.docs.first.data()['email'] ?? "Bilinmeyen Kullanıcı";

    final userUid = user.uid;
    final userEmail = user.email ?? "Bilinmeyen Kullanıcı";

    final notificationData = {
      'fromUser': userUid,
      'fromUserEmail': userEmail,
      'toUser': friendUid,
      'toUserEmail': friendEmailData,
      'amount': amount,
      'description': description,
      'relation': relation,
      'status': 'pending', // Onay bekliyor
      'type': 'newDebt',
      'createdAt': Timestamp.now(),
    };

    await _firestore.collection('notifications').add(notificationData);
  }

  /// 🔥 Borç ödeme bildirimi gönderir (yani borcun ödendiğini bildirir)
  Future<void> confirmDebtPaid({
    required String debtDocId,
    required Map<String, dynamic> debtData,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Kullanıcı oturum açmamış.');
    }

    final myEmail = currentUser.email ?? '';

    // 1) Arkadaşın UID'sini bul
    final friendQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: debtData['friendEmail'])
        .limit(1)
        .get();

    if (friendQuery.docs.isEmpty) {
      throw Exception('Borç sahibi (arkadaş) bulunamadı.');
    }

    final friendUid = friendQuery.docs.first.id;

    // 2) Karşı tarafın borç dokümanını bul (diğer kişinin kaydı)
    final query = await _firestore
        .collection('individualDebts')
        .where('borrowerId', isNotEqualTo: currentUser.uid)
        .where('friendEmail', isEqualTo: myEmail)
        .where('amount', isEqualTo: debtData['amount'])
        .where('description', isEqualTo: debtData['description'])
        .limit(1)
        .get();

    String? creditorDebtDocId;
    if (query.docs.isNotEmpty) {
      creditorDebtDocId = query.docs.first.id;
    }

    // 3) Bildirimi gönderelim
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

  /// 🔥 Kullanıcının bireysel borçlarını Stream ile dinler
  Stream<QuerySnapshot> getDebtsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('individualDebts')
        .where('borrowerId', isEqualTo: currentUser.uid)
        .snapshots();
  }

  Future<void> sendGroupInviteNotification({
    required List<String> friendEmails, // Grup üyeleri (email listesi)
    required double amount, // Kişi başı borç miktarı
    required String description, // Grup açıklaması
    required String groupId, // Grup ID'si
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturum açmamış.');
    }

    for (final email in friendEmails) {
      final friendQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (friendQuery.docs.isEmpty) continue;

      final friendId = friendQuery.docs.first.id;
      final friendEmail = friendQuery.docs.first.data()['email'] ?? '';

      await _firestore.collection('notifications').add({
        'type': 'groupInvite',
        'fromUser': user.uid,
        'fromUserEmail': user.email ?? '',
        'toUser': friendId,
        'toUserEmail': friendEmail,
        'groupId': groupId,
        'amount': amount,
        'description': description,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });
    }
  }
}
