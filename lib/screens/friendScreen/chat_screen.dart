import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  ChatScreen({required this.friendId, required this.friendName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  String _generateChatKey(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort(); // UID'leri sırala
    return '${sorted[0]}_${sorted[1]}';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final dateTime = (timestamp as Timestamp).toDate().add(Duration(hours: 3));
    final dateStr =
        '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr $timeStr';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final currentUser = _auth.currentUser!;
    final chatKey = _generateChatKey(currentUser.uid, widget.friendId);

    await _firestore.collection('quickMessages').add({
      'senderId': currentUser.uid,
      'receiverId': widget.friendId,
      'message': text,
      'timestamp': Timestamp.now(),
      'chatKey': chatKey,
      'isRead': false, // 🔥 GÖNDERİRKEN UNREAD
    });

    _controller.clear();
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = _auth.currentUser!;
    final chatKey = _generateChatKey(currentUser.uid, widget.friendId);

    final unread = await _firestore
        .collection('quickMessages')
        .where('chatKey', isEqualTo: chatKey)
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser!;
    final chatKey = _generateChatKey(currentUser.uid, widget.friendId);

    return Scaffold(
      appBar: AppBar(title: Text(widget.friendName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('quickMessages')
                  .where('chatKey', isEqualTo: chatKey)
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index];
                    final isMe = data['senderId'] == currentUser.uid;

                    return Dismissible(
                      key: ValueKey(data.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        _firestore
                            .collection('quickMessages')
                            .doc(data.id)
                            .delete();
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        title: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.teal : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  data['message'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(data['timestamp']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: 'Mesaj...'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
