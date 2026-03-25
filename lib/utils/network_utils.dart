import 'dart:io';

class NetworkUtils {
  // Menggunakan 'static' agar fungsinya bisa dipanggil langsung
  // tanpa harus membuat object class-nya terlebih dahulu.
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true; // Internet jalan
      }
    } on SocketException catch (_) {
      return false; // Tidak ada internet
    }
    return false;
  }
}
