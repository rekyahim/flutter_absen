import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'login_page.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = '';
  String _userId = '';
  String _imageUrl = '';
  String _unitKerja = '';
  bool _isLoading = true;
  int _selectedIndex = 0; // Untuk mengatur tab aktif di Footer

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
    _imageUrl = prefs.getString('imageUrl') ?? '';
    _unitKerja = prefs.getString('unitKerja') ?? 'Bapenda Pekanbaru';

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
      }
    } catch (e) {
      print('Error fetch absen: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _prosesAbsensi() async {
    // 1. Tampilkan Dialog Loading "Menunggu..."
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Menunggu lokasi & server..."),
            ],
          ),
        );
      },
    );

    try {
      // 2. Cek apakah layanan GPS HP menyala
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Navigator.pop(context); // Tutup loading
        _showSnackBar(
          'Layanan GPS tidak aktif. Mohon nyalakan GPS Anda.',
          Colors.red,
        );
        return;
      }

      // 3. Cek Izin Aplikasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Navigator.pop(context);
          _showSnackBar('Izin lokasi ditolak oleh pengguna.', Colors.red);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        Navigator.pop(context);
        _showSnackBar(
          'Izin lokasi diblokir permanen. Ubah di pengaturan HP.',
          Colors.red,
        );
        return;
      }

      // 4. Ambil Kordinat Lokasi (Akurasi Tinggi)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 5. PENGECEKAN FAKE GPS SANGAT KETAT
      if (position.isMocked) {
        Navigator.pop(context); // Tutup loading
        _showSnackBar(
          'TERDETEKSI FAKE GPS! Mohon matikan aplikasi Fake GPS Anda untuk melakukan absensi.',
          Colors.redAccent,
        );
        return;
      }

      // 6. Siapkan Data untuk dikirim ke Laravel
      String basicAuth =
          'Basic ${base64Encode(utf8.encode('Absenbapenda:b2@Y@3SaN!'))}';

      var response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/doabsen'),
        headers: {'authorization': basicAuth, 'Accept': 'application/json'},
        body: {
          'user_id': _userId,
          'lat': position.latitude.toString(),
          'lan': position.longitude
              .toString(), // Sesuai dengan field di Laravel kamu
        },
      );

      Navigator.pop(
        context,
      ); // Tutup dialog loading setelah dapat balasan server

      // 7. Proses Balasan dari Server
      var data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _showSnackBar(data['message'] ?? 'Absen Berhasil', Colors.green);
        _loadData(); // Refresh data riwayat absen otomatis
      } else {
        // Tampilkan pesan error dari backend (misal: "Anda Sedang Tidak pada posisi Kantor")
        _showSnackBar(
          data['message'] ?? 'Gagal melakukan absensi',
          Colors.orange,
        );
      }
    } catch (e) {
      Navigator.pop(context); // Tutup loading jika error sistem
      _showSnackBar('Terjadi kesalahan sistem atau jaringan.', Colors.red);
      print("Error Absen: $e");
    }
  }

  // Fungsi helper untuk memunculkan pesan (SnackBar)
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Fungsi untuk menangani klik pada Footer
  void _onItemTapped(int index) {
    if (index == 1) {
      // Panggil fungsi absen saat tombol tengah diklik
      _prosesAbsensi();
    } else if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Halaman Profil sedang dalam pengembangan 🛠️'),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        toolbarHeight: 80, // Ditinggikan sedikit agar lega
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _unitKerja,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Foto Profil
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              // Jika URL foto ada dan valid, tampilkan fotonya. Jika tidak, pakai icon default.
              backgroundImage:
                  _imageUrl.isNotEmpty && _imageUrl.startsWith('http')
                  ? NetworkImage(_imageUrl)
                  : null,
              child: _imageUrl.isEmpty || !_imageUrl.startsWith('http')
                  ? const Icon(Icons.person, size: 30, color: Colors.blueAccent)
                  : null,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Absen Hari Ini',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTodayCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Riwayat ${_absenBefore.length} Hari Sebelumnya',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                            shrinkWrap: true,
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

      // --- FOOTER NAVBAR ---
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
            BottomNavigationBarItem(
              icon: Icon(Icons.fingerprint, size: 32),
              label: 'Absen',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }

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

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: const Icon(
            Icons.calendar_today,
            color: Colors.blueAccent,
            size: 20,
          ),
        ),
        title: Text(
          _formatTanggal(item['tanggal'] ?? '-'),
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

  // Fungsi untuk mengubah format YYYY-MM-DD menjadi DD Bulan YYYY
  // Fungsi untuk mengubah format YYYY-MM-DD menjadi DD Bulan YYYY
  String _formatTanggal(String tanggalApi) {
    if (tanggalApi == '-' || tanggalApi.isEmpty) {
      return '-';
    }

    try {
      List<String> parts = tanggalApi.split('-');
      if (parts.length != 3) {
        return tanggalApi; // Jaga-jaga kalau formatnya bukan YYYY-MM-DD
      }

      List<String> namaBulan = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      int bulanIndex = int.parse(parts[1]);
      String tanggal = parts[2];
      String tahun = parts[0];

      return '$tanggal ${namaBulan[bulanIndex]} $tahun';
    } catch (e) {
      return tanggalApi; // Kembalikan ke format asli jika terjadi error parsing
    }
  }
}
