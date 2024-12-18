import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _acceptNotification(
      String notificationId, Map<String, dynamic> data) async {
    // Onayı kabul ettiğinde borcu ekle
    await _firestore.collection('individualDebts').add({
      'borrowerId': _auth.currentUser!.uid,
      'friendEmail': data['senderEmail'],
      'amount': data['amount'],
      'description': data['description'],
      'createdAt': Timestamp.now(),
    });

    // Bildirim durumunu güncelle
    await _firestore.collection('notifications').doc(notificationId).update({
      'status': 'accepted',
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirimler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('receiverId', isEqualTo: user!.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Yeni Borç Talebi'),
                  subtitle: Text(
                      'Tutar: ${data['amount']} TL\nAçıklama: ${data['description']}'),
                  trailing: IconButton(
                    icon: Icon(Icons.check, color: Colors.green),
                    onPressed: () =>
                        _acceptNotification(notifications[index].id, data),
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
