import 'package:flutter/material.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({Key? key}) : super(key: key);

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Picture
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
            // User Name
            const Text(
              'Kullanıcı Adı',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'email@example.com',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            // Profile Options
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
              onTap: () {},
              isLast: true,
            ),
          ],
        ),
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
