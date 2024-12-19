import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _updateNotificationStatus(
      String notificationId, String status, Map<String, dynamic> data) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'status': status,
    });

    if (status == 'approved') {
      if (data['type'] == 'add_request') {
        // Borç ekleme işlemi
        String borrowerId = data['relation'] == 'friend_to_me'
            ? data['toUser']
            : data['fromUser'];
        String creditorId = data['relation'] == 'friend_to_me'
            ? data['fromUser']
            : data['toUser'];

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
          'relation': 'me_to_friend',
          'description': data['description'] ?? "Açıklama yok",
          'createdAt': Timestamp.now(),
        });

        // Alacaklı için kayıt
        await _firestore.collection('individualDebts').add({
          'borrowerId': creditorId,
          'friendEmail': borrowerEmail,
          'amount': data['amount'] ?? 0.0,
          'relation': 'friend_to_me',
          'description': data['description'] ?? "Açıklama yok",
          'createdAt': Timestamp.now(),
        });
      } else if (data['type'] == 'delete_request') {
        // Borç silme işlemi
        await _firestore
            .collection('individualDebts')
            .doc(data['debtId'])
            .delete();
        await _firestore
            .collection('individualDebts')
            .where('borrowerId', isEqualTo: data['toUser'])
            .where('friendEmail', isEqualTo: data['fromUserEmail'])
            .get()
            .then((querySnapshot) {
          for (var doc in querySnapshot.docs) {
            doc.reference.delete();
          }
        });
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
              final data = notifications[index].data() as Map<String, dynamic>;
              final notificationId = notifications[index].id;
              final String message;
              if (data['type'] == 'add_request') {
                message = data['relation'] == 'me_to_friend'
                    ? "${data['fromUserEmail']} size ${data['amount']} TL borç ekledi."
                    : "Siz ${data['toUserEmail']} kişisine ${data['amount']} TL borç eklediniz.";
              } else if (data['type'] == 'delete_request') {
                message =
                    "${data['fromUserEmail']} borcun silinmesini istiyor.";
              } else {
                message = "Bilinmeyen bildirim.";
              }

              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(message),
                  subtitle: Text(
                      'Açıklama: ${data['description'] ?? "Açıklama yok"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => _updateNotificationStatus(
                            notificationId, 'approved', data),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _updateNotificationStatus(
                            notificationId, 'rejected', data),
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
