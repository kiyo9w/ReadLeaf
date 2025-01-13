import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:migrated/screens/home_screen.dart';
import 'package:migrated/screens/search_screen.dart';
import 'package:migrated/screens/my_library_screen.dart';
import 'package:migrated/screens/settings_screen.dart';
import 'package:migrated/screens/character_screen.dart';
import 'package:migrated/utils/file_utils.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';

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
    return BlocListener<FileBloc, FileState>(
      listener: (context, state) {
        if (state is FileViewing) {
          final file = File(state.filePath);
          context.read<ReaderBloc>().add(
                OpenReader('', file: file, filePath: state.filePath),
              );
          Navigator.pushNamed(context, '/viewer');
        }
      },
      child: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: _hideNavBarNotifier,
          builder: (context, hideNavBar, child) {
            return PersistentTabView(
              hideNavigationBar: hideNavBar,
              tabs: [
                PersistentTabConfig(
                  screen: HomeScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.home_filled),
                    inactiveIcon: const Icon(Icons.home_filled),
                    iconSize: widget.iconsize,
                    title: "Home",
                    activeForegroundColor: Colors.blue,
                    inactiveForegroundColor: Colors.black,
                  ),
                ),
                PersistentTabConfig(
                  screen: const SearchScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.search),
                    inactiveIcon: const Icon(Icons.search),
                    iconSize: widget.iconsize,
                    title: "Search",
                    activeForegroundColor: Colors.blue,
                    inactiveForegroundColor: Colors.black,
                  ),
                ),
                PersistentTabConfig(
                  screen: const CharacterScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.person),
                    inactiveIcon: const Icon(Icons.person),
                    iconSize: widget.iconsize,
                    title: "Character",
                    activeForegroundColor: Colors.blue,
                    inactiveForegroundColor: Colors.black,
                  ),
                ),
                PersistentTabConfig(
                  screen: const MyLibraryScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.collections_bookmark),
                    inactiveIcon: const Icon(Icons.collections_bookmark),
                    iconSize: widget.iconsize,
                    title: "Bookmark",
                    activeForegroundColor: Colors.blue,
                    inactiveForegroundColor: Colors.black,
                  ),
                ),
                PersistentTabConfig(
                  screen: const SettingsScreen(),
                  item: ItemConfig(
                    icon: const Icon(Icons.settings),
                    inactiveIcon: const Icon(Icons.settings),
                    iconSize: widget.iconsize,
                    title: "Settings",
                    activeForegroundColor: Colors.blue,
                    inactiveForegroundColor: Colors.black,
                  ),
                ),
              ],
              navBarBuilder: (navBarConfig) => Style1BottomNavBar(
                navBarConfig: navBarConfig,
              ),
            );
          },
        ),
      ),
    );
  }
}
