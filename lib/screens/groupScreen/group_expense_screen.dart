import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/services/group_service.dart';
import 'package:teilen2/screens/groupScreen/group_detail_screen.dart';

class GroupExpenseScreen extends StatefulWidget {
  @override
  _GroupExpenseScreenState createState() => _GroupExpenseScreenState();
}

class _GroupExpenseScreenState extends State<GroupExpenseScreen> {
  final TextEditingController _groupDescriptionController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  List<String> _selectedFriends = []; // Seçilen arkadaşların UID listesi
  List<Map<String, dynamic>> _friendsList = []; // Kullanıcının arkadaş listesi

  // Servis katmanından bir örnek (instance) oluşturuyoruz
  final GroupService _groupService = GroupService();

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  /// Arkadaş listesini servisten çeker
  Future<void> _loadFriends() async {
    try {
      final friends = await _groupService.loadFriends();
      setState(() {
        _friendsList = friends;
      });
    } catch (e) {
      print('Arkadaş listesi yüklenirken hata oluştu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arkadaş listesi yüklenirken hata oluştu: $e')),
      );
    }
  }

  /// Grup oluşturma işlemi
  Future<void> _createGroup() async {
    try {
      if (_groupDescriptionController.text.isEmpty ||
          _selectedFriends.isEmpty ||
          _amountController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tüm alanları doldurun!')),
        );
        return;
      }

      double totalAmount = double.parse(_amountController.text);

      // Servis katmanını çağırıyoruz
      await _groupService.createGroup(
        groupDescription: _groupDescriptionController.text,
        totalAmount: totalAmount,
        selectedFriendsUids: _selectedFriends,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grup ve borçlar başarıyla oluşturuldu!')),
      );

      // Formu temizle
      _groupDescriptionController.clear();
      _amountController.clear();
      setState(() => _selectedFriends = []);
    } catch (e) {
      print('Grup oluşturma sırasında hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  /// Grup kartını oluşturur
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
        leading: Icon(Icons.groups, color: Colors.blue),
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(
                groupId: groupDoc.id,
                groupName: groupData['groupName'] ?? 'Grup Detay',
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print("Kullanıcı UID'si: ${user.uid}");
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Grup Harcaması Ekranı'),
      ),
      body: Column(
        children: [
          // Üst kısımdaki form alanları
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

                // "Grup Oluştur" butonu
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
          // Alt kısımda grup listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _groupService.getUserGroups(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final groups = snapshot.data!.docs;
                if (groups.isEmpty) {
                  return Center(child: Text('Henüz oluşturulmuş grup yok.'));
                }
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

  /// Üyeleri seçmek için açılan pencere (Dialog)
  void _showMemberSelectionDialog() {
    // Dialog'ta geçici olarak seçimleri tutar
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
                  // Seçimleri kaydet
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
