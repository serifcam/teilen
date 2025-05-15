import 'package:flutter/material.dart';
import 'package:teilen2/screens/friendScreen/friend_requests_screen.dart';
import 'package:teilen2/screens/friendScreen/chat_screen.dart';
import 'package:teilen2/services/friend_service.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Arkadaşı Sil'),
        content:
            Text('Arkadaş listenizden çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Hayır'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Evet'),
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
    final Color mainTeal = Colors.teal.shade600;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade900
          : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Arkadaşlarım',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
            letterSpacing: 0.2,
            fontFamily:
                'Nunito', // istersen başka bir Google Font da ekleyebilirsin!
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: mainTeal,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1, color: mainTeal),
            tooltip: 'Gelen İstekler',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FriendRequestsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Arkadaş ekleme paneli
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: "E-posta ile arkadaş ekle",
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sendFriendRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1,
                    size: 22,
                    color: const Color.fromARGB(255, 253, 245, 245),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Divider(indent: 10, endIndent: 10, thickness: 1, height: 16),
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
                  padding: EdgeInsets.only(top: 8, bottom: 16),
                  itemBuilder: (ctx, index) {
                    final friend = friends[index];
                    final unread = _unreadStatus[friend['uid']] ?? false;

                    return Card(
                      elevation: 1.5,
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundImage: friend['profileImageUrl'] != null
                                  ? NetworkImage(friend['profileImageUrl'])
                                  : null,
                              backgroundColor: Colors.teal.shade50,
                              child: friend['profileImageUrl'] == null
                                  ? Icon(Icons.person,
                                      color: Colors.teal, size: 28)
                                  : null,
                            ),
                            if (unread)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade400,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.mail,
                                        size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          friend['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: mainTeal,
                          ),
                        ),
                        subtitle: Text(
                          friend['email'],
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                        trailing: PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) {
                            if (value == 'mesaj') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    friendId: friend['uid'],
                                    friendName: friend['name'],
                                  ),
                                ),
                              ).then((_) => _loadUnreadStatuses());
                            } else if (value == 'sil') {
                              _confirmAndRemoveFriend(friend['uid']);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'mesaj',
                              child: Row(
                                children: [
                                  Icon(Icons.message,
                                      color: mainTeal, size: 19),
                                  SizedBox(width: 7),
                                  Text("Mesajlaş"),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'sil',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove_alt_1,
                                      color: Colors.red.shade400, size: 19),
                                  SizedBox(width: 7),
                                  Text("Arkadaşı Sil"),
                                ],
                              ),
                            ),
                          ],
                          icon: Icon(Icons.more_vert,
                              color: Colors.teal.shade700),
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
