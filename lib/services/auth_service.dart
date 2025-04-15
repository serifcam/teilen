import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Kullanıcı giriş yapar
  Future<UserCredential> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // E-posta doğrulama kontrolü
      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        throw Exception(
            'E-posta adresiniz doğrulanmamış. Lütfen e-postanızı kontrol edin.');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Kullanıcı bulunamadı. Lütfen kayıt olun.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Hatalı şifre. Lütfen tekrar deneyin.');
      } else {
        throw Exception('Giriş sırasında bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Beklenmeyen bir hata oluştu: $e');
    }
  }

  /// Kullanıcı çıkış yapar
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Çıkış sırasında bir hata oluştu: $e');
    }
  }

  /// Yeni kullanıcı kaydeder ve doğrulama e-postası gönderir
  Future<UserCredential> register(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // E-posta doğrulama gönder
      await userCredential.user!.sendEmailVerification();

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception(
            'Bu e-posta zaten kullanılıyor. Lütfen başka bir e-posta deneyin.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Geçersiz bir e-posta adresi girdiniz.');
      } else if (e.code == 'weak-password') {
        throw Exception(
            'Şifreniz çok zayıf. Lütfen daha güçlü bir şifre belirleyin.');
      } else {
        throw Exception('Kayıt sırasında bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Beklenmeyen bir hata oluştu: $e');
    }
  }

  /// Şifre sıfırlama işlemi
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Bu e-posta ile kayıtlı bir kullanıcı bulunamadı.');
      } else {
        throw Exception(
            'Şifre sıfırlama sırasında bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Beklenmeyen bir hata oluştu: $e');
    }
  }

  /// Kullanıcının oturum açıp açmadığını kontrol eder
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Kullanıcı e-posta doğrulama işlemi
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      } else {
        throw Exception('Kullanıcı doğrulanmış veya giriş yapılmamış.');
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(
          'E-posta doğrulama gönderimi sırasında bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Beklenmeyen bir hata oluştu: $e');
    }
  }

  /// E-posta doğrulama durumu kontrolü
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload(); // Kullanıcı bilgilerini güncelle
      return user.emailVerified;
    }
    return false;
  }
}
