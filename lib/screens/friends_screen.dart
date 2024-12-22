import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'friend_requests_screen.dart';

class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
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

    if (_emailController.text == currentUser!.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kendinize arkadaşlık isteği yollayamazsınız')),
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
        'senderId': currentUser.uid,
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

  Future<void> _confirmAndRemoveFriend(
      String friendId, String currentUserId) async {
    final result = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arkadaşı Sil'),
        content:
            Text('Arkadaş listenizden çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Evet', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _firestore.collection('users').doc(currentUserId).update({
          'friends': FieldValue.arrayRemove([friendId])
        });

        await _firestore.collection('users').doc(friendId).update({
          'friends': FieldValue.arrayRemove([currentUserId])
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arkadaş başarıyla silindi')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arkadaş silinirken hata oluştu!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Arkadaşlarım'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FriendRequestsScreen(),
              ),
            ),
            tooltip: 'Arkadaşlık İstekleri',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Arkadaşın E-posta Adresi',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return Center(child: CircularProgressIndicator());
                }

                List friends = snapshot.data!['friends'] ?? [];

                if (friends.isEmpty) {
                  return Center(child: Text('Henüz arkadaşınız yok.'));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .where('uid', whereIn: friends)
                      .snapshots(),
                  builder: (ctx, friendsSnapshot) {
                    if (!friendsSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final friendDocs = friendsSnapshot.data!.docs;

                    return ListView.builder(
                      itemCount: friendDocs.length,
                      itemBuilder: (ctx, index) {
                        final friendData =
                            friendDocs[index].data() as Map<String, dynamic>;
                        final friendId = friendDocs[index].id;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundImage: friendData['profileImageUrl'] !=
                                    null
                                ? NetworkImage(friendData['profileImageUrl'])
                                : null,
                            child: friendData['profileImageUrl'] == null
                                ? Icon(Icons.person, size: 20)
                                : null,
                          ),
                          title: Text(friendData['email'] ?? ''),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
