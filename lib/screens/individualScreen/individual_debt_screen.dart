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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Borç Ödeme', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Borcunu ödemek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hayır'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Evet'),
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

        final balances = await ApiService.getBalances(borrowerUid);
        final balance = balances['balance'] ?? 0.0;

        if (balance >= debtAmount) {
          await ApiService.payDebt(
              borrowerUid, lenderUid, debtAmount, debtDocId);

          await FirebaseFirestore.instance
              .collection('individualDebts')
              .doc(debtDocId)
              .update({'status': 'paid'});

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
    String formattedDate = 'Tarih Bilinmiyor';
    if (createdAt != null) {
      final localDate = createdAt
          .toDate()
          .add(Duration(hours: 3)); // <-- Saat düzeltme burada
      formattedDate =
          '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year} ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
    }

    bool isMeToFriend = data['relation'] == 'me_to_friend';
    final currentUser = FirebaseAuth.instance.currentUser;

    bool isBorrower = data['borrowerId'] == currentUser?.uid;
    bool isPaid = data['status'] == 'paid';

    final Color accentColor = isMeToFriend ? Colors.redAccent : Colors.teal;
    final IconData directionIcon =
        isMeToFriend ? Icons.arrow_outward_rounded : Icons.arrow_upward_rounded;

    return Dismissible(
      key: Key(docId),
      direction: isPaid ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (isPaid) {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('Silmek istediğine emin misin?'),
              content:
                  Text('Borcun ödendi. Bu kartı geçmişten silmek ister misin?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Vazgeç'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Sil'),
                ),
              ],
            ),
          );
          return result ?? false;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Bu borç henüz ödenmediği için silemezsin!')),
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
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.red.shade300, Colors.red.shade700],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: Icon(Icons.delete, color: Colors.white, size: 32),
        ),
      ),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Theme.of(context).cardColor,
        child: ListTile(
          leading: Container(
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: EdgeInsets.all(8),
            child: Icon(
              directionIcon,
              color: accentColor,
              size: 32,
            ),
          ),
          title: Text(
            '${data['friendName'] ?? data['friendEmail']}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: accentColor,
              letterSpacing: 0.2,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Borç: ${data['amount']} ₺',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: 2),
                Text('Açıklama: ${data['description']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    )),
                Text(
                  'Tarih: $formattedDate',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (isPaid)
                  Row(
                    children: [
                      Icon(Icons.verified, color: Colors.teal, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Ödendi',
                        style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          trailing: isMeToFriend && isBorrower && !isPaid
              ? IconButton(
                  icon: Icon(Icons.payment,
                      color: Colors.teal.shade400, size: 28),
                  tooltip: 'Borcu öde',
                  onPressed: () => _confirmPayment(context, docId, data),
                  splashRadius: 24,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade900
          : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Bireysel Borçlar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
            letterSpacing: 0.2,
            fontFamily: 'Nunito',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal.shade800,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(18),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              margin: EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedFriendEmail,
                      items:
                          _friendsList.map<DropdownMenuItem<String>>((friend) {
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
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Borç Miktarı',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
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
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.add, color: Colors.white, size: 26),
                          tooltip: 'Borç Oluştur',
                          onPressed: _sendDebtNotification,
                          splashRadius: 26,
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.teal.shade700),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            overlayColor: MaterialStateProperty.all(Colors
                                .teal.shade900
                                .withOpacity(0.12)), // basınca hafif efekt
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  dense: true,
                                  title: Text('Ben Ona',
                                      style: TextStyle(fontSize: 13)),
                                  value: 'me_to_friend',
                                  groupValue: _relation,
                                  activeColor: Colors.teal.shade400,
                                  onChanged: (value) =>
                                      setState(() => _relation = value!),
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  dense: true,
                                  title: Text('O Bana',
                                      style: TextStyle(fontSize: 13)),
                                  value: 'friend_to_me',
                                  groupValue: _relation,
                                  activeColor: Colors.redAccent,
                                  onChanged: (value) =>
                                      setState(() => _relation = value!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
