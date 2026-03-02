import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Service untuk handle audio dan haptic feedback saat scanning barcode
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;

  late AudioPlayer _successPlayer;
  late AudioPlayer _errorPlayer;
  bool _isInitialized = false;

  SoundService._internal() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    _successPlayer = AudioPlayer();
    _errorPlayer = AudioPlayer();
    
    _successPlayer.setReleaseMode(ReleaseMode.stop);
    _errorPlayer.setReleaseMode(ReleaseMode.stop);
    
    _successPlayer.setVolume(1.0);
    _errorPlayer.setVolume(1.0);

    try {
      await _successPlayer.setSource(AssetSource('audio/correct.mp3'));
      await _errorPlayer.setSource(AssetSource('audio/wrong.mp3'));
      _isInitialized = true;
      print('✅ SoundService: Pre-loading assets successful');
    } catch (e) {
      print('❌ SoundService: Failed to pre-load assets: $e');
    }
  }

  /// Feedback untuk scan berhasil
  Future<void> playSuccess() async {
    try {
      // Tambahkan getaran (Haptic Feedback) sebagai fallback jika suara gagal
      await HapticFeedback.lightImpact();
      
      if (!_isInitialized) await _initialize();
      
      print('DEBUG: Playing SUCCESS sound (Pre-loaded)...');
      await _successPlayer.stop();
      await _successPlayer.resume();
      print('✅ DEBUG: SUCCESS sound resume called');
    } catch (e) {
      print('❌ Error in playSuccess: $e');
    }
  }

  /// Feedback untuk scan gagal
  Future<void> playError() async {
    try {
      // Getaran lebih kuat untuk error
      await HapticFeedback.vibrate();
      
      if (!_isInitialized) await _initialize();

      print('DEBUG: Playing ERROR sound (Pre-loaded)...');
      await _errorPlayer.stop();
      await _errorPlayer.resume();
      print('⚠️ DEBUG: ERROR sound resume called');
    } catch (e) {
      print('❌ Error in playError: $e');
    }
  }

  /// Dispose audio players when no longer needed
  void dispose() {
    _successPlayer.dispose();
    _errorPlayer.dispose();
    _isInitialized = false;
  }
}
