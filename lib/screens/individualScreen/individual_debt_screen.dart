import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/services/api_service.dart';
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

  final DebtService _debtService = DebtService();

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final friends = await _debtService.loadFriends();
    setState(() {
      _friendsList = friends;
    });
  }

  Future<void> _sendDebtNotification() async {
    if (_selectedFriendEmail == null ||
        _amountController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    try {
      await _debtService.sendDebtNotification(
        friendEmail: _selectedFriendEmail!,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        relation: _relation,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Borç bildirimi gönderildi, onay bekleniyor!')),
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

  Future<void> _confirmPayment(BuildContext context, String debtDocId,
      Map<String, dynamic> debtData) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Borç Ödeme'),
        content: Text('Borcunu ödemek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Evet', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) throw Exception('Kullanıcı bulunamadı.');

        final borrowerUid = currentUser.uid;
        final lenderUid = debtData['lenderId'];
        final debtAmount = (debtData['amount'] as num).toDouble();

        final balanceStr = await ApiService.getBalance(borrowerUid);
        final balance = double.tryParse(balanceStr) ?? 0.0;

        if (balance >= debtAmount) {
          await ApiService.payDebt(
              borrowerUid, lenderUid, debtAmount, debtDocId);

          // ✅ 1. Kendi borç kaydını 'paid' yap
          await FirebaseFirestore.instance
              .collection('individualDebts')
              .doc(debtDocId)
              .update({'status': 'paid'});

          // ✅ 2. Karşı tarafın kartını da 'paid' yap
          final query = await FirebaseFirestore.instance
              .collection('individualDebts')
              .where('borrowerId', isEqualTo: lenderUid)
              .where('lenderId', isEqualTo: borrowerUid)
              .where('amount', isEqualTo: debtAmount)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final otherDebtDocId = query.docs.first.id;
            await FirebaseFirestore.instance
                .collection('individualDebts')
                .doc(otherDebtDocId)
                .update({'status': 'paid'});
          }

          // ✅ Bilgi bildirimi gönder
          await FirebaseFirestore.instance.collection('notifications').add({
            'type': 'paymentInfo',
            'status': 'info',
            'fromUser': borrowerUid,
            'fromUserEmail': currentUser.email ?? '',
            'toUser': lenderUid,
            'toUserEmail': debtData['friendEmail'],
            'amount': debtAmount,
            'description':
                '🪙 ${currentUser.email ?? 'Bir kullanıcı'}, size olan $debtAmount TL borcunu ödemiştir.',
            'createdAt': Timestamp.now(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '✅ Borç ödendi ve her iki tarafın kaydı güncellendi!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Yetersiz bakiye!')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Widget _buildDebtCard(Map<String, dynamic> data, String docId) {
    final createdAt = data['createdAt'] as Timestamp?;
    String formattedDate = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} '
            '${createdAt.toDate().hour}:${createdAt.toDate().minute}'
        : 'Tarih Bilinmiyor';

    bool isMeToFriend = data['relation'] == 'me_to_friend';
    final currentUser = FirebaseAuth.instance.currentUser;

    bool isBorrower = data['borrowerId'] == currentUser?.uid;
    bool isPaid = data['status'] == 'paid';

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (isPaid) {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Onay'),
              content:
                  Text('Borcunuzu ödediniz. Bu kartı silmek ister misiniz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Hayır'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Evet'),
                ),
              ],
            ),
          );
          return result ?? false;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Bu borç henüz ödenmediği için silemezsiniz.')),
          );
          return false;
        }
      },
      onDismissed: (direction) async {
        await FirebaseFirestore.instance
            .collection('individualDebts')
            .doc(docId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Borç kartı silindi!')),
        );
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 60,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300, width: 1),
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
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isMeToFriend ? Colors.red : Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${data['friendName'] ?? data['friendEmail']}'),
                    Text('Açıklama: ${data['description']}'),
                    Text('Borç: ${data['amount']} TL'),
                    Text(
                      'Tarih: $formattedDate',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            if (isMeToFriend && isBorrower && !isPaid)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: Icon(Icons.payment, color: Colors.green, size: 28),
                  tooltip: 'Borcu öde',
                  onPressed: () => _confirmPayment(context, docId, data),
                ),
              ),
          ],
        ),
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
                  onPressed: _sendDebtNotification,
                  child: Text('Oluştur'),
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
                stream: _debtService.getDebtsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                        child: Text('Henüz eklenmiş borç bulunmamaktadır.'));
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
