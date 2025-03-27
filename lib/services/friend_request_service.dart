import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FriendRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Mailgun API Bilgileri (Bunları kendi bilgilerinizle değiştirin)
  final String mailgunDomain =
      "sandbox5b0905247fc3499799efa49a20a0f98b.mailgun.org"; // Örnek: "sandbox1234.mailgun.org"
  final String mailgunApiKey =
      "3d4b3a2a-1d3d364d"; // Örnek: "key-xxxxxxxxxxxxxxxxxxxx"

  /// Arkadaşlık isteğini günceller (kabul veya reddetme)
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    required String senderId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Kullanıcı oturum açmamış.');

    // Firestore'da arkadaşlık isteğinin durumunu güncelle
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

      // Kullanıcı bilgilerini çek
      final senderUserData =
          await _firestore.collection('users').doc(senderId).get();
      final acceptorUserData =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (senderUserData.exists && acceptorUserData.exists) {
        final senderEmail = senderUserData['email'];
        final senderName = senderUserData['name'] ?? 'Kullanıcı';
        final acceptorName = acceptorUserData['name'] ?? 'Kullanıcı';

        // Mailgun ile e-posta bildirimi gönder
        await _sendEmailNotification(senderEmail, senderName, acceptorName);
      }
    }
  }

  /// Mailgun API ile e-posta bildirimi gönderir
  Future<void> _sendEmailNotification(
      String toEmail, String toName, String fromName) async {
    final String mailgunUrl =
        "https://api.mailgun.net/v3/$mailgunDomain/messages";

    final response = await http.post(
      Uri.parse(mailgunUrl),
      headers: {
        "Authorization":
            "Basic ${base64Encode(utf8.encode('api:$mailgunApiKey'))}",
      },
      body: {
        "from": "Teilen Uygulaması <no-reply@$mailgunDomain>",
        "to": toEmail,
        "subject": "Arkadaşlık İsteğin Kabul Edildi!",
        "text":
            "Merhaba $toName,\n\n$fromName senin arkadaşlık isteğini kabul etti! 🎉\n\nTeilen uygulamasına giriş yaparak arkadaşlarınla sohbet edebilirsin.\n\nİyi günler!",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          "E-posta gönderilemedi: ${response.statusCode}, ${response.body}");
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
