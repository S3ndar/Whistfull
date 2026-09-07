// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'round.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoundAdapter extends TypeAdapter<Round> {
  @override
  final int typeId = 2;

  @override
  Round read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Round(
      contractType: fields[0] as String,
      declarerId: fields[1] as String,
      partnerId: fields[2] as String?,
      tricksWon: fields[3] as int,
      scoreDeltas: (fields[4] as Map).cast<String, int>(),
      success: fields[5] as bool,
      dealerId: fields[6] as String?,
      agreedTricks: fields[7] as int?,
      trump: fields[8] as String?,
      multiplier: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Round obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.contractType)
      ..writeByte(1)
      ..write(obj.declarerId)
      ..writeByte(2)
      ..write(obj.partnerId)
      ..writeByte(3)
      ..write(obj.tricksWon)
      ..writeByte(4)
      ..write(obj.scoreDeltas)
      ..writeByte(5)
      ..write(obj.success)
      ..writeByte(6)
      ..write(obj.dealerId)
      ..writeByte(7)
      ..write(obj.agreedTricks)
      ..writeByte(8)
      ..write(obj.trump)
      ..writeByte(9)
      ..write(obj.multiplier);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoundAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
