// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copione.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CopioneAdapter extends TypeAdapter<Copione> {
  @override
  final int typeId = 2;

  @override
  Copione read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Copione(
      id: fields[0] as String,
      titolo: fields[1] as String,
      personaggi: (fields[2] as List).cast<String>(),
      battute: (fields[3] as List).cast<Battuta>(),
      createdAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Copione obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.titolo)
      ..writeByte(2)
      ..write(obj.personaggi)
      ..writeByte(3)
      ..write(obj.battute)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CopioneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
