import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playDing() async {
    try {
      // Use a simple beep sound from the web
      await _player.play(UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'));
    } catch (e) {
      // Ignore errors on web
    }
  }

  void dispose() {
    _player.dispose();
  }
}
