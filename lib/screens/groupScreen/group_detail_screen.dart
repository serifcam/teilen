import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/services/group_detail_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  GroupDetailScreen({required this.groupId, required this.groupName});

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  // Servis katmanını kullanabilmek için oluşturuyoruz
  final GroupDetailService _service = GroupDetailService();

  String? _selectedUserId;
  String? _groupCreatorId;

  @override
  void initState() {
    super.initState();
    _fetchGroupCreator();
  }

  /// Grup kurucusunun UID'sini alıyoruz
  Future<void> _fetchGroupCreator() async {
    final creatorId = await _service.fetchGroupCreator(widget.groupId);
    setState(() {
      _groupCreatorId = creatorId;
    });
  }

  /// Borç durumunu değiştirir (paid <-> pending)
  Future<void> _toggleDebtStatus() async {
    if (_selectedUserId == null) return;

    try {
      await _service.toggleDebtStatus(widget.groupId, _selectedUserId!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Borç durumu güncellendi!')),
      );

      setState(() {
        _selectedUserId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  /// Kullanıcının e-postasını almak için servis katmanını çağırıyoruz
  Future<String> _getUserEmail(String uid) async {
    return await _service.getUserEmail(uid);
  }

  /// Grubu silmek için onay diyaloğu açar, onaylanırsa servise yönlendirir
  Future<void> _showDeleteConfirmationDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Onay'),
        content: Text(
            'Herkes borcunu ödemiştir, grubu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Evet'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteGroup();
    }
  }

  /// Grubu servisten siliyor
  Future<void> _deleteGroup() async {
    try {
      await _service.deleteGroup(widget.groupId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grup başarıyla silindi!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName} Detayları'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('debts')
            .where('groupId', isEqualTo: widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final debts = snapshot.data!.docs;

          // Toplam harcanan ücreti hesaplıyoruz
          double totalAmount = debts.fold(
            0.0,
            (previousValue, debt) =>
                previousValue + (debt['amount'] as num).toDouble(),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toplam harcanan tutar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Toplam Harcanan: ${totalAmount.toStringAsFixed(2)} TL',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Divider(),
              // Borçların listesi
              Expanded(
                child: ListView.builder(
                  itemCount: debts.length,
                  itemBuilder: (context, index) {
                    final docData = debts[index].data() as Map<String, dynamic>;
                    final isCreator = docData['fromUser'] == _groupCreatorId;
                    final isSelected = _selectedUserId == docData['fromUser'];

                    return FutureBuilder<String>(
                      future: _getUserEmail(docData['fromUser']),
                      builder: (context, emailSnapshot) {
                        if (!emailSnapshot.hasData) {
                          return ListTile(
                            title: Text('Yükleniyor...'),
                            subtitle: Text('Borç: ${docData['amount']} TL'),
                          );
                        }

                        return ListTile(
                          leading: Icon(
                            isCreator ? Icons.star : Icons.person,
                            color: isCreator ? Colors.amber : null,
                          ),
                          title: Text(
                            emailSnapshot.data!,
                            style: TextStyle(
                              fontWeight: isCreator
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCreator ? Colors.amber : null,
                            ),
                          ),
                          subtitle: isCreator
                              ? Text(
                                  'Tüm hesabı ödemiştir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                )
                              : Text('Borç: ${docData['amount']} TL'),
                          trailing: isCreator
                              ? Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                )
                              : Text(
                                  docData['status'] == 'pending'
                                      ? 'Borçlu'
                                      : 'Ödendi',
                                  style: TextStyle(
                                    color: docData['status'] == 'pending'
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          tileColor:
                              isSelected ? Colors.teal.withOpacity(0.2) : null,
                          onTap: isCreator
                              ? null
                              : () {
                                  setState(() {
                                    _selectedUserId = docData['fromUser'];
                                  });
                                },
                        );
                      },
                    );
                  },
                ),
              ),
              // Grup kurucusuna özel butonlar
              if (currentUserId == _groupCreatorId)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showDeleteConfirmationDialog,
                        icon: Icon(Icons.delete, color: Colors.red),
                        label: Text(
                          'Grubu Sil',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 20.0),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _selectedUserId != null ? _toggleDebtStatus : null,
                        icon: Icon(Icons.check, color: Colors.green),
                        label: Text(
                          'Ödendi',
                          style: TextStyle(color: Colors.green),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.green),
                          padding: EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 20.0),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
