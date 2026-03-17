import 'package:hive/hive.dart';

part 'battuta.g.dart';

@HiveType(typeId: 1)
class Battuta extends HiveObject {
  @HiveField(0)
  int index;

  @HiveField(1)
  String personaggio;

  @HiveField(2)
  String testo;

  @HiveField(3)
  bool isCurrentUser;

  Battuta({
    required this.index,
    required this.personaggio,
    required this.testo,
    this.isCurrentUser = false,
  });

  Battuta copyWith({
    int? index,
    String? personaggio,
    String? testo,
    bool? isCurrentUser,
  }) {
    return Battuta(
      index: index ?? this.index,
      personaggio: personaggio ?? this.personaggio,
      testo: testo ?? this.testo,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  @override
  String toString() => '[$index] $personaggio: $testo';
}
