import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:teilen2/screens/authenticate/login_screen.dart';
import 'package:teilen2/services/auth_service.dart';
import 'package:teilen2/services/firestore_service.dart';
import 'package:teilen2/widgets/auth_form.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _name = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // E-posta validasyonu için regex
  bool _isEmailValid(String email) {
    RegExp regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  Future<void> _submitRegisterForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
    });
    try {
      // Kullanıcı kaydı
      final userCredential = await AuthService().register(_email, _password);

      // Kullanıcı bilgilerini Firestore'a ekle
      await FirestoreService().addUserToFirestore(
        userCredential.user!.uid,
        _name,
        _email,
      );

      // Kullanıcıya e-posta doğrulama mesajı gönderildiğini bildir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'E-posta doğrulama bağlantısı gönderildi. Lütfen e-postanızı kontrol edin.'),
        ),
      );

      // Kullanıcıyı giriş ekranına yönlendir
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage =
            'Bu e-posta zaten kullanılıyor. Lütfen farklı bir e-posta deneyin.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Geçersiz bir e-posta adresi girdiniz.';
      } else if (e.code == 'weak-password') {
        errorMessage =
            'Şifreniz çok zayıf. Lütfen daha güçlü bir şifre belirleyin.';
      } else {
        errorMessage = 'Bir hata oluştu: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AuthForm(
            formKey: _formKey,
            title: 'Kayıt Ol',
            fields: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen adınızı girin.';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'E-Posta',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || !_isEmailValid(value.trim())) {
                    return 'Geçerli bir e-posta adresi girin.';
                  }
                  return null;
                },
                onSaved: (value) => _email = value!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                obscureText: !_isPasswordVisible,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Şifre en az 6 karakter olmalı.';
                  }
                  return null;
                },
                onSaved: (value) => _password = value!,
              ),
            ],
            submitButtonText: 'Kayıt Ol',
            onSubmit: _submitRegisterForm,
            alternateAction: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => LoginScreen()),
              ),
              child: const Text(
                'Hesabınız var mı? Giriş yapın.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
