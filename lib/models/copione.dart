import 'package:hive/hive.dart';
import 'battuta.dart';

part 'copione.g.dart';

@HiveType(typeId: 2)
class Copione extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String titolo;

  @HiveField(2)
  List<String> personaggi;

  @HiveField(3)
  List<Battuta> battute;

  @HiveField(4)
  DateTime createdAt;

  Copione({
    required this.id,
    required this.titolo,
    required this.personaggi,
    required this.battute,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Copione copyWith({
    String? id,
    String? titolo,
    List<String>? personaggi,
    List<Battuta>? battute,
    DateTime? createdAt,
  }) {
    return Copione(
      id: id ?? this.id,
      titolo: titolo ?? this.titolo,
      personaggi: personaggi ?? this.personaggi,
      battute: battute ?? this.battute,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
