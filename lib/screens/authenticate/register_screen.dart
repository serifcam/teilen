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

  Future<void> _submitRegisterForm() async {
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
      // Firebase hata kodlarına göre mesaj göster
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
      // Beklenmeyen hatalar için genel mesaj
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthForm(
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
              if (value == null || value.isEmpty) {
                return 'Lütfen adınızı girin.';
              }
              return null;
            },
            onSaved: (value) => _name = value!,
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
              if (value == null || !value.contains('@')) {
                return 'Geçerli bir e-posta adresi girin.';
              }
              return null;
            },
            onSaved: (value) => _email = value!,
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
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
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
        onSubmit: () {
          if (_formKey.currentState!.validate()) {
            _formKey.currentState!.save();
            _submitRegisterForm();
          }
        },
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
    );
  }
}
