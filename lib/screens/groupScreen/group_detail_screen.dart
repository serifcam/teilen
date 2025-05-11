import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/services/api_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  GroupDetailScreen({required this.groupId, required this.groupName});

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, String> _userNamesCache = {};
  String? _creatorId;

  @override
  void initState() {
    super.initState();
    _getCreatorId();
  }

  Future<void> _getCreatorId() async {
    final groupDoc =
        await _firestore.collection('groups').doc(widget.groupId).get();
    setState(() {
      _creatorId = groupDoc.data()?['creatorId'];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        body: Center(child: Text('Kullanıcı oturum açmamış.')),
      );
    }

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
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final debts = snapshot.data!.docs;
          if (debts.isEmpty)
            return Center(child: Text('Bu grupta borç bulunmuyor.'));

          final sortedDebts = [...debts];
          if (_creatorId != null) {
            sortedDebts.sort((a, b) {
              final aId = (a.data() as Map)['fromUser'];
              final bId = (b.data() as Map)['fromUser'];
              return aId == _creatorId
                  ? -1
                  : bId == _creatorId
                      ? 1
                      : 0;
            });
          }

          return ListView.builder(
            itemCount: sortedDebts.length,
            itemBuilder: (context, index) {
              final debt = sortedDebts[index];
              final data = debt.data() as Map<String, dynamic>;
              final userId = data['fromUser'];
              final isCurrentUser = userId == currentUser!.uid;
              final isPaid = data['status'] == 'paid';
              final isCreator = userId == _creatorId;

              return FutureBuilder<String>(
                future: _getUserName(userId),
                builder: (context, snapshot) {
                  final name = snapshot.data ?? 'Yükleniyor...';
                  return Card(
                    margin: EdgeInsets.all(8),
                    child: ListTile(
                      leading: Icon(
                        Icons.person,
                        color: isCreator ? Colors.amber : Colors.teal,
                      ),
                      title: Text(name),
                      subtitle: Text(
                        isCreator
                            ? 'Tüm borç ödendi'
                            : 'Borç: ${((data['amount'] as num?) ?? 0).toDouble().toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isCurrentUser && !isPaid
                          ? IconButton(
                              icon: Icon(Icons.payment, color: Colors.green),
                              onPressed: () => _confirmPayment(debt),
                            )
                          : isPaid
                              ? Icon(Icons.done, color: Colors.green)
                              : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 207, 42, 30),
        tooltip: 'Gruptan Ayrıl',
        child: Icon(Icons.exit_to_app),
        onPressed: _handleLeaveGroup,
      ),
    );
  }

  Future<String> _getUserName(String uid) async {
    if (_userNamesCache.containsKey(uid)) {
      return _userNamesCache[uid]!;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final name = doc.data()?['name'] ?? 'Bilinmeyen Kullanıcı';
      _userNamesCache[uid] = name;
      return name;
    } catch (_) {
      return 'Bilinmeyen Kullanıcı';
    }
  }

  Future<void> _confirmPayment(DocumentSnapshot debtDoc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Borç Ödeme Onayı'),
        content: Text('Bu borcu ödemeyi onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Hayır')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Evet')),
        ],
      ),
    );

    if (result == true) {
      await _payGroupDebt(debtDoc);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem iptal edildi.')),
      );
    }
  }

  // _payGroupDebt fonksiyonunu güncelledik:

  Future<void> _payGroupDebt(DocumentSnapshot debtDoc) async {
    final data = debtDoc.data() as Map<String, dynamic>;
    final amount = (data['amount'] as num).toDouble();
    final lenderId = data['toUser'];
    final debtId = debtDoc.id;

    try {
      final balanceStr = await ApiService.getBalance(currentUser!.uid);
      final balance = double.tryParse(balanceStr) ?? 0;

      if (balance >= amount) {
        await ApiService.payDebt(currentUser!.uid, lenderId, amount, debtId);

        // Borç durumunu güncelle
        await _firestore
            .collection('debts')
            .doc(debtId)
            .update({'status': 'paid'});

        // 🔥 Kullanıcı bilgilerini al
        final userDoc =
            await _firestore.collection('users').doc(currentUser!.uid).get();
        final userName = userDoc.data()?['name'] ?? 'Bilinmeyen';
        final userEmail = userDoc.data()?['email'] ?? 'Bilinmeyen';

        // 🔔 Bildirimi oluştur
        await _firestore.collection('notifications').add({
          'type': 'debtPayment',
          'fromUserId': currentUser!.uid,
          'fromUserName': userName,
          'fromUserEmail': userEmail,
          'toUserId': lenderId,
          'toUser': lenderId,
          'groupId': widget.groupId,
          'groupName': widget.groupName,
          'amount': amount,
          'status': 'info',
          'createdAt': Timestamp.now(),
          'message':
              '$userName ($userEmail), ${widget.groupName} grubundaki ${amount.toStringAsFixed(2)} ₺ borcunu ödedi.',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('✅ Borç başarıyla ödendi ve bildirim gönderildi!')),
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

  Future<void> _handleLeaveGroup() async {
    final userId = currentUser!.uid;

    final unpaidDebts = await _firestore
        .collection('debts')
        .where('groupId', isEqualTo: widget.groupId)
        .where('fromUser', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (unpaidDebts.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('❌ Gruptan ayrılmadan önce borcunuzu ödeyiniz.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Gruptan Ayrıl'),
        content:
            Text('Gruptan ayrılmak ve kartı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Hayır')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Evet')),
        ],
      ),
    );

    if (confirm != true) return;

    final groupRef = _firestore.collection('groups').doc(widget.groupId);
    final groupDoc = await groupRef.get();
    final data = groupDoc.data();

    if (data == null) return;

    List<dynamic> memberIds = data['memberIds'];
    memberIds.remove(userId);

    if (memberIds.isEmpty) {
      await groupRef.delete();
    } else {
      await groupRef.update({'memberIds': memberIds});
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Gruptan ayrıldınız.')),
    );
  }
}
