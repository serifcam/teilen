import 'dart:io';
import 'dart:convert'; // 🔥 Encoding için
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2/teilen_api';
    } else {
      return 'http://192.168.1.41/teilen_api'; // ⚡️ Senin IP
    }
  }

  // ✅ Kullanıcıyı MySQL'e kaydet
  static Future<void> registerUserToMySQL(
      String firebaseUid, String email) async {
    final url = '$baseUrl/register_user.php';

    final response = await http.post(
      Uri.parse(url),
      body: {
        'firebase_uid': firebaseUid,
        'email': email,
        'balance': '0.00',
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      encoding: Encoding.getByName('utf-8'),
    );

    if (response.statusCode == 200) {
      print('✅ Kullanıcı MySQL\'e kaydedildi!');
    } else {
      print('❌ MySQL Kayıt hatası: ${response.body}');
    }
  }

  // ✅ Kullanıcının bakiyesini al
  static Future<String> getBalance(String firebaseUid) async {
    final url = '$baseUrl/get_balance.php';

    final response = await http.post(
      Uri.parse(url),
      body: {
        'firebase_uid': firebaseUid,
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      encoding: Encoding.getByName('utf-8'),
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Bakiye alınamadı: ${response.body}');
    }
  }

  // ✅ Borç ödeme fonksiyonu
  static Future<void> payDebt(String borrowerUid, String lenderUid,
      double amount, String debtDocId) async {
    final url = '$baseUrl/pay_debt.php';

    final response = await http.post(
      Uri.parse(url),
      body: {
        'borrower_uid': borrowerUid,
        'lender_uid': lenderUid,
        'amount': amount.toString(),
        'debt_doc_id': debtDocId,
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      encoding: Encoding.getByName('utf-8'),
    );

    print('HTTP Status: ${response.statusCode}');
    print('HTTP Body: ${response.body}');

    if (response.statusCode == 200) {
      if (response.body.contains('success')) {
        print('✅ Borç başarıyla ödendi!');
      } else {
        throw Exception('Ödeme başarısız: ${response.body}');
      }
    } else {
      throw Exception('Sunucu hatası: ${response.statusCode}');
    }
  }

  // ✅ Para yükleme fonksiyonu (ana banka veritabanından çekilecek)
  static Future<String> depositMoney(String firebaseUid, double amount) async {
    final url =
        '$baseUrl/deposit_money.php'; // 💸 deposit_money.php dosyasını yazacağız!

    final response = await http.post(
      Uri.parse(url),
      body: {
        'firebase_uid': firebaseUid,
        'amount': amount.toString(),
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      encoding: Encoding.getByName('utf-8'),
    );

    if (response.statusCode == 200) {
      print('✅ Para yükleme cevabı: ${response.body}');
      return response.body.trim(); // whitespace temizleyelim
    } else {
      throw Exception('Para yükleme başarısız: ${response.statusCode}');
    }
  }

  // ✅ Uygulamadan para çekme (banka ana bakiyeye aktarır)
  static Future<String> withdrawMoney(String firebaseUid, double amount) async {
    final url = '$baseUrl/withdraw_money.php'; // 🔥 withdraw_money.php olacak

    final response = await http.post(
      Uri.parse(url),
      body: {
        'firebase_uid': firebaseUid,
        'amount': amount.toString(),
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      encoding: Encoding.getByName('utf-8'),
    );

    if (response.statusCode == 200) {
      print('✅ Para çekme cevabı: ${response.body}');
      return response.body.trim();
    } else {
      throw Exception('Para çekme başarısız: ${response.statusCode}');
    }
  }
}
