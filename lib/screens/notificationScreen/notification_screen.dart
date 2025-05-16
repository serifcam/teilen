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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final neutral = isDark ? Colors.grey.shade100 : Colors.grey.shade900;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Bildirimler',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal.shade700,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.getAllNotifications(user.uid),
        builder: (context, snapshot) {
          // HATA VARSA BURADA GÖSTER
          if (snapshot.hasError) {
            print('StreamBuilder ERROR: ${snapshot.error}');
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          // VERİ GELMEDİYSE LOADING GÖSTER
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          // GELEN BİLDİRİMLERİ KONSOLA YAZDIR
          print('Gelen bildirim sayısı: ${snapshot.data!.docs.length}');
          for (final doc in snapshot.data!.docs) {
            print('BİLDİRİM DATA: ${doc.data()}');
          }

          final notifications = snapshot.data!.docs;

          return ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            itemCount: notifications.length,
            separatorBuilder: (c, i) => SizedBox(height: 6),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final notificationId = doc.id;

              final type = data['type'] ?? 'newDebt';
              final status = data['status'] ?? 'pending';

              String message = '';
              IconData iconData = Icons.notifications;
              Color iconColor = Colors.teal.shade300;

              if (type == 'newDebt') {
                iconData = Icons.person_rounded;
                iconColor = Colors.teal.shade400;
                if (data['relation'] == 'me_to_friend') {
                  message =
                      "${data['fromUserEmail'] ?? "Bilinmeyen Kullanıcı"} size <b>${data['amount'] ?? 0} TL</b> borç ekledi.";
                } else {
                  message =
                      "Siz ${data['toUserEmail'] ?? "Bilinmeyen Kullanıcı"} kişisine <b>${data['amount'] ?? 0} TL</b> borç eklediniz.";
                }
              } else if (type == 'debtPaid' || type == 'paymentInfo') {
                iconData = Icons.attach_money_rounded;
                iconColor = Colors.orange.shade400;
                final fromUserEmail =
                    data['fromUserEmail'] ?? 'Bilinmeyen Kullanıcı';
                final amount = data['amount'] ?? 0;
                message =
                    "🪙 $fromUserEmail, size olan <b>$amount TL</b> borcunu ödemiştir.";
              } else if (type == 'groupRequest') {
                iconData = Icons.groups_2_rounded;
                iconColor = Colors.teal.shade400;
                final groupName = data['groupName'] ?? 'Grup';
                final totalAmount = (data['amount'] ?? 0).toDouble();

                // Kişi başı miktarı hesapla
                int kisiSayisi = 1;
                if (data['memberIds'] != null && data['memberIds'] is List) {
                  kisiSayisi = (data['memberIds'] as List).length;
                  if (kisiSayisi < 1) kisiSayisi = 1;
                }
                final perPersonAmount =
                    (kisiSayisi > 0 ? totalAmount / kisiSayisi : totalAmount)
                        .toStringAsFixed(2);

                final groupCreatorName =
                    data['fromUserName'] ?? 'Bir kullanıcı';

                // 🔥 DÜZELTİLDİ: Kişi başına düşen borç gösterilecek!
                message =
                    "💬 $groupCreatorName sizinle \"$groupName\" grubunu oluşturmak istiyor. Kişi başı <b>$perPersonAmount TL</b> ödeme düşüyor.";
              } else if (type == 'debtPayment') {
                iconData = Icons.payments_rounded;
                iconColor = Colors.green.shade400;
                final fromUserEmail = data['fromUserEmail'] ?? 'Bir kullanıcı';
                final groupName = data['groupName'] ?? 'bir grup';
                final amount = data['amount'] ?? 0;
                message =
                    "💸 $fromUserEmail, \"$groupName\" grubundaki <b>$amount TL</b> borcunu ödedi.";
              }

              // <b>...</b> arasını vurgulu göster
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
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );

                lastIndex = match.end;
              }

              if (lastIndex < message.length) {
                spans.add(TextSpan(text: message.substring(lastIndex)));
              }

              // KART YAPISI
              final card = Card(
                elevation: 3,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                color: Colors.white,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.18),
                      child: Icon(iconData, color: iconColor, size: 26),
                      radius: 22,
                    ),
                    title: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: neutral,
                          fontSize: 14.8,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                        children: spans,
                      ),
                    ),
                    subtitle:
                        data['description'] != null && data['description'] != ''
                            ? Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  'Açıklama: ${data['description']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12.8,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              )
                            : null,
                    trailing: status == 'pending'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: "Kabul Et",
                                child: IconButton(
                                  icon: Icon(Icons.check_circle_rounded,
                                      color: Colors.green, size: 27),
                                  onPressed: () {
                                    _notificationService
                                        .updateNotificationStatus(
                                      notificationId: notificationId,
                                      status: 'approved',
                                      data: data,
                                    );
                                  },
                                ),
                              ),
                              Tooltip(
                                message: "Reddet",
                                child: IconButton(
                                  icon: Icon(Icons.cancel_rounded,
                                      color: Colors.red.shade400, size: 27),
                                  onPressed: () {
                                    _notificationService
                                        .updateNotificationStatus(
                                      notificationId: notificationId,
                                      status: 'rejected',
                                      data: data,
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              );

              // Sadece info olanlar kaydırarak silinebilir!
              if (status == 'info') {
                return Dismissible(
                  key: Key(notificationId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete_forever_rounded,
                        color: Colors.white, size: 30),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        title: Text('Bildirim silinsin mi?'),
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
                  child: card,
                );
              }
              return card;
            },
          );
        },
      ),
    );
  }
}
