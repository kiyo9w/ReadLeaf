import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/core/providers/theme_provider.dart';
import 'package:read_leaf/core/providers/settings_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../auth/presentation/blocs/auth_event.dart';
import '../../../auth/presentation/blocs/auth_state.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../auth/data/auth_dialog_service.dart';
import 'package:read_leaf/nav_screen.dart';
import 'package:flutter/rendering.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AuthState? _lastKnownState;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;

  Future<void> _launchURL(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  void _shareApp() {
    Share.share(
      'Check out this amazing ebook reader app!',
      subject: 'ReadLeaf App',
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (!_isScrollingDown) {
        _isScrollingDown = true;
        NavScreen.globalKey.currentState?.hideNavBar(true);
      }
    }
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (_isScrollingDown) {
        _isScrollingDown = false;
        NavScreen.globalKey.currentState?.hideNavBar(false);
      }
    }
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

    return _buildSettingsCard(
      icon: Icons.login,
      title: 'Sign In / Sign Up',
      subtitle: 'Sync your reading progress and preferences',
      onTap: () => _showAuthDialog(context),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  Widget _buildAuthenticatedCard(
      BuildContext context, AuthAuthenticated state) {
    return _buildSettingsCard(
      customLeading: _buildAvatar(state.user.avatarUrl),
      title: state.user.username,
      subtitle: state.user.email,
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
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  Widget _buildSettingsCard({
    Widget? customLeading,
    IconData? icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Widget? child,
    Color? cardColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: child ??
                Row(
                  children: [
                    if (customLeading != null) ...[
                      customLeading,
                      const SizedBox(width: 16),
                    ] else if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
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
                        ],
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onToggle,
    required VoidCallback onCardTap,
  }) {
    return _buildSettingsCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onCardTap,
      cardColor: Theme.of(context).colorScheme.surface,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch.adaptive(
            value: value,
            onChanged: onToggle,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildSettingsCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.hideNavBar(true);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Text(
                    'Select Theme',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Material(
                    borderRadius: BorderRadius.circular(50),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.close_rounded,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSystemThemeOption(context, themeProvider),
                    const SizedBox(height: 32),
                    _buildThemeSectionHeader(context, 'Default Themes'),
                    const SizedBox(height: 16),
                    _buildModernThemeOption(
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
                    const SizedBox(height: 12),
                    _buildModernThemeOption(
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
                    const SizedBox(height: 32),
                    _buildThemeSectionHeader(context, 'Light Themes'),
                    const SizedBox(height: 16),
                    ...[
                      {
                        'mode': AppThemeMode.classicLight,
                        'name': 'Luminous',
                        'colors': [
                          Colors.black,
                          Colors.white,
                          const Color(0xFFFE2C55),
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
                    ]
                        .map((themeData) => Column(
                              children: [
                                _buildModernThemeOption(
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
                                ),
                                const SizedBox(height: 12),
                              ],
                            ))
                        ,
                    const SizedBox(height: 32),
                    _buildThemeSectionHeader(context, 'Dark Themes'),
                    const SizedBox(height: 16),
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
                          const Color(0xFF120520),
                          const Color(0xFF673AB7),
                          const Color(0xFFD1C4E9),
                          const Color(0xFF220A36),
                          const Color(0xFFBB86FC),
                        ],
                      },
                    ]
                        .map((themeData) => Column(
                              children: [
                                _buildModernThemeOption(
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
                                ),
                                const SizedBox(height: 12),
                              ],
                            ))
                        ,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NavScreen.globalKey.currentState?.hideNavBar(false);
      });
    });
  }

  Widget _buildSystemThemeOption(
      BuildContext context, ThemeProvider themeProvider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: themeProvider.useSystemTheme
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: 2,
          color: themeProvider.useSystemTheme
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final newValue = !themeProvider.useSystemTheme;
            if (newValue) {
              themeProvider.setSystemTheme();
            } else {
              // When turning off system theme, use the appropriate theme
              final brightness = MediaQuery.of(context).platformBrightness;
              themeProvider.setThemeMode(brightness == Brightness.dark
                  ? (themeProvider.lastDarkTheme ?? AppThemeMode.mysteriousDark)
                  : (themeProvider.lastLightTheme ??
                      AppThemeMode.readLeafLight));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.devices_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Follow Device Setting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automatically switch between light and dark theme',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: themeProvider.useSystemTheme,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool value) {
                    if (value) {
                      themeProvider.setSystemTheme();
                    } else {
                      // When turning off system theme, use the appropriate theme
                      final brightness =
                          MediaQuery.of(context).platformBrightness;
                      themeProvider.setThemeMode(brightness == Brightness.dark
                          ? (themeProvider.lastDarkTheme ??
                              AppThemeMode.mysteriousDark)
                          : (themeProvider.lastLightTheme ??
                              AppThemeMode.readLeafLight));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildModernThemeOption(
    BuildContext context, {
    required AppThemeMode mode,
    required String name,
    required List<Color> colors,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: isSelected ? 2 : 1,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors[5]
                            : colors[5],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
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
                const SizedBox(height: 16),
                // Completely redesigned theme preview
                Stack(
                  children: [
                    // Main container with background color
                    Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? colors[1] : colors[1],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    // UI elements to showcase the theme
                    Positioned.fill(
                      child: Column(
                        children: [
                          // App bar simulation
                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors[4]
                                  : colors[0].withOpacity(0.9),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                // Title
                                Container(
                                  height: 12,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: isDark ? colors[5] : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const Spacer(),
                                // Action buttons
                                Container(
                                  height: 10,
                                  width: 10,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? colors[3]
                                        : Colors.white.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 10,
                                  width: 10,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? colors[2]
                                        : Colors.white.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Content area
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 24,
                                        width: 24,
                                        decoration: BoxDecoration(
                                          color: colors[2],
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.bookmark,
                                            size: 12,
                                            color: isDark
                                                ? colors[1]
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        height: 10,
                                        width: 80,
                                        decoration: BoxDecoration(
                                          color: isDark ? colors[3] : colors[4],
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Content rows
                                  _buildColorPaletteRow(colors, isDark),

                                  const SizedBox(height: 10),

                                  // Two content blocks
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? colors[5].withOpacity(0.7)
                                                : colors[0].withOpacity(0.7),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? colors[2].withOpacity(0.7)
                                                : colors[4].withOpacity(0.7),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // const SizedBox(height: 8),

                                  // // Bottom navigation simulation
                                  // Container(
                                  //   height: 20,
                                  //   decoration: BoxDecoration(
                                  //     color: isDark
                                  //         ? colors[4].withOpacity(0.6)
                                  //         : colors[5].withOpacity(0.6),
                                  //     borderRadius: BorderRadius.circular(10),
                                  //   ),
                                  //   child: Row(
                                  //     mainAxisAlignment:
                                  //         MainAxisAlignment.spaceAround,
                                  //     children: List.generate(
                                  //       4,
                                  //       (index) => Container(
                                  //         height: 8,
                                  //         width: 8,
                                  //         decoration: BoxDecoration(
                                  //           color: index == 0
                                  //               ? (isDark
                                  //                   ? colors[5]
                                  //                   : colors[0])
                                  //               : (isDark
                                  //                   ? colors[1].withOpacity(0.6)
                                  //                   : Colors.white
                                  //                       .withOpacity(0.6)),
                                  //           shape: BoxShape.circle,
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorPaletteRow(List<Color> colors, bool isDark) {
    return SizedBox(
      height: 14,
      child: Row(
        children: colors.map((color) {
          final index = colors.indexOf(color);
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 2,
                right: index == colors.length - 1 ? 0 : 2,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isDark
                      ? Colors.black.withOpacity(0.1)
                      : Colors.white.withOpacity(0.1),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Settings',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Account'),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return _buildAccountSection(context, state);
                      },
                    ),
                    _buildSectionHeader('Appearance'),
                    _buildThemeCard(
                      icon: themeProvider.isDarkMode
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      title: 'Theme',
                      subtitle: themeProvider.currentThemeName,
                      value: themeProvider.isDarkMode,
                      onToggle: (value) => themeProvider.toggleTheme(),
                      onCardTap: () {
                        _showThemeSelector(context, themeProvider);
                      },
                    ),
                    _buildSectionHeader('Reading'),
                    _buildSwitchSettingCard(
                      icon: Icons.hourglass_empty,
                      title: 'Loading Screen',
                      subtitle: 'Show book loading transition screen',
                      value: settingsProvider.showLoadingScreen,
                      onChanged: (value) {
                        settingsProvider.toggleLoadingScreen(value);
                      },
                    ),
                    _buildSwitchSettingCard(
                      icon: Icons.notifications,
                      title: 'Reading Reminders',
                      subtitle: 'Get encouraged to continue reading',
                      value: settingsProvider.remindersEnabled,
                      onChanged: (value) {
                        settingsProvider.toggleReminders(value);
                      },
                    ),
                    _buildSectionHeader('About'),
                    _buildSettingsCard(
                      icon: Icons.coffee,
                      title: 'Buy me a coffee',
                      subtitle: 'Support the developer',
                      onTap: () => _launchURL('https://www.buymeacoffee.com/'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                    _buildSettingsCard(
                      icon: Icons.code,
                      title: 'Support this open source project',
                      subtitle: 'Contribute on GitHub',
                      onTap: () => _launchURL('https://github.com/'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                    _buildSettingsCard(
                      icon: Icons.share,
                      title: 'Share this app with friends',
                      subtitle: 'Spread the word',
                      onTap: _shareApp,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
