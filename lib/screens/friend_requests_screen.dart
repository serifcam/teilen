import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendRequestsScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _updateRequestStatus(
      String requestId, String status, String senderId) async {
    final currentUser = _auth.currentUser;

    await _firestore.collection('friendRequests').doc(requestId).update({
      'status': status,
    });

    if (status == 'accepted') {
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'friends': FieldValue.arrayUnion([senderId]),
      });

      await _firestore.collection('users').doc(senderId).update({
        'friends': FieldValue.arrayUnion([currentUser.uid]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Arkadaşlık İstekleri'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('friendRequests')
            .where('receiverId', isEqualTo: currentUser!.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Arkadaşlık isteği yok.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return FutureBuilder<DocumentSnapshot>(
                future:
                    _firestore.collection('users').doc(data['senderId']).get(),
                builder: (ctx, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return ListTile(
                      title: Text('Bilinmeyen Kullanıcı'),
                      subtitle: Text('Yükleniyor...'),
                    );
                  }
                  final senderData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
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
                          onPressed: () => _updateRequestStatus(
                              doc.id, 'accepted', data['senderId']),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _updateRequestStatus(
                              doc.id, 'declined', data['senderId']),
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
