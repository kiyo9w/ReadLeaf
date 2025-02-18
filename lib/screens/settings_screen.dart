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
import '../services/auth_dialog_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AuthState? _lastKnownState;

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
    AuthDialogService.showAuthDialog(context);
  }

  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl != null) {
      return CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) => const Icon(Icons.person, size: 30),
      );
    }
    return const CircleAvatar(
      radius: 30,
      child: Icon(Icons.person, size: 30),
    );
  }

  Widget _buildAccountSection(BuildContext context, AuthState state) {
    if (state is AuthLoading) {
      // Show last known state during loading if available
      if (_lastKnownState is AuthAuthenticated) {
        return _buildAuthenticatedCard(
            context, _lastKnownState as AuthAuthenticated);
      }
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (state is AuthAuthenticated) {
      _lastKnownState = state;
      return _buildAuthenticatedCard(context, state);
    }

    return ListTile(
      leading: const Icon(Icons.login),
      title: const Text('Sign In / Sign Up'),
      subtitle: const Text('Sync your reading progress and preferences'),
      onTap: () => _showAuthDialog(context),
    );
  }

  Widget _buildAuthenticatedCard(
      BuildContext context, AuthAuthenticated state) {
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
          ).then((_) {
            // Refresh auth state when returning from profile screen
            context.read<AuthBloc>().add(AuthCheckRequested());
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildAvatar(state.user.avatarUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.user.username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildAccountSection(context, state),
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
                leading: Icon(themeProvider.currentThemeMode ==
                            AppThemeMode.mysteriousDark ||
                        themeProvider.currentThemeMode ==
                            AppThemeMode.classicDark
                    ? Icons.dark_mode
                    : Icons.light_mode),
                title: const Text('Dark Mode'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: themeProvider.currentThemeMode ==
                              AppThemeMode.mysteriousDark ||
                          themeProvider.currentThemeMode ==
                              AppThemeMode.classicDark,
                      onChanged: (bool value) {
                        themeProvider.setThemeMode(value
                            ? AppThemeMode.mysteriousDark
                            : AppThemeMode.readLeafLight);
                      },
                    ),
                    PopupMenuButton<AppThemeMode>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'More themes',
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          enabled: false,
                          child: Text(
                            'Light Themes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: AppThemeMode.classicLight,
                          child: Row(
                            children: [
                              const Icon(Icons.light_mode, size: 20),
                              const SizedBox(width: 8),
                              const Text('Classic Light'),
                              if (themeProvider.currentThemeMode ==
                                  AppThemeMode.classicLight)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check, size: 20),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: AppThemeMode.readLeafLight,
                          child: Row(
                            children: [
                              const Icon(Icons.light_mode, size: 20),
                              const SizedBox(width: 8),
                              const Text('Read Leaf Light'),
                              if (themeProvider.currentThemeMode ==
                                  AppThemeMode.readLeafLight)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check, size: 20),
                                ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          enabled: false,
                          child: Text(
                            'Dark Themes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: AppThemeMode.classicDark,
                          child: Row(
                            children: [
                              const Icon(Icons.dark_mode, size: 20),
                              const SizedBox(width: 8),
                              const Text('Classic Dark'),
                              if (themeProvider.currentThemeMode ==
                                  AppThemeMode.classicDark)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check, size: 20),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: AppThemeMode.mysteriousDark,
                          child: Row(
                            children: [
                              const Icon(Icons.dark_mode, size: 20),
                              const SizedBox(width: 8),
                              const Text('Mysterious Dark'),
                              if (themeProvider.currentThemeMode ==
                                  AppThemeMode.mysteriousDark)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check, size: 20),
                                ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (AppThemeMode mode) {
                        themeProvider.setThemeMode(mode);
                      },
                    ),
                  ],
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
                onTap: () =>
                    _launchURL('https://github.com/kiyo9w/BlocResearch'),
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share this app with your friend'),
                onTap: _shareApp,
              ),
            ],
          );
        },
      ),
    );
  }
}
