import 'dart:async';

/// Global event bus untuk menangani token expiration
/// Digunakan untuk trigger logout dari mana saja tanpa BuildContext
class AuthEventBus {
  static final _tokenExpiredController = StreamController<void>.broadcast();
  
  /// Stream untuk listen token expired events
  static Stream<void> get onTokenExpired => _tokenExpiredController.stream;
  
  /// Trigger token expired event
  static void notifyTokenExpired() {
    print('🔒 Token expired - notifying listeners');
    _tokenExpiredController.add(null);
  }
  
  /// Dispose stream controller
  static void dispose() {
    _tokenExpiredController.close();
  }
}
