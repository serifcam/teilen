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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade900
          : Colors.grey.shade100,
      appBar: AppBar(
        title: Text('${widget.groupName} Detayları'),
        backgroundColor: Colors.white,
        elevation: 2,
        foregroundColor: Colors.teal.shade800,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('groupDebts')
            .where('groupId', isEqualTo: widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
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
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            itemBuilder: (context, index) {
              final debt = sortedDebts[index];
              final data = debt.data() as Map<String, dynamic>;
              final userId = data['fromUser'];
              final isCurrentUser = userId == currentUser!.uid;
              final isPaid = data['status'] == 'paid';
              final isCreator = userId == _creatorId;
              final isApproved = data['isApproved'] == true;

              return FutureBuilder<String>(
                future: _getUserName(userId),
                builder: (context, snapshot) {
                  final name = snapshot.data ?? 'Yükleniyor...';
                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    color: Theme.of(context).cardColor,
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      leading: Icon(
                        Icons.person,
                        color: isCreator ? Colors.amber.shade700 : Colors.teal,
                        size: 28,
                      ),
                      title: Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isCreator
                                  ? Colors.orange.shade700
                                  : Colors.teal.shade700,
                            ),
                          ),
                          if (isCreator)
                            Padding(
                              padding: const EdgeInsets.only(left: 7),
                              child: Icon(Icons.star_rounded,
                                  color: Colors.orange, size: 18),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          children: [
                            Icon(Icons.money, size: 17, color: Colors.teal),
                            SizedBox(width: 4),
                            if (isCreator)
                              Text(
                                'Tüm borç ödendi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              )
                            else if (!isApproved)
                              Text(
                                'Bekleniyor',
                                style: TextStyle(
                                  color: Colors.orange.shade400,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              )
                            else
                              Text(
                                'Borç: ${((data['amount'] as num?) ?? 0).toDouble().toStringAsFixed(2)} ₺',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing:
                          (!isCreator && isApproved && isCurrentUser && !isPaid)
                              ? IconButton(
                                  icon: Icon(Icons.payment,
                                      color: Colors.teal.shade400, size: 28),
                                  tooltip: 'Borcu öde',
                                  onPressed: () => _confirmPayment(debt),
                                  splashRadius: 24,
                                )
                              : isPaid
                                  ? Icon(Icons.verified_rounded,
                                      color: Colors.teal, size: 22)
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
        backgroundColor: Colors.red.shade400,
        tooltip: 'Gruptan Ayrıl',
        child: Icon(Icons.exit_to_app_rounded),
        onPressed: _handleLeaveGroup,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Borç Ödeme Onayı'),
        content: Text('Bu borcu ödemeyi onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Hayır')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Evet'),
          ),
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

  Future<void> _payGroupDebt(DocumentSnapshot debtDoc) async {
    final data = debtDoc.data() as Map<String, dynamic>;
    final amount = (data['amount'] as num).toDouble();
    final lenderId = data['toUser'];
    final debtId = debtDoc.id;

    try {
      final balances = await ApiService.getBalances(currentUser!.uid);
      final balance = balances['balance'] ?? 0.0;

      if (balance >= amount) {
        await ApiService.payDebt(currentUser!.uid, lenderId, amount, debtId);

        await _firestore
            .collection('groupDebts')
            .doc(debtId)
            .update({'status': 'paid'});

        final userDoc =
            await _firestore.collection('users').doc(currentUser!.uid).get();
        final userName = userDoc.data()?['name'] ?? 'Bilinmeyen';
        final userEmail = userDoc.data()?['email'] ?? 'Bilinmeyen';

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
        .collection('groupDebts')
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Gruptan Ayrıl'),
        content:
            Text('Gruptan ayrılmak ve kartı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Hayır')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Evet'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final groupRef = _firestore.collection('groups').doc(widget.groupId);
    final groupDoc = await groupRef.get();
    final data = groupDoc.data();

    if (data == null) return;

    List<dynamic> memberIds = List.from(data['memberIds']);
    List<dynamic> approvedMemberIds =
        List.from(data['approvedMemberIds'] ?? []);

    memberIds.remove(userId);
    approvedMemberIds.remove(userId);

    if (memberIds.isEmpty) {
      await groupRef.delete();
    } else {
      await groupRef.update({
        'memberIds': memberIds,
        'approvedMemberIds': approvedMemberIds,
      });
    }

    // Kullanıcının groupDebts dökümanlarını da silelim!
    final debtDocs = await _firestore
        .collection('groupDebts')
        .where('groupId', isEqualTo: widget.groupId)
        .where('fromUser', isEqualTo: userId)
        .get();
    for (final doc in debtDocs.docs) {
      await doc.reference.delete();
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Gruptan ayrıldınız.')),
    );
  }
}
