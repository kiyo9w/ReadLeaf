import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/providers/theme_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/AuthBloc/auth_bloc.dart';
import '../blocs/AuthBloc/auth_event.dart';
import '../blocs/AuthBloc/auth_state.dart';
import '../widgets/auth/auth_dialog.dart';
import 'profile_screen.dart';

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

  void _showAuthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AuthDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            child: Icon(Icons.person, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.user.username,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.user.email,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign In / Sign Up'),
                subtitle:
                    const Text('Sync your reading progress and preferences'),
                onTap: () => _showAuthDialog(context),
              );
            },
          ),
          const Divider(height: 32),

          // Appearance Section
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: Text(isDark ? 'Dark Mode' : 'Light Mode'),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),

          const Divider(height: 32),

          // About Section
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.coffee),
            title: const Text('Buy me a coffee'),
            onTap: () => _launchURL('https://www.buymeacoffee.com/kiyo9w'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Support this open source project'),
            onTap: () => _launchURL('https://github.com/kiyo9w/BlocResearch'),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share this app with your friend'),
            onTap: _shareApp,
          ),
        ],
      ),
    );
  }
}
