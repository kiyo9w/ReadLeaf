import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/screens/home_screen.dart';
import 'package:migrated/screens/search_screen.dart';
import 'package:migrated/screens/my_library_screen.dart';
import 'package:migrated/screens/settings_screen.dart';
import 'package:migrated/screens/character_screen.dart';
import 'package:migrated/utils/file_utils.dart' show FileParser;
import 'package:migrated/utils/utils.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart' hide FileParser;
import 'package:provider/provider.dart';
import 'package:migrated/providers/theme_provider.dart';

class NavScreen extends StatefulWidget {
  const NavScreen({super.key});
  static final GlobalKey<_NavScreenState> globalKey =
      GlobalKey<_NavScreenState>();

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  final ValueNotifier<bool> _hideNavBarNotifier = ValueNotifier<bool>(false);
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    const SearchScreen(),
    const CharacterScreen(),
    const MyLibraryScreen(),
    const SettingsScreen(),
  ];

  void setNavBarVisibility(bool hide) {
    _hideNavBarNotifier.value = hide;
  }

  @override
  void dispose() {
    _hideNavBarNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return BlocListener<FileBloc, FileState>(
      listener: (context, state) {
        if (state is FileViewing) {
          final file = File(state.filePath);
          context.read<ReaderBloc>().add(
                OpenReader('', file: file, filePath: state.filePath),
              );

          // Navigate to the appropriate viewer based on file type
          final fileType = FileParser.determineFileType(state.filePath);
          switch (fileType) {
            case 'pdf':
              Navigator.pushNamed(context, '/pdf_viewer');
              break;
            case 'epub':
              Navigator.pushNamed(context, '/epub_viewer');
              break;
            default:
              Utils.showErrorSnackBar(context, 'Unsupported file format');
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        body: ValueListenableBuilder<bool>(
          valueListenable: _hideNavBarNotifier,
          builder: (context, hideNavBar, child) {
            return IndexedStack(
              index: _selectedIndex,
              children: _screens,
            );
          },
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _hideNavBarNotifier,
          builder: (context, hideNavBar, child) {
            if (hideNavBar) return const SizedBox.shrink();
            return NavigationBar(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_filled),
                  label: 'Home',
                  selectedIcon: Icon(Icons.home_filled,
                      color: Theme.of(context).primaryColor),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.search),
                  label: 'Search',
                  selectedIcon:
                      Icon(Icons.search, color: Theme.of(context).primaryColor),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person),
                  label: 'Character',
                  selectedIcon:
                      Icon(Icons.person, color: Theme.of(context).primaryColor),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.collections_bookmark),
                  label: 'Bookmark',
                  selectedIcon: Icon(Icons.collections_bookmark,
                      color: Theme.of(context).primaryColor),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings),
                  label: 'Settings',
                  selectedIcon: Icon(Icons.settings,
                      color: Theme.of(context).primaryColor),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
