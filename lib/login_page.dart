import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'config/api_config.dart';
import 'widgets/background_wrapper.dart'; // Sesuaikan dengan folder tempat kamu
import 'utils/network_utils.dart'; // Tambahkan baris ini

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  // GANTI BAGIAN INI DENGAN IP VPS KAMU (Misal: http://103.xxx.xxx.xxx/api/v1/login)

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // --- TAMBAHKAN PENGECEKAN INTERNET DI SINI ---
      bool adaInternet = await NetworkUtils.hasInternet();
      if (!mounted) return; // Penjaga context

      if (!adaInternet) {
        _showErrorDialog(
          'Koneksi internet terputus. Silakan cek jaringan Anda.',
        );
        return; // Hentikan proses login
      }
      // ----------------------------------------------

      // 1. Buat token Basic Auth dari Username dan Password API
      String basicAuth =
          'Basic ${base64Encode(utf8.encode('Absenbapenda:b2@Y@3SaN!'))}';

      // 2. Tambahkan headers ke dalam request
      var response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: {
          'authorization': basicAuth,
          'Accept': 'application/json', // Memaksa server membalas dengan JSON
        },
        body: {
          'username': _usernameController.text,
          'password': _passwordController.text,
        },
      );

      // 3. Pengecekan Status Code agar lebih aman dari crash HTML
      if (response.statusCode >= 200 && response.statusCode < 500) {
        var data = json.decode(response.body);

        // Jika status 200 dan 'status' dari JSON bernilai true
        if (response.statusCode == 200 && data['status'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userId', data['data']['id'].toString());
          await prefs.setString('userName', data['data']['name']);
          await prefs.setString('imageUrl', data['data']['imageurl'] ?? '');
          // Menggunakan 'unitkerja' sesuai dengan update Laravel terbaru
          await prefs.setString(
            'unitKerja',
            data['data']['unitkerja'] ?? 'Bapenda Pekanbaru',
          );

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          // Menangkap pesan error dari Laravel (salah password, akun nonaktif, dll)
          _showErrorDialog(data['message'] ?? 'Login Gagal');
        }
      } else {
        // Menangkap error fatal server (Status 500)
        _showErrorDialog(
          'Terjadi kesalahan fatal pada server (${response.statusCode}).',
        );
      }
    } catch (e) {
      _showErrorDialog('Terjadi kesalahan koneksi server atau jaringan.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // Cukup bungkus body dengan widget buatan kita tadi
      body: BackgroundWrapper(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fingerprint,
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Absensi Mobile',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                Card(
                  elevation: 4,
                  // Agar Card sedikit transparan dan background terlihat tipis-tipis
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(fontSize: 18),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
