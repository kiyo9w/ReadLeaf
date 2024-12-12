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
    final backgroundColor = Colors.grey.shade200;
    final iconColor = Colors.black;
    final activeColor = Colors.white;
    final tabBackgroundColor = Theme
        .of(context)
        .colorScheme
        .secondary;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: SizedBox(
        height: 58,
          // child: Padding(
          // padding: const EdgeInsets.only(bottom: 20),
          // Adjust this value to raise the bar
          child: GNav(
            haptic: true,
            tabBorderRadius: 50,
            tabActiveBorder: Border.all(
              color: Theme
                  .of(context)
                  .colorScheme
                  .secondary,
            ),
            tabMargin: const EdgeInsets.fromLTRB(13, 6, 13, 2.5),
            curve: Curves.fastLinearToSlowEaseIn,
            duration: const Duration(milliseconds: 25),
            gap: 5,
            backgroundColor: Colors.grey.shade200,
            color: Colors.black,
            activeColor: Colors.white,
            iconSize: 19,
            tabBackgroundColor: Theme
                .of(context)
                .colorScheme
                .secondary,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
            tabs: const [
              GButton(
                icon: FontAwesome5.home,
                text: ' Home',
                iconColor: Colors.black,
                textStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              GButton(
                icon: Icons.search,
                text: 'Search',
                iconColor: Colors.black,
                textStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              GButton(
                icon: Icons.collections_bookmark,
                text: 'My Library',
                iconColor: Colors.black,
                textStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              GButton(
                icon: Octicons.settings,
                text: 'Settings',
                iconColor: Colors.black,
                textStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: 11,
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
    );
  }
}