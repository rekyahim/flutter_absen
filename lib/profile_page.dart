import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'config/api_config.dart';
import 'widgets/background_wrapper.dart'; // Pastikan path ini benar

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userName = '';
  String _userId = '';
  String _imageUrl = '';
  String _unitKerja = '';
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'User';
      _userId = prefs.getString('userId') ?? '';
      _imageUrl = prefs.getString('imageUrl') ?? '';
      _unitKerja = prefs.getString('unitKerja') ?? 'Bapenda Pekanbaru';
    });
  }

  // Fungsi untuk mengambil gambar dari galeri dan LANGSUNG KOMPRESI 50%
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // imageQuality: 50 akan mengkompres ukuran file menjadi 50% dari aslinya
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Fungsi untuk mengupload gambar ke server Laravel
  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String basicAuth =
          'Basic ${base64Encode(utf8.encode('Absenbapenda:b2@Y@3SaN!'))}';

      // Menggunakan MultipartRequest untuk mengirim file
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/update-photo/$_userId'),
      );

      request.headers['authorization'] = basicAuth;
      request.headers['Accept'] = 'application/json';

      // Memasukkan file gambar ke dalam request
      request.files.add(
        await http.MultipartFile.fromPath('image', _imageFile!.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Update URL gambar baru ke SharedPreferences agar beranda ikut terupdate
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('imageUrl', data['imageurl']);

          setState(() {
            _imageUrl = data['imageurl'];
            _imageFile = null; // Reset file pilihan setelah sukses
          });

          _showSnackBar('Foto profil berhasil diperbarui!', Colors.green);
        } else {
          _showSnackBar(
            data['message'] ?? 'Gagal memperbarui foto',
            Colors.orange,
          );
        }
      } else {
        _showSnackBar(
          'Terjadi kesalahan pada server (${response.statusCode})',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan jaringan.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: BackgroundWrapper(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              color: Colors.white.withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40.0,
                  horizontal: 20.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tampilan Foto Profil
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : (_imageUrl.isNotEmpty &&
                                        _imageUrl.startsWith('http')
                                    ? NetworkImage(_imageUrl)
                                    : null),
                          child:
                              _imageFile == null &&
                                  (_imageUrl.isEmpty ||
                                      !_imageUrl.startsWith('http'))
                              ? const Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        // Tombol Edit (Kamera) kecil di pojok foto
                        FloatingActionButton.small(
                          onPressed: _pickImage,
                          backgroundColor: Colors.blueAccent,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _unitKerja,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Tombol Simpan hanya muncul jika ada gambar baru yang dipilih
                    if (_imageFile != null)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _uploadImage,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(
                            _isLoading ? 'Menyimpan...' : 'Simpan Foto Baru',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
