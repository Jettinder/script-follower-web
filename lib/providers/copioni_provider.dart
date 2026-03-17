import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/battuta.dart';
import '../models/copione.dart';
import '../services/parser_service.dart';
import '../services/storage_service.dart';

class CopioniProvider extends ChangeNotifier {
  final StorageService storage;
  final ParserService parser;

  CopioniProvider({
    required this.storage,
    required this.parser,
  });

  List<Copione> _copioni = [];
  List<Copione> get copioni => _filteredQuery?.isNotEmpty == true ? _filtered : _copioni;

  String? _filteredQuery;
  List<Copione> _filtered = [];

  Future<void> load() async {
    _copioni = storage.listCopioni();
    _applyFilter();
    notifyListeners();
  }

  void search(String query) {
    _filteredQuery = query.trim();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_filteredQuery == null || _filteredQuery!.isEmpty) {
      _filtered = _copioni;
      return;
    }
    final q = _filteredQuery!.toLowerCase();
    _filtered = _copioni.where((c) {
      if (c.titolo.toLowerCase().contains(q)) return true;
      return c.personaggi.any((p) => p.toLowerCase().contains(q));
    }).toList();
  }

  Future<Copione> importFromText({
    required String titolo,
    required String raw,
  }) async {
    final id = _generateId();
    final copione = parser.parseFromText(id: id, titolo: titolo, raw: raw);
    await storage.saveCopione(copione);
    await load();
    return copione;
  }

  /// Import a pre-parsed copione with selected characters and battute
  Future<Copione> importParsedCopione({
    required String titolo,
    required List<String> personaggi,
    required List<Battuta> battute,
  }) async {
    final id = _generateId();
    final copione = Copione(
      id: id,
      titolo: titolo,
      personaggi: personaggi..sort(),
      battute: battute,
    );
    await storage.saveCopione(copione);
    await load();
    return copione;
  }

  Future<void> deleteCopione(String id) async {
    await storage.deleteCopione(id);
    await load();
  }

  String _generateId() {
    final r = Random();
    return 'cop_${DateTime.now().millisecondsSinceEpoch}_${r.nextInt(1 << 32)}';
  }
}
