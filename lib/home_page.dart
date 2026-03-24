import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = '';
  String _userId = '';
  bool _isLoading = true;

  Map<String, dynamic> _absenToday = {};
  List<dynamic> _absenBefore = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('userName') ?? 'User';
    _userId = prefs.getString('userId') ?? '';

    if (_userId.isNotEmpty) {
      await _fetchAbsenData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAbsenData() async {
    try {
      String basicAuth =
          'Basic ${base64Encode(utf8.encode('Absenbapenda:b2@Y@3SaN!'))}';

      var response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/getabsen/$_userId'),
        headers: {'authorization': basicAuth, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _absenToday = data['absentoday'] ?? {};
            _absenBefore = data['absenbefore'] ?? [];
          });
        }
      } else {
        print('Gagal mengambil data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetch absen: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beranda',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            ),
            Text(
              _userName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Dialog konfirmasi logout
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: _logout,
                      child: const Text(
                        'Ya, Keluar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData, // Fitur tarik ke bawah untuk refresh
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CARD ABSEN HARI INI ---
                    const Text(
                      'Absen Hari Ini',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTodayCard(),

                    const SizedBox(height: 24),

                    // --- LIST RIWAYAT ABSEN ---
                    Text(
                      'Riwayat ${_absenBefore.length} Hari Sebelumnya',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _absenBefore.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('Belum ada riwayat absen.'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap:
                                true, // Agar ListView bisa masuk di dalam SingleChildScrollView
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _absenBefore.length,
                            itemBuilder: (context, index) {
                              var item = _absenBefore[index];
                              return _buildHistoryCard(item);
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget khusus untuk mendesain Card Absen Hari Ini
  Widget _buildTodayCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Colors.blueAccent, Colors.lightBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeColumn(
                  'Masuk',
                  _absenToday['jam_masuk'] ?? '-',
                  Icons.login,
                ),
                _buildTimeColumn(
                  'Siang 1',
                  _absenToday['jam_siang'] ?? '-',
                  Icons.restaurant,
                ),
              ],
            ),
            const Divider(color: Colors.white54, height: 30, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeColumn(
                  'Siang 2',
                  _absenToday['jam_siang2'] ?? '-',
                  Icons.work,
                ),
                _buildTimeColumn(
                  'Pulang',
                  _absenToday['jam_pulang'] ?? '-',
                  Icons.logout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget khusus untuk History Card yang dinamis
  Widget _buildHistoryCard(Map<String, dynamic> item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          // <-- Hapus kata 'const' di sini
          backgroundColor: Colors.blue[100], // <-- Gunakan kurung siku
          child: const Icon(
            Icons.calendar_today,
            color: Colors.blueAccent,
            size: 20,
          ), // <-- Pindahkan 'const' ke Icon
        ),
        title: Text(
          item['tanggal'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Masuk: ${item['jam_masuk']} | Pulang: ${item['jam_pulang']}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHistoryDetail('Masuk', item['jam_masuk'] ?? '-'),
                _buildHistoryDetail('Siang 1', item['jam_siang'] ?? '-'),
                _buildHistoryDetail('Siang 2', item['jam_siang2'] ?? '-'),
                _buildHistoryDetail('Pulang', item['jam_pulang'] ?? '-'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Komponen kecil penyusun Card Hari Ini
  Widget _buildTimeColumn(String label, String time, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Komponen kecil penyusun detail History
  Widget _buildHistoryDetail(String label, String time) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
