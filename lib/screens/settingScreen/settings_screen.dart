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

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadBalance();
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

  Future<void> _loadBalance() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final result = await ApiService.getBalance(uid);
      setState(() {
        balance = '$result ₺';
      });
    } catch (e) {
      setState(() {
        balance = 'Hata!';
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
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo),
            title: Text('Değiştir'),
            onTap: () {
              Navigator.of(context).pop();
              _pickAndUploadImage();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Sil'),
            onTap: () {
              Navigator.of(context).pop();
              _deleteProfileImage();
            },
          ),
        ],
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
                final result = await ApiService.depositMoney(uid, amount);
                if (result == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Para başarıyla yüklendi!')));
                  await _loadBalance();
                } else if (result.contains('insufficient')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Yetersiz ana bakiye!')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Yükleme başarısız: $result')));
                }
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
                final result = await ApiService.withdrawMoney(uid, amount);
                if (result == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Para başarıyla çekildi!')));
                  await _loadBalance();
                } else if (result.contains('Yetersiz bakiye')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Yetersiz bakiye!')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Çekim başarısız: $result')));
                }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hesap Ayarları')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _showImageOptions,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: (!_isLoading && _profileImageUrl != null)
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: _isLoading
                        ? Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: LoadingIndicator(
                                indicatorType: Indicator.circleStrokeSpin,
                                colors: [Colors.blue],
                              ),
                            ),
                          )
                        : _profileImageUrl == null
                            ? Icon(Icons.camera_alt, size: 30)
                            : null,
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_name != null)
                      Text(
                        _name!,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    if (_email != null)
                      Text(
                        _email!,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Divider(thickness: 1, color: Colors.grey),
          ListTile(
            leading: Icon(Icons.account_balance_wallet_outlined,
                color: Colors.teal, size: 30),
            title: Text(
              '$balance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_downward, color: Colors.green),
                  tooltip: 'Para Yükle',
                  onPressed: _showDepositDialog,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_upward, color: Colors.red),
                  tooltip: 'Para Çek',
                  onPressed: _showWithdrawDialog,
                ),
              ],
            ),
          ),
          Divider(thickness: 1, color: Colors.grey),
          ListTile(
            leading: Icon(Icons.notifications_active, color: Colors.teal),
            title: Text(
              'Bildirim Ayarları',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).pushNamed('/notification-settings');
            },
          ),
          Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _signOut(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                shadowColor: Colors.black,
                elevation: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Çıkış Yap',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
