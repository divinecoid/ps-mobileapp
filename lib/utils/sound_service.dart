import 'package:audioplayers/audioplayers.dart';

/// Service untuk handle audio feedback saat scanning barcode
/// Menggunakan audioplayers untuk custom sound files
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;

  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  /// Play sound untuk barcode berhasil discan (lolos validasi)
  /// Menggunakan assets/audio/correct.mp3
  Future<void> playSuccess() async {
    try {
      await _player.play(AssetSource('audio/correct.mp3'));
      print('✅ Success sound played');
    } catch (e) {
      print('❌ Error playing success sound: $e');
    }
  }

  /// Play sound untuk barcode error (tidak lolos validasi)
  /// Menggunakan assets/audio/wrong.mp3
  Future<void> playError() async {
    try {
      await _player.play(AssetSource('audio/wrong.mp3'));
      print('⚠️ Error sound played');
    } catch (e) {
      print('❌ Error playing error sound: $e');
    }
  }

  /// Dispose audio player when no longer needed
  void dispose() {
    _player.dispose();
  }
}
