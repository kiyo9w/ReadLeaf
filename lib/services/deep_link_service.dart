import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_links/uni_links.dart';

enum DeepLinkStatus {
  notInitialized,
  initialized,
  error,
}

@lazySingleton
class DeepLinkService {
  final supabase = Supabase.instance.client;
  DeepLinkStatus _status = DeepLinkStatus.notInitialized;
  String? _lastError;
  bool _isInitialized = false;
  StreamSubscription<Uri?>? _subscription;

  DeepLinkStatus get status => _status;
  String? get lastError => _lastError;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Handle deep link when app is started from terminated state
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        unawaited(_handleDeepLink(initialUri));
      }

      // Handle deep link when app is in background or foreground
      _subscription = uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null) {
            unawaited(_handleDeepLink(uri));
          }
        },
        onError: (err) {
          _lastError = err.toString();
          _status = DeepLinkStatus.error;
          debugPrint('Deep link stream error: $err');
        },
      );

      _isInitialized = true;
      _status = DeepLinkStatus.initialized;
      return true;
    } on PlatformException catch (e) {
      _lastError = e.message;
      _status = DeepLinkStatus.error;
      debugPrint('Deep link initialization error: ${e.message}');
      return false;
    } catch (e) {
      _lastError = e.toString();
      _status = DeepLinkStatus.error;
      debugPrint('Unexpected error during deep link initialization: $e');
      return false;
    }
  }

  Future<bool> _handleDeepLink(Uri uri) async {
    try {
      if (uri.host == 'login-callback') {
        // Handle OAuth callback
        final response = await supabase.auth.getSessionFromUrl(uri);
        debugPrint('Successfully handled OAuth callback: ${uri.toString()}');
        return true;
            }
      _lastError = 'Unhandled deep link host: ${uri.host}';
      return false;
    } on AuthException catch (e) {
      _lastError = 'Auth error: ${e.message}';
      debugPrint('Auth error handling deep link: ${e.message}');
      return false;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error handling deep link: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    _status = DeepLinkStatus.notInitialized;
  }
}
