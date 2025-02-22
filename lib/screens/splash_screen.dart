import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/providers/theme_provider.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_logo/logo_nobg.png',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
