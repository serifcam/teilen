import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/services/debt_service.dart';

class IndividualDebtScreen extends StatefulWidget {
  @override
  _IndividualDebtScreenState createState() => _IndividualDebtScreenState();
}

class _IndividualDebtScreenState extends State<IndividualDebtScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _friendsList = [];
  String? _selectedFriendEmail;
  String _relation = 'me_to_friend';

  // Servis katmanından bir instance oluşturuyoruz
  final DebtService _debtService = DebtService();

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  /// Servis katmanından arkadaş listesini çekiyoruz
  Future<void> _loadFriends() async {
    final friends = await _debtService.loadFriends();
    setState(() {
      _friendsList = friends;
    });
  }

  /// "Ekle" butonuna tıklandığında çalışır
  Future<void> _addDebt() async {
    if (_selectedFriendEmail == null ||
        _amountController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    try {
      await _debtService.addDebt(
        friendEmail: _selectedFriendEmail!,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        relation: _relation,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim gönderildi, onay bekleniyor!')),
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

  /// Borcu ödediğini onaylama işlemi
  Future<void> _confirmDebtPaid(
    BuildContext context,
    String debtDocId,
    Map<String, dynamic> debtData,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Onay'),
        content: Text('Borcu ödediğinizi onaylıyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Evet'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _debtService.confirmDebtPaid(
          debtDocId: debtDocId,
          debtData: debtData,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Borcu ödediğinize dair bildirim gönderildi.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  /// Ekranda borç kartlarını oluşturur
  Widget _buildDebtCard(Map<String, dynamic> data, String docId) {
    final createdAt = data['createdAt'] as Timestamp?;
    String formattedDate = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} '
            '${createdAt.toDate().hour}:${createdAt.toDate().minute}'
        : 'Tarih Bilinmiyor';

    bool isMeToFriend = data['relation'] == 'me_to_friend';
    final currentUser = FirebaseAuth.instance.currentUser;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          // Sol taraftaki ikon
          Container(
            width: 80,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isMeToFriend ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isMeToFriend ? Colors.red : Colors.green,
                ),
                SizedBox(height: 4),
                Text(
                  isMeToFriend ? 'Borçluyum' : 'Borçlu',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isMeToFriend ? Colors.red : Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Orta kısımdaki borç bilgileri
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kişi: ${data['friendEmail']}'),
                  Text('Açıklama: ${data['description']}'),
                  Text('Borç: ${data['amount']} TL'),
                  Text(
                    'Tarih: $formattedDate',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          // Sağ taraftaki "Borcu Ödedim" ikonu (Sadece borçlu olan kişi görür)
          if (isMeToFriend && data['borrowerId'] == currentUser?.uid)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.black),
                onPressed: () => _confirmDebtPaid(context, docId, data),
                tooltip: 'Borcu ödediğinizi bildir',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bireysel Borç Ekranı'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Arkadaş seçimi
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
            // Borç miktarı
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
            // Açıklama
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
            // Radyo butonları ve "Ekle" butonu
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
            // Borçların listesi
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _debtService.getDebtsStream(),
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
                      final doc = debts[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildDebtCard(data, doc.id);
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
