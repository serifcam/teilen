import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/services/api_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String? userUid;

  const TransactionHistoryScreen({Key? key, this.userUid}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final String uid = widget.userUid ?? FirebaseAuth.instance.currentUser!.uid;
    try {
      final data = await ApiService.fetchTransactions(uid);
      setState(() {
        _transactions = data;
      });
    } catch (e) {
      // Hata varsa snackbar ile bildir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTransaction(int index) async {
    // Burada DB'den silmek istiyorsan ApiService'de bir fonksiyon eklemen gerek!
    setState(() {
      _transactions.removeAt(index);
    });
    // Hızlı silme, sadece localden (ekrandan) siler.
    // Eğer veritabanından da silmek istersen, bana bildir kanka!
  }

  @override
  Widget build(BuildContext context) {
    final Color neutralGrey = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade300
        : Colors.grey.shade800;

    return Scaffold(
      appBar: AppBar(
        title: Text('İşlem Geçmişi'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.teal.shade800,
      ),
      body: _transactions.isEmpty
          ? const Center(
              child: Text('Hiç işlem geçmişi yok!',
                  style: TextStyle(fontSize: 18)))
          : ListView.separated(
              itemCount: _transactions.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade300),
              itemBuilder: (context, i) {
                final t = _transactions[i];

                IconData icon;
                Color iconColor;
                String label;
                switch (t['type']) {
                  case 'deposit':
                    icon = Icons.add_circle_outline;
                    iconColor = Colors.green.shade400;
                    label = "Para Yükleme";
                    break;
                  case 'withdraw':
                    icon = Icons.remove_circle_outline;
                    iconColor = Colors.red.shade300;
                    label = "Para Çekme";
                    break;
                  case 'debt_pay':
                    icon = Icons.call_made;
                    iconColor = Colors.orange.shade400;
                    label = "Borç Ödeme";
                    break;
                  case 'debt_paid':
                    icon = Icons.call_received;
                    iconColor = Colors.blue.shade400;
                    label = "Borç Alındı";
                    break;
                  default:
                    icon = Icons.info_outline;
                    iconColor = neutralGrey;
                    label = "Bilinmeyen";
                }

                String formattedDate = t['created_at'].toString();
                if (formattedDate.length > 16) {
                  formattedDate =
                      formattedDate.substring(0, 16).replaceAll('T', ' ');
                }

                final String description = t['description'] ?? '';
                final RegExp reg = RegExp(r'^(.+?)\s\((.+?)\)');
                String mainInfo = '';
                String detail = description;
                if (reg.hasMatch(description)) {
                  final match = reg.firstMatch(description);
                  mainInfo = match?.group(1) ?? '';
                  detail = description.replaceFirst(reg, '').trim();
                }

                return Dismissible(
                  key: Key('${t['id'] ?? '$i-${t['created_at']}'}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    color: Colors.red.shade400,
                    padding: EdgeInsets.only(right: 32),
                    child: Icon(Icons.delete_forever,
                        color: Colors.white, size: 32),
                  ),
                  confirmDismiss: (direction) async {
                    bool confirm = false;
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text("Silmek istediğinize emin misiniz?"),
                        content: Text(
                            "İşlemi geçmişten kaldırmak istediğinizden emin misiniz?"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(false);
                            },
                            child: Text("Hayır"),
                          ),
                          TextButton(
                            onPressed: () {
                              confirm = true;
                              Navigator.of(context).pop(true);
                            },
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: Text("Evet"),
                          ),
                        ],
                      ),
                    );
                    return confirm;
                  },
                  onDismissed: (direction) {
                    _deleteTransaction(i);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("İşlem geçmişten kaldırıldı.")),
                    );
                  },
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    color: Theme.of(context).cardColor,
                    child: ListTile(
                      leading: Container(
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(8),
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                      title: Text(
                        mainInfo.isNotEmpty ? mainInfo : label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: neutralGrey,
                          letterSpacing: 0.1,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (detail.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 2.0, bottom: 2.0),
                              child: Text(
                                detail,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: neutralGrey.withOpacity(0.85),
                                ),
                              ),
                            ),
                          Text(
                            '${t['amount']} ₺   •   $label',
                            style: TextStyle(
                              fontSize: 13,
                              color: iconColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        formattedDate,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
