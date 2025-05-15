import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/services/api_service.dart';
import 'package:teilen2/services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService _userService = UserService();
  String? _profileImageUrl;
  String? _name;
  String? _email;
  bool _isLoading = false;
  String balance = '...';
  String mainBalance = '...';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadBalances();
  }

  Future<void> _fetchUserData() async {
    final userData = await _userService.fetchUserData();
    if (userData != null) {
      setState(() {
        _profileImageUrl = userData['profileImageUrl'];
        _name = userData['name'];
        _email = userData['email'];
      });
    }
  }

  Future<void> _loadBalances() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final result = await ApiService.getBalances(uid);
      setState(() {
        balance = '${result['balance']} ₺';
        mainBalance = '${result['main_balance']} ₺';
      });
    } catch (e) {
      setState(() {
        balance = 'Hata!';
        mainBalance = 'Hata!';
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final url = await _userService.uploadProfileImage(File(pickedFile.path));
      if (url != null) {
        setState(() => _profileImageUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil resmi başarıyla değiştirildi!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim değiştirilemedi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProfileImage() async {
    setState(() => _isLoading = true);
    try {
      await _userService.deleteProfileImageOnStorage(forceDelete: true);
      setState(() => _profileImageUrl = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil resmi başarıyla silindi!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim silinemedi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo, color: Colors.teal),
              title: Text('Değiştir'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndUploadImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Sil'),
              onTap: () {
                Navigator.of(context).pop();
                _deleteProfileImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await _userService.signOutUser();
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth',
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış yapılamadı: $e')),
      );
    }
  }

  Future<void> _showDepositDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Para Yükle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Yüklenecek miktar (₺)'),
        ),
        actions: [
          TextButton(
            child: Text('İptal'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Yükle'),
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Geçerli bir miktar girin!')));
                return;
              }
              try {
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await ApiService.depositMoney(uid, amount);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Para başarıyla yüklendi!')));
                await _loadBalances();
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('❌ Hata: $e')));
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showWithdrawDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Para Çek'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Çekilecek miktar (₺)'),
        ),
        actions: [
          TextButton(
            child: Text('İptal'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Çek'),
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Geçerli bir miktar girin!')));
                return;
              }
              try {
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await ApiService.withdrawMoney(uid, amount);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Para başarıyla çekildi!')));
                await _loadBalances();
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('❌ Hata: $e')));
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _openTransactionHistory() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    Navigator.pushNamed(context, '/transaction-history', arguments: uid);
  }

  @override
  Widget build(BuildContext context) {
    final mainTeal = Colors.teal.shade700;
    final surfaceColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(
          'Hesap Ayarları',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
            letterSpacing: 0.2,
            fontFamily: 'Nunito',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        foregroundColor: mainTeal,
      ),
      body: ListView(
        padding: EdgeInsets.all(18),
        children: [
          // PROFILE CARD
          Container(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 18,
                  offset: Offset(0, 5),
                )
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showImageOptions,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundImage: (!_isLoading && _profileImageUrl != null)
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    backgroundColor: Colors.teal.shade50,
                    child: _isLoading
                        ? Center(
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: LoadingIndicator(
                                indicatorType: Indicator.circleStrokeSpin,
                                colors: [Colors.teal],
                              ),
                            ),
                          )
                        : _profileImageUrl == null
                            ? Icon(Icons.camera_alt_rounded,
                                size: 30, color: mainTeal)
                            : null,
                  ),
                ),
                SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_name != null)
                        Text(
                          _name!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: mainTeal,
                            letterSpacing: 0.2,
                          ),
                        ),
                      if (_email != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _email!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showImageOptions,
                  icon: Icon(Icons.edit, color: Colors.grey.shade400, size: 22),
                  tooltip: "Profil Fotoğrafı Düzenle",
                )
              ],
            ),
          ),
          SizedBox(height: 22),

          // BALANCES CARD
          Container(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: mainTeal, size: 33),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uygulama Bakiyesi',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        balance,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.teal.shade800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ana Bakiye',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        mainBalance,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_downward,
                          color: Colors.green, size: 26),
                      tooltip: 'Para Yükle',
                      onPressed: _showDepositDialog,
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.arrow_upward, color: Colors.red, size: 26),
                      tooltip: 'Para Çek',
                      onPressed: _showWithdrawDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 18),

          // ACTIONS
          ListTile(
            leading: Icon(Icons.history, color: mainTeal),
            title: Text(
              'İşlem Geçmişi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onTap: _openTransactionHistory,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            tileColor: Colors.white,
          ),
          SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.notifications_active_rounded, color: mainTeal),
            title: Text(
              'Bildirim Ayarları',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onTap: () {
              Navigator.of(context).pushNamed('/notification-settings');
            },
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            tileColor: Colors.white,
          ),
          SizedBox(height: 32),

          // LOGOUT BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text("Çıkış Yap"),
                    content:
                        Text("Hesabından çıkış yapmak istediğine emin misin?"),
                    actions: [
                      TextButton(
                        child: Text("Hayır"),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: Text("Evet"),
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  _signOut(context);
                }
              },
              icon: Icon(Icons.logout_rounded, size: 22),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Çıkış Yap',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
