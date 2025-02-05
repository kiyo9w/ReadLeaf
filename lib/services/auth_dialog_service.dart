import 'package:flutter/material.dart';
import '../widgets/auth/auth_dialog.dart';
import '../screens/nav_screen.dart';

class AuthDialogService {
  static Future<void> showAuthDialog(BuildContext context) async {
    // Hide the nav bar before showing the dialog
    NavScreen.globalKey.currentState?.setNavBarVisibility(true);

    // Show the dialog
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      barrierColor: Colors.black54,
      builder: (context) => const AuthDialog(),
    ).whenComplete(() {
      FocusScope.of(context).unfocus();
      // Show the nav bar after the dialog is closed
      NavScreen.globalKey.currentState?.setNavBarVisibility(false);
    });
  }
}
