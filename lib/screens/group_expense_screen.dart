import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_detail_screen.dart';

class GroupExpenseScreen extends StatefulWidget {
  @override
  _GroupExpenseScreenState createState() => _GroupExpenseScreenState();
}

class _GroupExpenseScreenState extends State<GroupExpenseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _groupDescriptionController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  List<String> _selectedFriends = [];
  List<Map<String, dynamic>> _friendsList = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    List friends = userDoc.data()?['friends'] ?? [];

    if (friends.isNotEmpty) {
      final querySnapshot = await _firestore
          .collection('users')
          .where('uid', whereIn: friends)
          .get();

      setState(() {
        _friendsList = querySnapshot.docs.map((doc) {
          return {
            'uid': doc.id,
            'email': doc.data()['email'] ?? 'Bilinmeyen E-posta',
          };
        }).toList();
      });
    }
  }

  Future<void> _createGroup() async {
    final user = _auth.currentUser;

    if (_groupDescriptionController.text.isEmpty ||
        _selectedFriends.isEmpty ||
        _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm alanları doldurun!')),
      );
      return;
    }

    double totalAmount = double.parse(_amountController.text);
    double splitAmount = totalAmount / (_selectedFriends.length + 1);
    final allMembers = [..._selectedFriends, user!.uid];

    try {
      DocumentReference groupRef = await _firestore.collection('groups').add({
        'groupName': _groupDescriptionController.text,
        'createdBy': user.uid,
        'members': allMembers,
        'createdAt': Timestamp.now(),
      });

      for (var memberId in allMembers) {
        await _firestore.collection('debts').add({
          'groupId': groupRef.id,
          'fromUser': memberId,
          'toUser': user.uid,
          'amount': splitAmount,
          'status': 'pending',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grup ve borçlar başarıyla oluşturuldu!')),
      );

      _groupDescriptionController.clear();
      _amountController.clear();
      setState(() => _selectedFriends = []);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Üyeleri Seç
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Üyeleri Seç',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  onTap: _showMemberSelectionDialog,
                ),
                SizedBox(height: 10),

                // Toplam Borç Tutarı
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Toplam Borç Tutarı',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 10),

                // Açıklama
                TextField(
                  controller: _groupDescriptionController,
                  decoration: InputDecoration(
                    labelText: 'Açıklama',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _createGroup,
                    child: Text('Grup Oluştur'),
                  ),
                ),
              ],
            ),
          ),
          Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .where('members', arrayContains: user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final groups = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) =>
                      _buildGroupCard(groups[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(DocumentSnapshot groupDoc) {
    final groupData = groupDoc.data() as Map<String, dynamic>;
    final createdAt =
        groupData['createdAt'] as Timestamp?; // Tarih ve saat bilgisi

    String formattedDate = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} ${createdAt.toDate().hour}:${createdAt.toDate().minute}'
        : 'Tarih Bilinmiyor'; // Tarih formatı

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Icon(Icons.group, color: Colors.teal),
        title: Text(groupData['groupName'] ?? 'Grup İsmi Yok'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Üye Sayısı: ${groupData['members'].length} kişi'),
            SizedBox(height: 4),
            Text(
              'Oluşturulma Tarihi: $formattedDate',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => GroupDetailScreen(
              groupId: groupDoc.id,
              groupName: groupData['groupName'] ?? 'Grup Detay',
            ),
          ));
        },
      ),
    );
  }

  void _showMemberSelectionDialog() {
    List<String> tempSelectedFriends = List.from(_selectedFriends);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Üyeleri Seç'),
            content: Container(
              height: 300,
              width: double.maxFinite,
              child: ListView(
                children: _friendsList.map((friend) {
                  return CheckboxListTile(
                    title: Text(friend['email']),
                    value: tempSelectedFriends.contains(friend['uid']),
                    onChanged: (isChecked) {
                      setDialogState(() {
                        if (isChecked!) {
                          tempSelectedFriends.add(friend['uid']);
                        } else {
                          tempSelectedFriends.remove(friend['uid']);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFriends = List.from(tempSelectedFriends);
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text('Tamam'),
              ),
            ],
          );
        },
      ),
    );
  }
}
