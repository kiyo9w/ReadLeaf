import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLightMode = true;

  void _toggleTheme(bool value) {
    setState(() {
      _isLightMode = value;
    });
    // TODO: dark mode
  }

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
                leading: const Icon(Icons.light_mode),
                title: const Text('Light Mode'),
                trailing: Switch(
                  value: _isLightMode,
                  onChanged: _toggleTheme,
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
                onTap: () => _launchURL('https://github.com/kiyo9w/BlocResearch'),
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