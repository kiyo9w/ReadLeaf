import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:migrated/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchURL(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  void _shareApp() {
    Share.share(
      'Check out this amazing PDF reader app!',
      subject: 'PDF Reader App',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              ListTile(
                leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                title: Text(isDark ? 'Dark Mode' : 'Light Mode'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.coffee),
                title: const Text('Buy me a coffee'),
                onTap: () => _launchURL('https://www.buymeacoffee.com/kiyo9w'),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Support this open source project'),
                onTap: () =>
                    _launchURL('https://github.com/kiyo9w/BlocResearch'),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share this app with your friend'),
                onTap: _shareApp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
