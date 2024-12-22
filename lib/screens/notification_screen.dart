import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _updateNotificationStatus(
    String notificationId,
    String status,
    Map<String, dynamic> data,
  ) async {
    // Bildirimin statusunu güncelle
    await _firestore.collection('notifications').doc(notificationId).update({
      'status': status,
    });

    // Eğer bildirim tipi "yeni borç" ve onaylanırsa
    if (status == 'approved' &&
        (data['type'] == null || data['type'] == 'newDebt')) {
      String borrowerId = data['relation'] == 'friend_to_me'
          ? data['toUser'] // O Bana
          : data['fromUser']; // Ben Ona
      String creditorId = data['relation'] == 'friend_to_me'
          ? data['fromUser'] // O Bana
          : data['toUser']; // Ben Ona

      String borrowerEmail = data['relation'] == 'friend_to_me'
          ? data['toUserEmail'] ?? "Bilinmeyen Kullanıcı"
          : data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı";
      String creditorEmail = data['relation'] == 'friend_to_me'
          ? data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı"
          : data['toUserEmail'] ?? "Bilinmeyen Kullanıcı";

      // Borçlu için kayıt
      await _firestore.collection('individualDebts').add({
        'borrowerId': borrowerId,
        'friendEmail': creditorEmail,
        'amount': data['amount'] ?? 0.0,
        'relation': 'me_to_friend', // Borçlu bakış açısından
        'description': data['description'] ?? "Açıklama yok",
        'createdAt': Timestamp.now(),
      });

      // Alacaklı için kayıt
      await _firestore.collection('individualDebts').add({
        'borrowerId': creditorId,
        'friendEmail': borrowerEmail,
        'amount': data['amount'] ?? 0.0,
        'relation': 'friend_to_me', // Alacaklı bakış açısından
        'description': data['description'] ?? "Açıklama yok",
        'createdAt': Timestamp.now(),
      });
    }

    // Eğer bildirim tipi "debtPaid" ise ve onaylanırsa
    if (status == 'approved' && data['type'] == 'debtPaid') {
      // Borçlu kişi, borcu ödediğini bildirmişti
      // Karşı taraf (alacaklı) onay verince, ilgili iki doküman silinir
      String? borrowerDebtDocId = data['borrowerDebtDocId'];
      String? creditorDebtDocId = data['creditorDebtDocId'];

      // Borçlunun dokümanını sil
      if (borrowerDebtDocId != null && borrowerDebtDocId.isNotEmpty) {
        await _firestore
            .collection('individualDebts')
            .doc(borrowerDebtDocId)
            .delete();
      }
      // Alacaklının dokümanını sil
      if (creditorDebtDocId != null && creditorDebtDocId.isNotEmpty) {
        await _firestore
            .collection('individualDebts')
            .doc(creditorDebtDocId)
            .delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Center(
        child: Text('Kullanıcı oturum açmamış.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirimler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('toUser', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Hiçbir bildirim yok.'));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final notificationId = doc.id;

              final type = data['type'] ?? 'newDebt';

              String message = '';
              if (type == 'newDebt') {
                if (data['relation'] == 'me_to_friend') {
                  message =
                      "${data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı"} size ${data['amount'] ?? 0} TL borç ekledi.";
                } else {
                  message =
                      "Siz ${data['toUserEmail'] ?? "Bilinmeyen Kullanıcı"} kişisine ${data['amount'] ?? 0} TL borç eklediniz.";
                }
              } else if (type == 'debtPaid') {
                final fromUserEmail =
                    data['fromUserEmail'] ?? 'Bilinmeyen Kullanıcı';
                final amount = data['amount'] ?? 0;
                message = "$fromUserEmail, $amount TL borcunu ödemiştir.";
              }

              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(message),
                  subtitle: Text(
                    'Açıklama: ${data['description'] ?? "Açıklama yok"}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => _updateNotificationStatus(
                          notificationId,
                          'approved',
                          data,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _updateNotificationStatus(
                          notificationId,
                          'rejected',
                          data,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
