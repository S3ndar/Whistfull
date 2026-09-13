// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_player_ref.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GamePlayerRefAdapter extends TypeAdapter<GamePlayerRef> {
  @override
  final int typeId = 3;

  @override
  GamePlayerRef read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GamePlayerRef(
      id: fields[0] as String,
      name: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GamePlayerRef obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamePlayerRefAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
