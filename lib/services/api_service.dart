import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2/teilen_api';
    } else {
      return 'http://192.168.1.41/teilen_api'; // Kendi IP'ni koyarsın
    }
  }

  // ✅ Kullanıcıyı MySQL'e kaydet
  static Future<void> registerUserToMySQL(
      String firebaseUid, String email, String name) async {
    final url = '$baseUrl/register_user.php';

    final response = await http.post(
      Uri.parse(url),
      body: {
        'firebase_uid': firebaseUid,
        'email': email,
        'name': name, // <-- Burada artık name gönderiyoruz!
        'balance': '0.00',
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      encoding: Encoding.getByName('utf-8'),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      print('✅ Kullanıcı MySQL\'e kaydedildi!');
    } else {
      throw Exception('MySQL Kayıt hatası: ${data['msg']}');
    }
  }

  // ✅ Kullanıcının bakiyelerini al (main ve normal)
  static Future<Map<String, dynamic>> getBalances(String firebaseUid) async {
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

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      return {
        'balance': double.tryParse(data['balance'].toString()) ?? 0.0,
        'main_balance': double.tryParse(data['main_balance'].toString()) ?? 0.0,
      };
    } else {
      throw Exception('Bakiye alınamadı: ${data['msg']}');
    }
  }

  // ✅ Borç ödeme fonksiyonu (ÇİFT PHP endpoint ile!)
  static Future<void> payDebt(String borrowerUid, String lenderUid,
      double amount, String debtDocId) async {
    // 1. Borçlu için işlem kaydı
    final payUrl = '$baseUrl/pay_debt.php';
    final payResponse = await http.post(
      Uri.parse(payUrl),
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
    final payData = jsonDecode(payResponse.body);

    if (payData['success'] != true) {
      throw Exception('Ödeme başarısız (borrower): ${payData['msg']}');
    }

    // 2. Alacaklı için işlem kaydı
    final paidUrl = '$baseUrl/paid_debt.php';
    final paidResponse = await http.post(
      Uri.parse(paidUrl),
      body: {
        'lender_uid': lenderUid,
        'borrower_uid': borrowerUid,
        'amount': amount.toString(),
        'debt_doc_id': debtDocId,
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      encoding: Encoding.getByName('utf-8'),
    );
    final paidData = jsonDecode(paidResponse.body);

    if (paidData['success'] != true) {
      throw Exception('Ödeme başarısız (lender): ${paidData['msg']}');
    }

    print('✅ Borç hem borçlu hem alacaklı için başarıyla işlendi!');
  }

  // ✅ Para yükleme fonksiyonu (ana banka veritabanından çekilecek)
  static Future<void> depositMoney(String firebaseUid, double amount) async {
    final url = '$baseUrl/deposit_money.php';

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

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      print('✅ Para yüklendi!');
    } else {
      throw Exception('Para yükleme başarısız: ${data['msg']}');
    }
  }

  // ✅ Uygulamadan para çekme (banka ana bakiyeye aktarır)
  static Future<void> withdrawMoney(String firebaseUid, double amount) async {
    final url = '$baseUrl/withdraw_money.php';

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

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      print('✅ Para çekildi!');
    } else {
      throw Exception('Para çekme başarısız: ${data['msg']}');
    }
  }

  // ✅ İşlem geçmişi (transaction history) çek
  static Future<List<Map<String, dynamic>>> fetchTransactions(
      String userUid) async {
    final url = '$baseUrl/get_transactions.php';

    final response = await http.post(
      Uri.parse(url),
      body: {
        'user_uid': userUid,
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      encoding: Encoding.getByName('utf-8'),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      final list = data['transactions'] as List;
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception('İşlem geçmişi çekilemedi: ${data['msg']}');
    }
  }
}
