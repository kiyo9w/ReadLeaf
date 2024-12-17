import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'my_library_screen.dart';
import 'settings_screen.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/octicons_icons.dart';

class NavScreen extends StatefulWidget {
  const NavScreen({super.key});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    SearchScreen(),
    MyLibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Colors.white;
    final iconColor = Colors.black;
    final activeColor = Colors.blue;
    final tabBackgroundColor = Colors.white;

    return Scaffold(
      body: SafeArea(
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: GNav(
              haptic: true,
              tabBorderRadius: 50,
              curve: Curves.easeInOut,
              duration: const Duration(milliseconds: 400),
              gap: 8,
              backgroundColor: backgroundColor,
              color: iconColor,
              activeColor: activeColor,
              iconSize: 26,
              tabBackgroundColor: tabBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              tabs: [
                GButton(
                  icon: Icons.home_filled,
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedIndex == 0 ? activeColor : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                GButton(
                  icon: Icons.search,
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedIndex == 1 ? activeColor : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                GButton(
                  icon: Icons.collections_bookmark,
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedIndex == 2 ? activeColor : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                GButton(
                  icon: Icons.settings,
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedIndex == 3 ? activeColor : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
