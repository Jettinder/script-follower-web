import 'package:hive/hive.dart';

part 'sessione_prova.g.dart';

@HiveType(typeId: 3)
class SessioneProva extends HiveObject {
  @HiveField(0)
  String copioneId;

  @HiveField(1)
  String personaggioSelezionato;

  @HiveField(2)
  int battutaCorrente;

  @HiveField(3)
  bool isListening;

  SessioneProva({
    required this.copioneId,
    required this.personaggioSelezionato,
    this.battutaCorrente = 0,
    this.isListening = false,
  });

  SessioneProva copyWith({
    String? copioneId,
    String? personaggioSelezionato,
    int? battutaCorrente,
    bool? isListening,
  }) {
    return SessioneProva(
      copioneId: copioneId ?? this.copioneId,
      personaggioSelezionato:
          personaggioSelezionato ?? this.personaggioSelezionato,
      battutaCorrente: battutaCorrente ?? this.battutaCorrente,
      isListening: isListening ?? this.isListening,
    );
  }
}
