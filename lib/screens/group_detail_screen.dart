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

  String? _selectedUserId; // Seçilen kullanıcının ID'si
  String? _groupCreatorId; // Grubu oluşturan kişinin ID'si
  String? _currentUserId; // Mevcut kullanıcının ID'si

  @override
  void initState() {
    super.initState();
    _fetchGroupCreator();
    _currentUserId = _auth.currentUser?.uid;
  }

  // Grubun kurucusunu çekme
  Future<void> _fetchGroupCreator() async {
    final groupDoc =
        await _firestore.collection('groups').doc(widget.groupId).get();
    if (groupDoc.exists) {
      setState(() {
        _groupCreatorId = groupDoc['createdBy'];
      });
    }
  }

  // UID'ye karşılık gelen e-posta adresini çekmek için fonksiyon
  Future<String> _getUserEmail(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      return userDoc.data()?['email'] ?? 'Bilinmeyen Kullanıcı';
    } else {
      return 'Bilinmeyen Kullanıcı';
    }
  }

  // Borç durumunu güncelleme fonksiyonu
  Future<void> _toggleDebtStatus() async {
    if (_selectedUserId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('debts')
          .where('groupId', isEqualTo: widget.groupId)
          .where('fromUser', isEqualTo: _selectedUserId)
          .get();

      for (var doc in querySnapshot.docs) {
        final currentStatus = doc['status'];
        final newStatus = currentStatus == 'paid' ? 'pending' : 'paid';

        await _firestore.collection('debts').doc(doc.id).update({
          'status': newStatus,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Borç durumu güncellendi!')),
      );

      setState(() {
        _selectedUserId = null; // Seçimi sıfırla
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName} '),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('debts')
            .where('groupId', isEqualTo: widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

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
                    bool isCreator = debt['fromUser'] == debt['toUser'];
                    bool isSelected = _selectedUserId == debt['fromUser'];

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
                            ),
                          ),
                          subtitle: isCreator
                              ? Text(
                                  'Tüm harcamayı ödedi',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                )
                              : Text('Borç: ${debt['amount']} TL'),
                          trailing: Text(
                            isCreator
                                ? 'Kurucu'
                                : debt['status'] == 'pending'
                                    ? 'Borçlu'
                                    : 'Ödendi',
                            style: TextStyle(
                              color: isCreator
                                  ? Colors.amber
                                  : debt['status'] == 'pending'
                                      ? Colors.red
                                      : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          tileColor: isSelected
                              ? Colors.teal.withOpacity(0.2)
                              : null, // Seçilen kullanıcıyı vurgula
                          onTap: () {
                            if (_groupCreatorId == _currentUserId) {
                              setState(() {
                                _selectedUserId = debt[
                                    'fromUser']; // Kullanıcı seçimini kaydet
                              });
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _groupCreatorId == _currentUserId
          ? FloatingActionButton.extended(
              onPressed: _selectedUserId != null ? _toggleDebtStatus : null,
              label: Text('Ödedi'),
              icon: Icon(Icons.check),
              backgroundColor:
                  _selectedUserId != null ? Colors.green : Colors.grey,
            )
          : null, // Buton sadece grup kurucusuna gösterilecek
    );
  }
}
