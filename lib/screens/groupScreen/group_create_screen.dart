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

    String formattedDate = 'Tarih Bilinmiyor';
    if (createdAt != null) {
      // +3 saat ekledik bro
      final DateTime localDate =
          createdAt.toDate().add(const Duration(hours: 3));
      formattedDate = '${localDate.day.toString().padLeft(2, '0')}/'
          '${localDate.month.toString().padLeft(2, '0')}/'
          '${localDate.year} '
          '${localDate.hour.toString().padLeft(2, '0')}:'
          '${localDate.minute.toString().padLeft(2, '0')}';
    }
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 7, horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: Container(
          decoration: BoxDecoration(
            color: Colors.teal.shade100.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.all(10),
          child:
              Icon(Icons.groups_rounded, color: Colors.teal.shade700, size: 28),
        ),
        title: Text(
          groupData['name'] ?? 'Grup İsmi Yok',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            letterSpacing: 0.1,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: Colors.teal.shade400, size: 16),
                  SizedBox(width: 3),
                  Text(
                    'Üye: ${(groupData['memberIds'] as List).length}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  SizedBox(width: 18),
                  Icon(Icons.attach_money,
                      color: Colors.orange.shade300, size: 16),
                  SizedBox(width: 2),
                  Text(
                    '${(groupData['totalAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'} ₺',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              SizedBox(height: 3),
              Text(
                'Oluşturulma: $formattedDate',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            color: Colors.teal.shade300, size: 22),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Üyeleri Seç',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Container(
              height: 320,
              width: double.maxFinite,
              child: ListView(
                children: _friendsList.map((friend) {
                  return CheckboxListTile(
                    title: Text(friend['email']),
                    value: tempSelectedFriends.contains(friend['uid']),
                    activeColor: Colors.teal.shade400,
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
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal.shade700,
                  textStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
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
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:
          BorderSide(color: const Color.fromARGB(255, 68, 66, 66), width: 1),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Grup Oluştur',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
            letterSpacing: 0.2,
            fontFamily: 'Nunito',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.teal.shade800,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Material(
              borderRadius: BorderRadius.circular(18),
              elevation: 1,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showMemberSelectionDialog,
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                'Üyeleri Seç (${_selectedFriends.length} kişi)',
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                                borderSide: BorderSide(
                                    color: Colors.teal.shade300, width: 1.8)),
                            suffixIcon: Icon(Icons.arrow_drop_down,
                                color: Colors.teal.shade400),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _groupNameController,
                      decoration: InputDecoration(
                        labelText: 'Grup İsmi',
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(
                                color: Colors.teal.shade300, width: 1.8)),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _totalAmountController,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Toplam Tutar (₺)',
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(
                                color: Colors.teal.shade300, width: 1.8)),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Açıklama (Opsiyonel)',
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(
                                color: Colors.teal.shade300, width: 1.8)),
                      ),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.group_add_rounded,
                                color: Colors.white, size: 22),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            _isLoading ? '' : 'Grubu Oluştur',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        onPressed: _isLoading ? null : _createGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
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
