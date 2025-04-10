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
              Widget leadingIcon = Icon(Icons.person); // Varsayılan ikon

              if (type == 'newDebt') {
                leadingIcon = Icon(Icons.person, color: Colors.teal);
                if (data['relation'] == 'me_to_friend') {
                  message =
                      "${data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı"} size "
                      "<b>${data['amount'] ?? 0} TL</b> borç ekledi.";
                } else {
                  message =
                      "Siz ${data['toUserEmail'] ?? "Bilinmeyen Kullanıcı"} kişisine "
                      "<b>${data['amount'] ?? 0} TL</b> borç eklediniz.";
                }
              } else if (type == 'debtPaid') {
                final fromUserEmail =
                    data['fromUserEmail'] ?? 'Bilinmeyen Kullanıcı';
                final amount = data['amount'] ?? 0;
                message =
                    "$fromUserEmail, <b>$amount TL</b> borcunu ödemiştir.";
                leadingIcon = Icon(Icons.attach_money, color: Colors.orange);
              } else if (type == 'groupDebt') {
                final fromUserEmail =
                    data['fromUserEmail'] ?? 'Bilinmeyen Kullanıcı';
                final amount = data['amount'] ?? 0;
                message =
                    "$fromUserEmail, size <b>$amount TL</b> grup borcu ekledi.";
                leadingIcon = Icon(Icons.groups, color: Colors.blue);
              }

              // Miktarı yeşil renkle vurgulamak için metin parçalama
              final amountRegExp = RegExp(r'(<b>)(.*?)(</b>)');
              final spans = <TextSpan>[];
              final matches = amountRegExp.allMatches(message);

              int lastIndex = 0;
              for (final match in matches) {
                final normalText = message.substring(lastIndex, match.start);
                final highlightedText = match.group(2)!;

                spans.add(TextSpan(text: normalText));
                spans.add(
                  TextSpan(
                    text: highlightedText,
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );

                lastIndex = match.end;
              }

              // Kalan metni ekle
              if (lastIndex < message.length) {
                spans.add(TextSpan(text: message.substring(lastIndex)));
              }

              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  leading: leadingIcon,
                  title: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      children: spans,
                    ),
                  ),
                  subtitle: Text(
                    'Açıklama: ${data['description'] ?? "Açıklama yok"}',
                    style: TextStyle(color: Colors.grey[700]),
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
