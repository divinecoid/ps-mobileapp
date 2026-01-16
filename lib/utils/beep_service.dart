import 'package:flutter_beep/flutter_beep.dart';

/// Service untuk handle audio feedback saat scanning barcode
/// Menggunakan flutter_beep untuk system beep sounds
class BeepService {
  /// Play beep sound untuk barcode berhasil discan
  /// Menggunakan system success sound
  static Future<void> playSuccessBeep() async {
    try {
      // Play success beep (high pitch)
      await FlutterBeep.beep();
    } catch (e) {
      print('Error playing success beep: $e');
    }
  }
  
  /// Play error sound untuk barcode yang sudah pernah discan
  /// Menggunakan system error sound
  static Future<void> playErrorBeep() async {
    try {
      // Play error beep (low pitch)
      await FlutterBeep.beep(false);
    } catch (e) {
      print('Error playing error beep: $e');
    }
  }
  
  /// Play custom Android sound
  static Future<void> playCustomAndroidSound(int soundId) async {
    try {
      await FlutterBeep.playSysSound(soundId);
    } catch (e) {
      print('Error playing custom sound: $e');
    }
  }
}
