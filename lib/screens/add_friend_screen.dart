import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddFriendScreen extends StatefulWidget {
  @override
  _AddFriendScreenState createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _sendFriendRequest() async {
    final currentUser = _auth.currentUser;

    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen bir e-posta adresi girin')),
      );
      return;
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: _emailController.text)
          .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kullanıcı bulunamadı!')),
        );
        return;
      }

      final receiverId = querySnapshot.docs.first.id;

      await _firestore.collection('friendRequests').add({
        'senderId': currentUser!.uid,
        'receiverId': receiverId,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arkadaşlık isteği gönderildi!')),
      );
      _emailController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  void _showFriendsList() async {
    final currentUser = _auth.currentUser;

    final userDoc =
        await _firestore.collection('users').doc(currentUser!.uid).get();

    if (!userDoc.exists) return;

    List friends = userDoc.data()?['friends'] ?? [];

    // Arkadaşları gösteren Dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arkadaşlarım'),
        content: friends.isEmpty
            ? Text('Henüz arkadaşınız yok.')
            : Container(
                width: double.maxFinite,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .where('uid', whereIn: friends)
                      .snapshots(),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final friendDocs = snapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: friendDocs.length,
                      itemBuilder: (ctx, index) {
                        final friendData =
                            friendDocs[index].data() as Map<String, dynamic>;
                        final friendId = friendDocs[index].id;

                        return ListTile(
                          leading: Icon(Icons.person),
                          title: Text(
                              friendData['name'] ?? 'Bilinmeyen Kullanıcı'),
                          subtitle: Text(friendData['email'] ?? ''),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _confirmAndRemoveFriend(
                                  friendId, currentUser.uid);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _confirmAndRemoveFriend(String friendId, String currentUserId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arkadaşı Sil'),
        content: Text('Bu arkadaşınızı silmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(), // Hayır butonu
            child: Text('Hayır'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop(); // Dialog'u kapat
              await _removeFriend(
                  friendId, currentUserId); // Silme işlemini gerçekleştir
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Arkadaş başarıyla silindi')),
              );
            },
            child: Text('Evet', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFriend(String friendId, String currentUserId) async {
    try {
      // Kullanıcının arkadaş listesinden kaldır
      await _firestore.collection('users').doc(currentUserId).update({
        'friends': FieldValue.arrayRemove([friendId])
      });

      // Arkadaşın arkadaş listesinden de kullanıcıyı kaldır
      await _firestore.collection('users').doc(friendId).update({
        'friends': FieldValue.arrayRemove([currentUserId])
      });
    } catch (e) {
      print('Arkadaş silme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arkadaş silinirken hata oluştu!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Arkadaş Ekle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration:
                      InputDecoration(labelText: 'Arkadaşın E-posta Adresi'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _sendFriendRequest,
                  child: Text('Arkadaşlık İsteği Gönder'),
                ),
              ],
            ),
          ),
          Expanded(
              child:
                  FriendRequestsWidget()), // Arkadaşlık isteklerini gösteren widget
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFriendsList,
        child: Icon(Icons.group),
        tooltip: 'Arkadaşlarım',
      ),
    );
  }
}

class FriendRequestsWidget extends StatelessWidget {
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

    return StreamBuilder<QuerySnapshot>(
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
                  title: Text(senderData['name'] ?? 'Bilinmeyen Kullanıcı'),
                  subtitle: Text(senderData['email']),
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
    );
  }
}
