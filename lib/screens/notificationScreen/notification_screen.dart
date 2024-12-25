import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:teilen2/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
        stream: _notificationService.getPendingNotifications(user.uid),
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
                        onPressed: () {
                          _notificationService.updateNotificationStatus(
                            notificationId: notificationId,
                            status: 'approved',
                            data: data,
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          _notificationService.updateNotificationStatus(
                            notificationId: notificationId,
                            status: 'rejected',
                            data: data,
                          );
                        },
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
