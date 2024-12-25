import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:teilen2/services/friend_request_service.dart';

class FriendRequestsScreen extends StatelessWidget {
  final FriendRequestService _friendRequestService = FriendRequestService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Arkadaşlık İstekleri'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _friendRequestService.getPendingFriendRequestsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Arkadaşlık isteği yok.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return FutureBuilder<Map<String, dynamic>?>(
                future: _friendRequestService.getUserData(data['senderId']),
                builder: (ctx, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return ListTile(
                      title: Text('Bilinmeyen Kullanıcı'),
                      subtitle: Text('Yükleniyor...'),
                    );
                  }
                  final senderData = userSnapshot.data!;
                  return ListTile(
                    leading: senderData['profileImageUrl'] != null
                        ? CircleAvatar(
                            backgroundImage:
                                NetworkImage(senderData['profileImageUrl']),
                          )
                        : CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                    title: Text(senderData['name'] ?? 'Bilinmeyen İsim'),
                    subtitle: Text(senderData['email'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            _friendRequestService.updateRequestStatus(
                              requestId: doc.id,
                              status: 'accepted',
                              senderId: data['senderId'],
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            _friendRequestService.updateRequestStatus(
                              requestId: doc.id,
                              status: 'declined',
                              senderId: data['senderId'],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
