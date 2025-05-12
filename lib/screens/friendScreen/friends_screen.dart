import 'package:flutter/material.dart';
import 'package:teilen2/screens/friendScreen/friend_requests_screen.dart';
import 'package:teilen2/screens/friendScreen/chat_screen.dart';
import 'package:teilen2/services/friend_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FriendService _friendService = FriendService();

  Map<String, bool> _unreadStatus = {};

  @override
  void initState() {
    super.initState();
    _loadUnreadStatuses();
  }

  Future<void> _loadUnreadStatuses() async {
    final friendsSnapshot = await _friendService.getFriendsStream().first;
    Map<String, bool> newStatus = {};
    for (var friend in friendsSnapshot) {
      bool hasUnread = await _friendService.hasUnreadMessage(friend['uid']);
      newStatus[friend['uid']] = hasUnread;
    }
    setState(() {
      _unreadStatus = newStatus;
    });
  }

  Future<void> _sendFriendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen bir e-posta adresi girin.')),
      );
      return;
    }

    try {
      await _friendService.sendFriendRequest(email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arkadaşlık isteği gönderildi!')),
      );
      _emailController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
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
        _loadUnreadStatuses();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Arkadaş silinirken hata oluştu: ${e.toString()}')),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Henüz arkadaşınız yok.'));
                }

                final friends = snapshot.data!;

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (ctx, index) {
                    final friend = friends[index];
                    final unread = _unreadStatus[friend['uid']] ?? false;

                    return Slidable(
                      key: ValueKey(friend['uid']),
                      endActionPane: ActionPane(
                        motion: DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    friendId: friend['uid'],
                                    friendName: friend['name'],
                                  ),
                                ),
                              ).then((_) =>
                                  _loadUnreadStatuses()); // 👈 dönüşte yeniden kontrol
                            },
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            icon: Icons.message,
                            label: 'Mesaj',
                          ),
                        ],
                      ),
                      child: ListTile(
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (unread)
                              Icon(Icons.mark_email_unread,
                                  color: Colors.orange),
                            IconButton(
                              icon: Icon(Icons.person_remove_alt_1,
                                  color: Colors.red),
                              onPressed: () {
                                _confirmAndRemoveFriend(friend['uid']);
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
          ),
        ],
      ),
    );
  }
}
