import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:teilen2/screens/authenticate/login_screen.dart';
import 'package:teilen2/services/auth_service.dart';
import 'package:teilen2/services/firestore_service.dart';
import 'package:teilen2/widgets/auth_form.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _name = '';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  bool _isEmailValid(String email) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);

  Future<void> _submitRegisterForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_password != _confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreler uyuşmuyor.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Kayıt işlemi
      final userCredential =
          await AuthService().register(_email, _password, _name);

      // Firestore'a ekle
      await FirestoreService().addUserToFirestore(
        userCredential.user!.uid,
        _name,
        _email,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E-posta doğrulama bağlantısı gönderildi. Lütfen e-postanızı kontrol edin.',
          ),
        ),
      );

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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF181F1B)
          : Color(0xFFF7FDFD),
      body: Stack(
        children: [
          AuthForm(
            formKey: _formKey,
            title: 'Kayıt Ol',
            submitButtonText: 'Kayıt Ol',
            isLoading: _isLoading,
            onSubmit: _submitRegisterForm,
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
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Lütfen adınızı girin.'
                    : null,
                onSaved: (value) => _name = value!.trim(),
              ),
              const SizedBox(height: 14),
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
                validator: (value) =>
                    (value == null || !_isEmailValid(value.trim()))
                        ? 'Geçerli bir e-posta adresi girin.'
                        : null,
                onSaved: (value) => _email = value!.trim(),
              ),
              const SizedBox(height: 14),
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
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                obscureText: !_isPasswordVisible,
                validator: (value) => (value == null || value.length < 6)
                    ? 'Şifre en az 6 karakter olmalı.'
                    : null,
                onSaved: (value) => _password = value!,
              ),
              const SizedBox(height: 14),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Şifre Tekrar',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      setState(() => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible);
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                obscureText: !_isConfirmPasswordVisible,
                validator: (value) => (value == null || value.length < 6)
                    ? 'Şifre en az 6 karakter olmalı.'
                    : null,
                onSaved: (value) => _confirmPassword = value!,
              ),
            ],
            alternateAction: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => LoginScreen()),
              ),
              child: RichText(
                text: TextSpan(
                  text: "Hesabınız var mı? ",
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  children: [
                    TextSpan(
                      text: "Giriş yapın",
                      style: TextStyle(
                        color: Color(0xFF00C3A5),
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.18),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
