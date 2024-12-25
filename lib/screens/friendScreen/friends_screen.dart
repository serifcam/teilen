import 'package:flutter/material.dart';
import 'package:teilen2/screens/friendScreen/friend_requests_screen.dart';
import 'package:teilen2/services/friend_service.dart';

class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FriendService _friendService = FriendService();

  Future<void> _sendFriendRequest() async {
    try {
      await _friendService.sendFriendRequest(_emailController.text);
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

  Future<void> _confirmAndRemoveFriend(String friendId) async {
    final result = await showDialog<bool>(
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
        await _friendService.removeFriend(friendId);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Arkadaşlarım'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () {
              // Arkadaşlık İstekleri Ekranı
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FriendRequestsScreen(),
                ),
              );
            },
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _friendService.getFriendsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final friends = snapshot.data!;

                if (friends.isEmpty) {
                  return Center(child: Text('Henüz arkadaşınız yok.'));
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (ctx, index) {
                    final friend = friends[index];
                    return ListTile(
                      leading: friend['profileImageUrl'] != null
                          ? CircleAvatar(
                              backgroundImage:
                                  NetworkImage(friend['profileImageUrl']),
                            )
                          : CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                      title: Text(friend['name']),
                      subtitle: Text(friend['email']),
                      trailing: IconButton(
                        icon:
                            Icon(Icons.person_remove_alt_1, color: Colors.red),
                        onPressed: () {
                          _confirmAndRemoveFriend(friend['uid']);
                        },
                      ),
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
