import 'package:flutter/material.dart';
import 'package:teilen2/services/auth_service.dart';
import 'package:teilen2/widgets/auth_form.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  bool _isLoading = false;

  bool _isEmailValid(String email) {
    RegExp regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  Future<void> _submitResetForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      await AuthService().resetPassword(_email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hata: ${e.toString()}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor =
        isDark ? const Color(0xFF18D7B1) : const Color(0xFF0B9581);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF181F1B) : const Color(0xFFF7FDFD),
      body: Stack(
        children: [
          AuthForm(
            formKey: _formKey,
            title: 'Şifre Sıfırla',
            submitButtonText: 'Bağlantı Gönder',
            isLoading: _isLoading,
            onSubmit: _submitResetForm,
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
                validator: (value) =>
                    (value == null || !_isEmailValid(value.trim()))
                        ? 'Geçerli bir e-posta adresi girin.'
                        : null,
                onSaved: (value) => _email = value!.trim(),
              ),
            ],
            alternateAction: Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: buttonColor,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Geri Dön'),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.18),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
