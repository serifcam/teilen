import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:teilen2/services/friend_request_service.dart';

class FriendRequestsScreen extends StatelessWidget {
  final FriendRequestService _friendRequestService = FriendRequestService();

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Arkadaşlık İstekleri'),
        elevation: 1.2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal.shade800,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _friendRequestService.getPendingFriendRequestsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_unread_rounded,
                      size: 62, color: Colors.teal.shade100),
                  SizedBox(height: 10),
                  Text(
                    'Bekleyen arkadaşlık isteği yok.',
                    style: TextStyle(
                        fontSize: 17,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            separatorBuilder: (c, i) => SizedBox(height: 10),
            itemCount: requests.length,
            itemBuilder: (ctx, i) {
              final doc = requests[i];
              final data = doc.data() as Map<String, dynamic>;

              return FutureBuilder<Map<String, dynamic>?>(
                future: _friendRequestService.getUserData(data['senderId']),
                builder: (ctx, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return _friendRequestShimmer();
                  }

                  final sender = userSnapshot.data!;
                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 13),
                      leading: sender['profileImageUrl'] != null
                          ? CircleAvatar(
                              backgroundImage:
                                  NetworkImage(sender['profileImageUrl']),
                              radius: 24,
                            )
                          : CircleAvatar(
                              child: Icon(Icons.person, color: Colors.teal),
                              backgroundColor: Colors.teal.shade50,
                              radius: 24,
                            ),
                      title: Text(
                        sender['name'] ?? 'Bilinmeyen',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      subtitle: Text(
                        sender['email'] ?? '',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: "Kabul Et",
                            child: IconButton(
                              icon: Icon(Icons.check_circle_rounded,
                                  color: Colors.green, size: 28),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text("Arkadaş Ekle"),
                                    content: Text(
                                        "Arkadaş eklemek istediğine emin misin?"),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text("Vazgeç")),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text("Evet",
                                            style:
                                                TextStyle(color: Colors.green)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _friendRequestService.updateRequestStatus(
                                    requestId: doc.id,
                                    status: 'accepted',
                                    senderId: data['senderId'],
                                  );
                                }
                              },
                            ),
                          ),
                          Tooltip(
                            message: "Reddet",
                            child: IconButton(
                              icon: Icon(Icons.cancel_rounded,
                                  color: Colors.red.shade400, size: 28),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text("Arkadaşlığı Reddet"),
                                    content: Text(
                                        "Arkadaşlık isteğini reddetmek istediğine emin misin?"),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text("Vazgeç")),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text("Evet",
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _friendRequestService.updateRequestStatus(
                                    requestId: doc.id,
                                    status: 'declined',
                                    senderId: data['senderId'],
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Yükleniyor shimmerı gibi - boş hali
Widget _friendRequestShimmer() {
  return Card(
    margin: EdgeInsets.zero,
    elevation: 0.5,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 13),
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Icon(Icons.hourglass_empty, color: Colors.teal.shade100),
      ),
      title: Container(
        width: 75,
        height: 16,
        color: Colors.grey.shade200,
      ),
      subtitle: Container(
        width: 40,
        height: 10,
        color: Colors.grey.shade100,
      ),
      trailing: SizedBox(width: 60, height: 18),
    ),
  );
}
