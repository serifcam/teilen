import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teilen2/services/group_service.dart';
import 'package:teilen2/screens/groupScreen/group_detail_screen.dart';

class GroupCreateScreen extends StatefulWidget {
  @override
  _GroupCreateScreenState createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<String> _selectedFriends = [];
  List<Map<String, dynamic>> _friendsList = [];

  final GroupService _groupService = GroupService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isNotEqualTo: currentUser.uid)
        .get();

    setState(() {
      _friendsList = snapshot.docs
          .map((doc) => {
                'uid': doc['uid'],
                'email': doc['email'],
              })
          .toList();
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    final totalAmount =
        double.tryParse(_totalAmountController.text.trim()) ?? 0;
    final description = _descriptionController.text.trim();

    if (groupName.isEmpty || totalAmount <= 0 || _selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm alanları doldurun ve üye seçin!')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Kullanıcı bulunamadı.');

      List<String> memberIds = List.from(_selectedFriends);
      memberIds.add(currentUser.uid); // Kurucuyu da ekle

      await _groupService.createGroup(
        groupName: groupName,
        memberIds: memberIds,
        totalAmount: totalAmount,
        description: description,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('✅ Grup oluşturuldu, üyelerden onay bekleniyor!')),
      );

      // Formu temizle
      _groupNameController.clear();
      _totalAmountController.clear();
      _descriptionController.clear();
      setState(() => _selectedFriends = []);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hata: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGroupCard(DocumentSnapshot groupDoc) {
    final groupData = groupDoc.data() as Map<String, dynamic>;
    final createdAt = groupData['createdAt'] as Timestamp?;

    String formattedDate = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} '
            '${createdAt.toDate().hour}:${createdAt.toDate().minute}'
        : 'Tarih Bilinmiyor';

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Icon(Icons.groups, color: Colors.teal),
        title: Text(groupData['name'] ?? 'Grup İsmi Yok'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Üye Sayısı: ${(groupData['memberIds'] as List).length}'),
            SizedBox(height: 4),
            Text(
              'Toplam Tutar: ${(groupData['totalAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'} ₺',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            SizedBox(height: 4),
            Text(
              'Oluşturulma Tarihi: $formattedDate',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(
                groupId: groupDoc.id,
                groupName: groupData['name'] ?? 'Grup Detay',
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMemberSelectionDialog() {
    List<String> tempSelectedFriends = List.from(_selectedFriends);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grup Oluştur'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showMemberSelectionDialog,
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText:
                            'Üyeleri Seç (${_selectedFriends.length} kişi)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    labelText: 'Grup İsmi',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _totalAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Toplam Tutar (₺)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Açıklama (Opsiyonel)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  child: _isLoading
                      ? CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text('Grubu Oluştur'),
                ),
              ],
            ),
          ),
          Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _groupService.getUserGroups(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text('Bir hata oluştu: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Henüz oluşturulmuş grup yok.'));
                }

                final groups = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    return _buildGroupCard(groups[index]);
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
