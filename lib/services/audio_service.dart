import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  Future<void> initialize() async {
    try {
      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  Future<void> playNotificationSound() async {
    if (!_isInitialized) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/notification.mp3'));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
