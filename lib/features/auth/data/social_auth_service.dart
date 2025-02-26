import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SocialAuthService {
  final supabase = Supabase.instance.client;
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '8655995403-ekl7g6elabs8ha4ro3fobjbv4r2tv39g.apps.googleusercontent.com',
  );

  Future<AuthResponse?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Could not get auth details from Google');
      }

      return await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } on PlatformException catch (e) {
      debugPrint('Platform Exception signing in with Google: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return null;
    }
  }

  Future<AuthResponse?> signInWithApple() async {
    try {
      if (!await SignInWithApple.isAvailable()) {
        throw Exception('Sign in with Apple is not available on this device');
      }

      final rawNonce = supabase.auth.generateRawNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: rawNonce,
      );

      if (credential.identityToken == null) return null;

      return await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
        nonce: rawNonce,
      );
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      return null;
    }
  }

  Future<AuthResponse?> signInWithFacebook() async {
    try {
      // Sign in with Supabase using OAuth
      await supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'io.supabase.readleaf://login-callback/',
      );

      // The OAuth sign-in will redirect to the callback URL
      // The app will handle the redirect and complete the sign-in process
      // We return null here as the actual auth response will be handled by the redirect
      return null;
    } on AuthException catch (e) {
      debugPrint('Error signing in with Facebook: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error signing in with Facebook: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        FacebookAuth.instance.logOut(),
      ]);
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}
