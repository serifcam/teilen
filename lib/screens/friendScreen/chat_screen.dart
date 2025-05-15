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
    final sorted = [uid1, uid2]..sort();
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
      'isRead': false,
      'deletedBy': [],
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

  Future<void> _deleteMessage(DocumentSnapshot data) async {
    final currentUser = _auth.currentUser!;
    final docRef = _firestore.collection('quickMessages').doc(data.id);

    final deletedBy = (data.data() as Map<String, dynamic>)['deletedBy'] is List
        ? List<String>.from(data['deletedBy'])
        : <String>[];

    if (!deletedBy.contains(currentUser.uid)) {
      deletedBy.add(currentUser.uid);
    }

    if (deletedBy.contains(widget.friendId)) {
      await docRef.delete();
    } else {
      await docRef.update({'deletedBy': deletedBy});
    }
  }

  Future<void> _showDeleteConfirmDialog(DocumentSnapshot messageDoc) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Mesajı Sil'),
        content: Text('Bu mesajı silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hayır'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Evet'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _deleteMessage(messageDoc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser!;
    final chatKey = _generateChatKey(currentUser.uid, widget.friendId);
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Icon(Icons.person, color: Colors.teal.shade700),
              radius: 18,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(widget.friendName,
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        elevation: 1.2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal.shade800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: SafeArea(
        child: Column(
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

                  return ListView.separated(
                    reverse: false,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    separatorBuilder: (context, i) => SizedBox(height: 5),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final data = messages[index];
                      final isMe = data['senderId'] == currentUser.uid;

                      final deletedBy =
                          List<String>.from(data['deletedBy'] ?? []);
                      if (deletedBy.contains(currentUser.uid)) {
                        return SizedBox.shrink();
                      }

                      return GestureDetector(
                        onLongPress: () => _showDeleteConfirmDialog(data),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.teal.shade50,
                                child: Icon(Icons.person,
                                    color: Colors.teal, size: 19),
                              ),
                              SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 11, horizontal: 15),
                                margin: EdgeInsets.only(
                                  left: isMe ? 40 : 0,
                                  right: isMe ? 0 : 40,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.teal.shade400
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(isMe ? 20 : 6),
                                    topRight: Radius.circular(isMe ? 6 : 20),
                                    bottomLeft: Radius.circular(14),
                                    bottomRight: Radius.circular(14),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['message'],
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.grey.shade900,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(data['timestamp']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.grey.shade200
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              SizedBox(width: 6),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(10, 6, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: Offset(0, -1))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.teal.shade100),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.teal.shade400,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.shade100,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
