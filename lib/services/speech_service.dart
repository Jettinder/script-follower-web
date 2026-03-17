import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Unified speech recognition service
/// Uses Web Speech API on web platforms
class WebSpeechService {
  final _controller = StreamController<String>.broadcast();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';

  Stream<String> get transcriptStream => _controller.stream;
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            // Auto-restart if still supposed to be listening
            if (_isListening) {
              _restartListening();
            }
          }
        },
      );
      
      if (!_isInitialized) {
        throw StateError('Speech recognition not available');
      }
      
      debugPrint('Web Speech initialized');
    } catch (e) {
      debugPrint('Web Speech init error: $e');
      rethrow;
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized) await init();
    if (_isListening) return;

    try {
      _isListening = true;
      _lastWords = '';
      
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.trim().toLowerCase();
          if (text.isNotEmpty && text != _lastWords) {
            _lastWords = text;
            debugPrint('Web Speech: $text (final: ${result.finalResult})');
            _controller.add(text);
          }
        },
        localeId: 'it_IT', // Italian
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
      
      debugPrint('Web Speech started listening');
    } catch (e) {
      _isListening = false;
      debugPrint('Web Speech start error: $e');
      rethrow;
    }
  }

  Future<void> _restartListening() async {
    if (!_isListening) return;
    
    // Small delay before restarting
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (_isListening && !_speech.isListening) {
      try {
        await _speech.listen(
          onResult: (result) {
            final text = result.recognizedWords.trim().toLowerCase();
            if (text.isNotEmpty && text != _lastWords) {
              _lastWords = text;
              _controller.add(text);
            }
          },
          localeId: 'it_IT',
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        );
      } catch (e) {
        debugPrint('Web Speech restart error: $e');
      }
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      _isListening = false;
      await _speech.stop();
      debugPrint('Web Speech stopped');
    } catch (e) {
      debugPrint('Web Speech stop error: $e');
    }
  }

  Future<void> dispose() async {
    await stopListening();
    await _controller.close();
  }
}
