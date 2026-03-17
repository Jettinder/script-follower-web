import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/battuta.dart';
import '../models/copione.dart';
import '../models/sessione_prova.dart';
import '../services/matching_service.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import 'settings_provider.dart';

class ProvaProvider extends ChangeNotifier {
  final StorageService storage;
  final MatchingService matching;
  final SettingsProvider settings;
  final SoundService sound;

  ProvaProvider({
    required this.storage,
    required this.matching,
    required this.settings,
    SoundService? sound,
  }) : sound = sound ?? SoundService();

  Copione? _copione;
  String? _personaggioSelezionato;
  int _battutaCorrente = 0;
  bool _autoMode = false;  // Auto-advance mode
  Timer? _autoTimer;

  Copione? get copione => _copione;
  String? get personaggioSelezionato => _personaggioSelezionato;
  int get battutaCorrente => _battutaCorrente;
  bool get isAutoMode => _autoMode;

  void loadCopione(Copione c) {
    _copione = c;
    _battutaCorrente = 0;
    notifyListeners();
  }

  void selectPersonaggio(String p) {
    _personaggioSelezionato = p;
    notifyListeners();
  }

  // Start auto-advance mode (automatically advances every few seconds)
  void startAutoMode() {
    if (_copione == null) return;
    
    _autoMode = true;
    _startAutoTimer();
    notifyListeners();
  }

  void stopAutoMode() {
    _autoMode = false;
    _autoTimer?.cancel();
    _autoTimer = null;
    notifyListeners();
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    
    if (!_autoMode || _copione == null) return;
    
    // Auto-advance every 8-12 seconds depending on text length
    final currentBattuta = _copione!.battute[_battutaCorrente];
    final baseTime = 8; // Base seconds
    final extraTime = (currentBattuta.testo.length / 100).floor().clamp(0, 6);
    final totalSeconds = baseTime + extraTime;
    
    _autoTimer = Timer(Duration(seconds: totalSeconds), () {
      if (_autoMode && _battutaCorrente < _copione!.battute.length - 1) {
        nextBattuta();
        _startAutoTimer(); // Restart timer for next battuta
      }
    });
  }

  // Manual navigation methods
  void nextBattuta() {
    if (_copione == null) return;
    if (_battutaCorrente < _copione!.battute.length - 1) {
      _battutaCorrente++;
      _checkNextTurnAlert();
      
      if (_autoMode) {
        _startAutoTimer(); // Restart timer
      }
      
      notifyListeners();
    }
  }

  void previousBattuta() {
    if (_copione == null) return;
    if (_battutaCorrente > 0) {
      _battutaCorrente--;
      
      if (_autoMode) {
        _startAutoTimer(); // Restart timer
      }
      
      notifyListeners();
    }
  }

  int? nextMyTurnIn() {
    if (_copione == null || _personaggioSelezionato == null) return null;
    for (int offset = 1; offset <= 3; offset++) {
      final idx = _battutaCorrente + offset;
      if (idx < _copione!.battute.length) {
        final b = _copione!.battute[idx];
        if (b.personaggio == _personaggioSelezionato) {
          return offset;
        }
      }
    }
    return null;
  }

  Future<void> _checkNextTurnAlert() async {
    final n = nextMyTurnIn();
    if (n == null) return;

    // Play sound alert
    if (settings.soundAlert) {
      await sound.playDing();
    }
  }

  Future<void> saveSessione() async {
    if (_copione == null) return;
    final s = SessioneProva(
      copioneId: _copione!.id,
      personaggioSelezionato: _personaggioSelezionato ?? '',
      battutaCorrente: _battutaCorrente,
      isListening: _autoMode,  // Save auto mode state
    );
    await storage.saveSessione(s);
  }

  void jumpTo(int index) {
    if (_copione == null) return;
    if (index < 0 || index >= _copione!.battute.length) return;
    _battutaCorrente = index;
    
    if (_autoMode) {
      _startAutoTimer(); // Restart timer from new position
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    sound.dispose();
    super.dispose();
  }
}
