import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  GroupDetailScreen({required this.groupId, required this.groupName});

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedUserId;
  String? _groupCreatorId;

  @override
  void initState() {
    super.initState();
    _fetchGroupCreator();
  }

  Future<void> _fetchGroupCreator() async {
    final groupDoc =
        await _firestore.collection('groups').doc(widget.groupId).get();
    if (groupDoc.exists) {
      setState(() {
        _groupCreatorId = groupDoc['createdBy'];
      });
    }
  }

  Future<void> _toggleDebtStatus() async {
    if (_selectedUserId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('debts')
          .where('groupId', isEqualTo: widget.groupId)
          .where('fromUser', isEqualTo: _selectedUserId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final currentStatus = doc['status'];
        final newStatus = currentStatus == 'paid' ? 'pending' : 'paid';

        await _firestore.collection('debts').doc(doc.id).update({
          'status': newStatus,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Borç durumu güncellendi!')),
        );

        setState(() {
          _selectedUserId = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seçilen kullanıcı için borç bulunamadı.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<String> _getUserEmail(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      return userDoc.data()?['email'] ?? 'Bilinmeyen Kullanıcı';
    } else {
      return 'Bilinmeyen Kullanıcı';
    }
  }

  Future<void> _deleteGroup() async {
    try {
      await _firestore.collection('groups').doc(widget.groupId).delete();
      final debtsSnapshot = await _firestore
          .collection('debts')
          .where('groupId', isEqualTo: widget.groupId)
          .get();

      for (var debtDoc in debtsSnapshot.docs) {
        await _firestore.collection('debts').doc(debtDoc.id).delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grup başarıyla silindi!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName} Detayları'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('debts')
            .where('groupId', isEqualTo: widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final debts = snapshot.data!.docs;

          double totalAmount = debts.fold(
            0.0,
            (previousValue, debt) =>
                previousValue + (debt['amount'] as num).toDouble(),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Toplam Harcanan: ${totalAmount.toStringAsFixed(2)} TL',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: debts.length,
                  itemBuilder: (context, index) {
                    final debt = debts[index].data() as Map<String, dynamic>;
                    final isCreator = debt['fromUser'] == _groupCreatorId;
                    final isSelected = _selectedUserId == debt['fromUser'];

                    return FutureBuilder<String>(
                      future: _getUserEmail(debt['fromUser']),
                      builder: (context, emailSnapshot) {
                        if (!emailSnapshot.hasData) {
                          return ListTile(
                            title: Text('Yükleniyor...'),
                            subtitle: Text('Borç: ${debt['amount']} TL'),
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
                              : Text('Borç: ${debt['amount']} TL'),
                          trailing: isCreator
                              ? Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                )
                              : Text(
                                  debt['status'] == 'pending'
                                      ? 'Borçlu'
                                      : 'Ödendi',
                                  style: TextStyle(
                                    color: debt['status'] == 'pending'
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
                                    _selectedUserId = debt['fromUser'];
                                  });
                                },
                        );
                      },
                    );
                  },
                ),
              ),
              // Bu butonlar yalnızca grup kurucusuna görünecek
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
