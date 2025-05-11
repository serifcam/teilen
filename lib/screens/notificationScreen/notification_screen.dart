import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/services/notification_service.dart';

class NotificationScreen extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text('Kullanıcı oturum açmamış.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirimler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.getAllNotifications(user.uid),
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
              final status = data['status'] ?? 'pending';

              String message = '';
              Widget leadingIcon =
                  Icon(Icons.notifications, color: Colors.grey);

              if (type == 'newDebt') {
                leadingIcon = Icon(Icons.person, color: Colors.teal);
                if (data['relation'] == 'me_to_friend') {
                  message =
                      "${data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı"} size <b>${data['amount'] ?? 0} TL</b> borç ekledi.";
                } else {
                  message =
                      "Siz ${data['toUserEmail'] ?? "Bilinmeyen Kullanıcı"} kişisine <b>${data['amount'] ?? 0} TL</b> borç eklediniz.";
                }
              } else if (type == 'debtPaid' || type == 'paymentInfo') {
                final fromUserEmail =
                    data['fromUserEmail'] ?? 'Bilinmeyen Kullanıcı';
                final amount = data['amount'] ?? 0;
                message =
                    "🪙 $fromUserEmail, size olan <b>$amount TL</b> borcunu ödemiştir.";
                leadingIcon = Icon(Icons.attach_money, color: Colors.orange);
              } else if (type == 'groupRequest') {
                final groupName = data['groupName'] ?? 'Grup';
                final amount = data['amount'] ?? 0;
                final groupCreatorName =
                    data['fromUserName'] ?? 'Bir kullanıcı';
                message =
                    "💬 $groupCreatorName sizinle \"$groupName\" grubunu oluşturmak istiyor. Kişi başı <b>$amount TL</b> ödeme düşüyor.";
                leadingIcon = Icon(Icons.groups_2_rounded, color: Colors.teal);
              } else if (type == 'debtPayment') {
                final fromUserEmail = data['fromUserEmail'] ?? 'Bir kullanıcı';
                final groupName = data['groupName'] ?? 'bir grup';
                final amount = data['amount'] ?? 0;
                message =
                    "💸 $fromUserEmail, \"$groupName\" grubundaki <b>$amount TL</b> borcunu ödedi.";
                leadingIcon =
                    Icon(Icons.payments_outlined, color: Colors.green);
              }

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

              if (lastIndex < message.length) {
                spans.add(TextSpan(text: message.substring(lastIndex)));
              }

              // 🔥 Eğer "info" veya "debtPaid" bildirimi ise kaydırarak silelim
              if (status == 'info') {
                return Dismissible(
                  key: Key(notificationId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Bildirim Silinsin mi?'),
                        content: Text('Bu bildirim silinecek, emin misin?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Hayır'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Evet',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) async {
                    await _notificationService
                        .deleteNotification(notificationId);
                  },
                  child: Card(
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
                    ),
                  ),
                );
              }

              // 🔥 Eğer pending borç bildirimi ise eski sistem devam
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
