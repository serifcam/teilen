import 'package:flutter/material.dart';
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

  Future<void> _submitLoginForm() async {
    try {
      // Kullanıcı giriş yapar
      await AuthService().signIn(_email, _password);

      // Eğer giriş başarılıysa ana ekrana yönlendirme
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    } catch (error) {
      // Kullanıcıya hata mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthForm(
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
        submitButtonText: 'Giriş Yap',
        onSubmit: () {
          if (_formKey.currentState!.validate()) {
            _formKey.currentState!.save();
            _submitLoginForm();
          }
        },
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
    );
  }
}
