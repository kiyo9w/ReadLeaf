import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/core/providers/theme_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../auth/presentation/blocs/auth_event.dart';
import '../../../auth/presentation/blocs/auth_state.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../auth/data/auth_dialog_service.dart';
import 'package:read_leaf/nav_screen.dart';

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

  Widget _buildColorPalette(List<Color> colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: colors.map((color) {
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required AppThemeMode mode,
    required String name,
    required List<Color> colors,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  size: 20,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color:
                    Theme.of(context).colorScheme.surface.withOpacity(0.5),
              ),
              child: Row(
                children: colors.map((color) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Theme',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // System Theme Option
                    ListTile(
                      leading: const Icon(Icons.devices),
                      title: const Text('Follow Device Setting'),
                      trailing: Switch(
                        value: themeProvider.useSystemTheme,
                        onChanged: (bool value) {
                          if (value) {
                            themeProvider.setSystemTheme();
                          } else {
                            // When turning off system theme, use the appropriate theme based on current system brightness
                            final brightness =
                                MediaQuery.of(context).platformBrightness;
                            themeProvider.setThemeMode(
                                brightness == Brightness.dark
                                    ? (themeProvider.lastDarkTheme ??
                                        AppThemeMode.mysteriousDark)
                                    : (themeProvider.lastLightTheme ??
                                        AppThemeMode.readLeafLight));
                          }
                          Navigator.pop(context);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Default Themes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Default Light Theme
                    _buildThemeOption(
                      context,
                      mode: AppThemeMode.readLeafLight,
                      name: 'Light',
                      colors: [
                        const Color(0xFF6B8F71),
                        const Color(0xFFF5F2ED),
                        const Color(0xFFB5A89E),
                        const Color(0xFFE9CFA3),
                        const Color(0xFF4C6A43),
                        const Color(0xFFC4D9C7),
                      ],
                      isSelected: themeProvider.currentThemeMode ==
                          AppThemeMode.readLeafLight,
                      isDark: false,
                      onTap: () {
                        themeProvider.setThemeMode(AppThemeMode.readLeafLight);
                        Navigator.pop(context);
                      },
                    ),

                    // Default Dark Theme
                    _buildThemeOption(
                      context,
                      mode: AppThemeMode.mysteriousDark,
                      name: 'Dark',
                      colors: [
                        const Color(0xFF433E8A),
                        Colors.black,
                        const Color(0xFF6F6BAE),
                        const Color(0xFFA29FDC),
                        const Color(0xFF353165),
                        const Color(0xFF5C58A7),
                      ],
                      isSelected: themeProvider.currentThemeMode ==
                          AppThemeMode.mysteriousDark,
                      isDark: true,
                      onTap: () {
                        themeProvider.setThemeMode(AppThemeMode.mysteriousDark);
                        Navigator.pop(context);
                      },
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Other Light Themes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Other Light Themes
                    ...[
                      {
                        'mode': AppThemeMode.classicLight,
                        'name': 'Luminous',
                        'colors': [
                          Colors.black,
                          const Color(0xFFFE2C55),
                          Colors.white,
                          const Color(0xFFF9F9F9),
                          Colors.grey,
                          const Color(0xFFE0E0E0),
                        ],
                      },
                      {
                        'mode': AppThemeMode.oceanBlue,
                        'name': 'Ocean',
                        'colors': [
                          const Color(0xFF0288D1),
                          const Color(0xFFF0F8FA),
                          const Color(0xFF81D4FA),
                          const Color(0xFF4DD0E1),
                          const Color(0xFFE1F5FE),
                          const Color(0xFFB3E5FC),
                        ],
                      },
                      {
                        'mode': AppThemeMode.pinkCutesy,
                        'name': 'Candy',
                        'colors': [
                          const Color(0xFFFF8FAB),
                          const Color(0xFFFFE4EC),
                          const Color(0xFFFFD3DD),
                          const Color(0xFFFFAFC7),
                          const Color(0xFFFFC2D1),
                          const Color(0xFFFFEBF1),
                        ],
                      },
                    ].map((themeData) => _buildThemeOption(
                          context,
                          mode: themeData['mode'] as AppThemeMode,
                          name: themeData['name'] as String,
                          colors: themeData['colors'] as List<Color>,
                          isSelected: themeProvider.currentThemeMode ==
                              themeData['mode'],
                          isDark: false,
                          onTap: () {
                            themeProvider.setThemeMode(
                                themeData['mode'] as AppThemeMode);
                            Navigator.pop(context);
                          },
                        )),

                    const SizedBox(height: 16),
                    const Text(
                      'Other Dark Themes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Other Dark Themes
                    ...[
                      {
                        'mode': AppThemeMode.classicDark,
                        'name': 'Archaic',
                        'colors': [
                          const Color(0xFF2E4E3F),
                          const Color(0xFF0B1F16),
                          const Color(0xFF16281F),
                          const Color(0xFF4B3A2B),
                          const Color(0xFF1F3329),
                          const Color(0xFF264033),
                        ],
                      },
                      {
                        'mode': AppThemeMode.darkForest,
                        'name': 'Forest',
                        'colors': [
                          const Color(0xFF2E4E3F),
                          const Color(0xFF0B1F16),
                          const Color(0xFF614D3B),
                          const Color(0xFF8C6E54),
                          const Color(0xFF264033),
                          const Color(0xFF4B3A2B),
                        ],
                      },
                      {
                        'mode': AppThemeMode.midNight,
                        'name': 'Midnight',
                        'colors': [
                          const Color(0xFF321246),
                          const Color(0xFF9F6CD2),
                          const Color(0xFF1E062E),
                          const Color(0xFFC7A7E3),
                          const Color(0xFF15032C),
                          const Color(0xFFE1C6F7),
                        ],
                      },
                    ].map((themeData) => _buildThemeOption(
                          context,
                          mode: themeData['mode'] as AppThemeMode,
                          name: themeData['name'] as String,
                          colors: themeData['colors'] as List<Color>,
                          isSelected: themeProvider.currentThemeMode ==
                              themeData['mode'],
                          isDark: true,
                          onTap: () {
                            themeProvider.setThemeMode(
                                themeData['mode'] as AppThemeMode);
                            Navigator.pop(context);
                          },
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NavScreen.globalKey.currentState?.hideNavBar(false);
      });
    });
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
                leading: Icon(themeProvider.isDarkMode
                    ? Icons.dark_mode
                    : Icons.light_mode),
                title: const Text('Theme'),
                subtitle: Text(themeProvider.currentThemeName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (bool value) => themeProvider.toggleTheme(),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () => {
                  _showThemeSelector(context, themeProvider),
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    NavScreen.globalKey.currentState?.hideNavBar(true);
                  })
                },
              ),

              const Divider(height: 32),

              // Reading Section
              const Text(
                'Reading',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Reading Reminders'),
                subtitle: const Text('Get encouraged to continue reading'),
                trailing: Switch(
                  value: themeProvider.showReadingReminders,
                  onChanged: (value) =>
                      themeProvider.setShowReadingReminders(value),
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
