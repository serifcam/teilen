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
  String _relation = 'me_to_friend'; // Default borç ilişkisi

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

      final debtData = {
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text,
        'createdAt': Timestamp.now(),
      };

      // Kullanıcı ve arkadaş için borç ekleme
      await _firestore.collection('individualDebts').add({
        ...debtData,
        'borrowerId': user!.uid,
        'friendEmail': _selectedFriendEmail,
        'relation': _relation,
      });

      await _firestore.collection('individualDebts').add({
        ...debtData,
        'borrowerId': friendId,
        'friendEmail': user.email,
        'relation':
            _relation == 'me_to_friend' ? 'friend_to_me' : 'me_to_friend',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Borç başarıyla eklendi!')),
      );

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
    final createdAt =
        data['createdAt'] as Timestamp?; // Tarih bilgisini çekiyoruz.
    String formattedDate = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} ${createdAt.toDate().hour}:${createdAt.toDate().minute}'
        : 'Tarih Bilinmiyor'; // Tarih formatlama.

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Icon(
          data['relation'] == 'me_to_friend'
              ? Icons.arrow_upward
              : Icons.arrow_downward,
          color: data['relation'] == 'me_to_friend' ? Colors.red : Colors.green,
        ),
        title: Text(data['friendEmail']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data['description']}'),
            Text('Borç: ${data['amount']} TL'),
            Text(
              'Oluşturulma Tarihi: $formattedDate',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
        trailing: Text(
          data['relation'] == 'me_to_friend' ? 'Borçluyum' : 'Bana Borçlu',
          style: TextStyle(
            color:
                data['relation'] == 'me_to_friend' ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Borç Ekleme Alanı
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
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
                      borderRadius:
                          BorderRadius.circular(12), // Aynı kenar yuvarlaklığı
                    ),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Borç Miktarı',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12), // Aynı kenar yuvarlaklığı
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
                      borderRadius:
                          BorderRadius.circular(12), // Aynı kenar yuvarlaklığı
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Borçluyum'),
                        value: 'me_to_friend',
                        groupValue: _relation,
                        onChanged: (value) =>
                            setState(() => _relation = value!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Borçlu'),
                        value: 'friend_to_me',
                        groupValue: _relation,
                        onChanged: (value) =>
                            setState(() => _relation = value!),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment
                      .start, // Row içindeki butonu sola hizalar
                  children: [
                    ElevatedButton(
                      onPressed: _addDebt,
                      child: Text('Borç Ekle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(),
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
    );
  }
}
