// lib/services/audio_service.dart
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playRainSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('rain_sound.mp3'));

      for (double volume = 0.0; volume <= 1.0; volume += 0.1) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _audioPlayer.setVolume(volume);
      }
    } catch (e) {
      print('Error playing rain sound: $e');
    }
  }

  Future<void> stopRainSound() async {
    try {
      for (double volume = 1.0; volume >= 0.0; volume -= 0.1) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _audioPlayer.setVolume(volume);
      }
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping rain sound: $e');
    }
  }
}