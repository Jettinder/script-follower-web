// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessione_prova.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessioneProvaAdapter extends TypeAdapter<SessioneProva> {
  @override
  final int typeId = 3;

  @override
  SessioneProva read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessioneProva(
      copioneId: fields[0] as String,
      personaggioSelezionato: fields[1] as String,
      battutaCorrente: fields[2] as int,
      isListening: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SessioneProva obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.copioneId)
      ..writeByte(1)
      ..write(obj.personaggioSelezionato)
      ..writeByte(2)
      ..write(obj.battutaCorrente)
      ..writeByte(3)
      ..write(obj.isListening);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessioneProvaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
