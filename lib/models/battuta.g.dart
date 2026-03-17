// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'battuta.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BattutaAdapter extends TypeAdapter<Battuta> {
  @override
  final int typeId = 1;

  @override
  Battuta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Battuta(
      index: fields[0] as int,
      personaggio: fields[1] as String,
      testo: fields[2] as String,
      isCurrentUser: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Battuta obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.index)
      ..writeByte(1)
      ..write(obj.personaggio)
      ..writeByte(2)
      ..write(obj.testo)
      ..writeByte(3)
      ..write(obj.isCurrentUser);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BattutaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
