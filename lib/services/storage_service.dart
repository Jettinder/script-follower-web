import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/copione.dart';
import '../models/battuta.dart';
import '../models/sessione_prova.dart';

class StorageService {
  static const copioniBoxName = 'copioni_box';
  static const sessioniBoxName = 'sessioni_box';

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(BattutaAdapter());
    Hive.registerAdapter(CopioneAdapter());
    Hive.registerAdapter(SessioneProvaAdapter());

    await Hive.openBox<Copione>(copioniBoxName);
    await Hive.openBox<SessioneProva>(sessioniBoxName);
  }

  Box<Copione> get copioniBox => Hive.box<Copione>(copioniBoxName);
  Box<SessioneProva> get sessioniBox => Hive.box<SessioneProva>(sessioniBoxName);

  Future<void> saveCopione(Copione c) async {
    await copioniBox.put(c.id, c);
  }

  Future<void> deleteCopione(String id) async {
    await copioniBox.delete(id);
  }

  List<Copione> listCopioni() {
    return copioniBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveSessione(SessioneProva s) async {
    await sessioniBox.put(s.copioneId, s);
  }

  SessioneProva? getSessione(String copioneId) {
    return sessioniBox.get(copioneId);
  }
}
