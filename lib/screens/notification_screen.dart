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
      // Bildirim onaylandığında borcu hem borçluya hem de alacaklıya ekle
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

              final String message = data['relation'] == 'me_to_friend'
                  ? "${data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı"} size ${data['amount'] ?? 0} TL borç ekledi."
                  : "Siz ${data['toUserEmail'] ?? "Bilinmeyen Kullanıcı"} kişisine ${data['amount'] ?? 0} TL borç eklediniz.";

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
