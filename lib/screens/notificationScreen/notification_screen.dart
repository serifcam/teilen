import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:teilen2/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Bildirimlerin listelendiği ekran
class NotificationScreen extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Kullanıcı oturum açmamışsa uyarı göster
    if (user == null) {
      return Center(
        child: Text('Kullanıcı oturum açmamış.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirimler'),
      ),

      // Bildirimleri gerçek zamanlı olarak dinleyen StreamBuilder
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService
            .getPendingNotifications(user.uid), // Bekleyen bildirimleri alır
        builder: (context, snapshot) {
          // Bildirim yoksa mesaj göster
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Hiçbir bildirim yok.'));
          }

          final notifications = snapshot.data!.docs;

          // Bildirimleri liste olarak göster
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final notificationId = doc.id;

              final type =
                  data['type'] ?? 'newDebt'; // Bildirim türü kontrol edilir

              String message = '';
              Widget leadingIcon = Icon(Icons.person); // Varsayılan ikon

              // Bildirim türüne göre mesaj ve ikon belirlenir
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

              // <b>etiketleri</b> içindeki miktarları yeşil ve kalın göstermek için metni işler
              final amountRegExp = RegExp(r'(<b>)(.*?)(</b>)');
              final spans = <TextSpan>[];
              final matches = amountRegExp.allMatches(message);

              int lastIndex = 0;
              for (final match in matches) {
                final normalText =
                    message.substring(lastIndex, match.start); // <b> öncesi
                final highlightedText = match.group(2)!; // vurgulanacak miktar

                spans.add(TextSpan(text: normalText)); // Normal yazı
                spans.add(
                  TextSpan(
                    text: highlightedText, // Vurgulu yazı
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );

                lastIndex = match.end;
              }

              // Son kalan metni de ekle
              if (lastIndex < message.length) {
                spans.add(TextSpan(text: message.substring(lastIndex)));
              }

              // Tek bir bildirim kartı olarak gösterilir
              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  leading: leadingIcon, // Türüne göre belirlenen ikon
                  title: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      children: spans, // Renkli miktar içeren yazı
                    ),
                  ),
                  subtitle: Text(
                    'Açıklama: ${data['description'] ?? "Açıklama yok"}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bildirimi onayla
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
                      // Bildirimi reddet
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
