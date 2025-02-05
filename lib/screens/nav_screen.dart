import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:read_leaf/screens/home_screen.dart';
import 'package:read_leaf/screens/search_screen.dart';
import 'package:read_leaf/screens/my_library_screen.dart';
import 'package:read_leaf/screens/settings_screen.dart';
import 'package:read_leaf/screens/character_screen.dart';
import 'package:read_leaf/utils/file_utils.dart';
import 'package:read_leaf/injection.dart';
import 'package:read_leaf/blocs/FileBloc/file_bloc.dart';
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart';

class NavScreen extends StatefulWidget {
  const NavScreen({super.key});
  final double iconsize = 28;
  static final GlobalKey<_NavScreenState> globalKey =
      GlobalKey<_NavScreenState>();

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  final ValueNotifier<bool> _hideNavBarNotifier = ValueNotifier<bool>(false);

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDarkMode ? Colors.white : Colors.black;
    final inactiveColor = isDarkMode
        ? Colors.white.withOpacity(0.5)
        : Colors.black.withOpacity(0.5);

    return BlocListener<FileBloc, FileState>(
      listener: (context, state) {
        if (state is FileViewing) {
          final file = File(state.filePath);
          context.read<ReaderBloc>().add(
                OpenReader('', file: file, filePath: state.filePath),
              );
          Navigator.pushNamed(context, '/pdf_viewer');
        }
      },
      child: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: _hideNavBarNotifier,
          builder: (context, hideNavBar, child) {
            return PersistentTabView(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hideNavigationBar: hideNavBar,
              tabs: [
                PersistentTabConfig(
                  screen: HomeScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.home),
                    inactiveIcon: const Icon(Icons.home_outlined),
                    iconSize: widget.iconsize,
                    title: "Home",
                    activeForegroundColor: activeColor,
                    inactiveForegroundColor: inactiveColor,
                  ),
                ),
                PersistentTabConfig(
                  screen: const SearchScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.search),
                    inactiveIcon: const Icon(Icons.search_outlined),
                    iconSize: widget.iconsize,
                    title: "Search",
                    activeForegroundColor: activeColor,
                    inactiveForegroundColor: inactiveColor,
                  ),
                ),
                PersistentTabConfig(
                  screen: const CharacterScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.person),
                    inactiveIcon: const Icon(Icons.person_outline),
                    iconSize: widget.iconsize,
                    title: "Character",
                    activeForegroundColor: activeColor,
                    inactiveForegroundColor: inactiveColor,
                  ),
                ),
                PersistentTabConfig(
                  screen: const MyLibraryScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.collections_bookmark),
                    inactiveIcon:
                        const Icon(Icons.collections_bookmark_outlined),
                    iconSize: widget.iconsize,
                    title: "Bookmark",
                    activeForegroundColor: activeColor,
                    inactiveForegroundColor: inactiveColor,
                  ),
                ),
                PersistentTabConfig(
                  screen: const SettingsScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.settings),
                    inactiveIcon: const Icon(Icons.settings_outlined),
                    iconSize: widget.iconsize,
                    title: "Settings",
                    activeForegroundColor: activeColor,
                    inactiveForegroundColor: inactiveColor,
                  ),
                ),
              ],
              navBarBuilder: (navBarConfig) => Style1BottomNavBar(
                navBarConfig: navBarConfig,
                navBarDecoration: NavBarDecoration(
                  color: Theme.of(context).appBarTheme.backgroundColor!,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
