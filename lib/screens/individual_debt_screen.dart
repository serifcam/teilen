import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IndividualDebtScreen extends StatefulWidget {
  @override
  _IndividualDebtScreenState createState() => _IndividualDebtScreenState();
}

class _IndividualDebtScreenState extends State<IndividualDebtScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _friendsList = [];
  String? _selectedFriendEmail;
  String _relation = 'me_to_friend';

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

  Future<void> _addDebt() async {
    final user = _auth.currentUser;

    if (_selectedFriendEmail == null ||
        _amountController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }

    try {
      // Arkadaşın bilgilerini Firestore'dan getir
      final friendDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: _selectedFriendEmail)
          .get();

      if (friendDoc.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arkadaş bulunamadı')),
        );
        return;
      }

      final friendId = friendDoc.docs.first.id;
      final friendEmail =
          friendDoc.docs.first.data()['email'] ?? "Bilinmeyen Kullanıcı";

      // İlişkilerin doğru atanması
      String relationValue =
          _relation == 'me_to_friend' ? 'me_to_friend' : 'friend_to_me';

      // Bildirimi gönderirken e-posta adreslerini ekle
      final notificationData = {
        'fromUser': user!.uid,
        'fromUserEmail': user.email ?? "Bilinmeyen Kullanıcı",
        'toUser': friendId,
        'toUserEmail': friendEmail,
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text,
        'relation': relationValue,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      };

      // Bildirimi Firestore'a ekle
      await _firestore.collection('notifications').add(notificationData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim gönderildi, onay bekleniyor!')),
      );

      // Giriş alanlarını temizle
      _amountController.clear();
      _descriptionController.clear();
      setState(() => _selectedFriendEmail = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Widget _buildDebtCard(Map<String, dynamic> data) {
    final createdAt = data['createdAt'] as Timestamp?;
    String formattedDate = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} ${createdAt.toDate().hour}:${createdAt.toDate().minute}'
        : 'Tarih Bilinmiyor';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(data['friendEmail']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Açıklama: ${data['description']}'),
            Text('Borç: ${data['amount']} TL'),
            Text(
              'Tarih: $formattedDate',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
        leading: Icon(
          data['relation'] == 'me_to_friend'
              ? Icons.arrow_upward
              : Icons.arrow_downward,
          color: data['relation'] == 'me_to_friend' ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedFriendEmail,
              items: _friendsList.map<DropdownMenuItem<String>>((friend) {
                return DropdownMenuItem<String>(
                  value: friend['email'],
                  child: Text(friend['email']),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedFriendEmail = value),
              decoration: InputDecoration(
                labelText: 'Arkadaş Seç',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Borç Miktarı',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addDebt,
                  child: Text('Ekle'),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          dense: true,
                          title:
                              Text('Ben Ona', style: TextStyle(fontSize: 13)),
                          value: 'me_to_friend',
                          groupValue: _relation,
                          onChanged: (value) =>
                              setState(() => _relation = value!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          dense: true,
                          title: Text('O Bana', style: TextStyle(fontSize: 13)),
                          value: 'friend_to_me',
                          groupValue: _relation,
                          onChanged: (value) =>
                              setState(() => _relation = value!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('individualDebts')
                    .where('borrowerId', isEqualTo: _auth.currentUser!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text('Henüz eklenmiş borç bulunmamaktadır.'),
                    );
                  }

                  final debts = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: debts.length,
                    itemBuilder: (context, index) {
                      final data = debts[index].data() as Map<String, dynamic>;
                      return _buildDebtCard(data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
