import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teilen2/screens/authenticate/register_screen.dart';
import 'package:teilen2/screens/mainScreen/main_screen.dart';
import 'package:teilen2/services/auth_service.dart';
import 'package:teilen2/widgets/auth_form.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // E-posta validasyonu için regex
  bool _isEmailValid(String email) {
    RegExp regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  Future<void> _submitLoginForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
    });
    try {
      // Kullanıcı giriş yapar
      await AuthService().signIn(_email, _password);
      // Başarılı giriş sonrası ana ekrana yönlendir
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'Kullanıcı bulunamadı.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Yanlış şifre girdiniz.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Geçersiz e-posta adresi.';
      } else {
        errorMessage = e.message ?? 'Bir hata oluştu.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
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
            title: 'Giriş Yap',
            fields: [
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
            submitButtonText: 'Giriş Yap',
            onSubmit: _submitLoginForm,
            alternateAction: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => RegisterScreen()),
              ),
              child: const Text(
                'Hesabınız yok mu? Kayıt olun.',
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
