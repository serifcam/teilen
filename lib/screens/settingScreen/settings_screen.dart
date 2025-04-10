import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_indicator/loading_indicator.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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

          /// ✅ Bildirim Ayarları Seçeneği
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
