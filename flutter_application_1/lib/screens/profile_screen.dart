import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfilScreen extends StatefulWidget {
  final Future<void> Function() onLogout;

  const ProfilScreen({super.key, required this.onLogout});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  late Future<Map<String, dynamic>> _userFuture;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _userFuture = ApiService.getCurrentUser();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Çıkış Yap"),
        content: const Text("Hesabından çıkış yapmak istediğine emin misin?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB04242)),
            child: const Text("Çıkış Yap"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loggingOut = true);
    await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userFuture,
        builder: (context, snapshot) {
          final name = snapshot.data?['name']?.toString() ?? 'Kullanıcı';
          final email = snapshot.data?['email']?.toString() ?? '';

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const CircularProgressIndicator()
                else ...[
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                _buildProfileOption(
                  icon: Icons.account_circle,
                  title: 'Hesap Bilgileri',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.lock,
                  title: 'Şifre Değiştir',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.notifications,
                  title: 'Bildirimler',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.settings,
                  title: 'Ayarlar',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.help,
                  title: 'Yardım',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.logout,
                  title: 'Çıkış Yap',
                  onTap: _loggingOut ? () {} : _confirmLogout,
                  isLast: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}
