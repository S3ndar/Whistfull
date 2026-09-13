// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameAdapter extends TypeAdapter<Game> {
  @override
  final int typeId = 1;

  @override
  Game read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Game(
      id: fields[0] as String,
      dateStarted: fields[1] as DateTime,
      playerRefs: (fields[9] as List?)?.cast<GamePlayerRef>(),
      rounds: (fields[3] as List?)?.cast<Round>(),
      totalScores: (fields[4] as Map?)?.cast<String, int>(),
      pointMultiplier: fields[5] as int,
      scoringSnapshot: (fields[6] as Map?)?.cast<String, int>(),
      dateEnded: fields[7] as DateTime?,
      isComplete: fields[8] as bool,
    )..legacyPlayers = (fields[2] as List?)?.cast<Player>();
  }

  @override
  void write(BinaryWriter writer, Game obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dateStarted)
      ..writeByte(2)
      ..write(obj.legacyPlayers)
      ..writeByte(3)
      ..write(obj.rounds)
      ..writeByte(4)
      ..write(obj.totalScores)
      ..writeByte(5)
      ..write(obj.pointMultiplier)
      ..writeByte(6)
      ..write(obj.scoringSnapshot)
      ..writeByte(7)
      ..write(obj.dateEnded)
      ..writeByte(8)
      ..write(obj.isComplete)
      ..writeByte(9)
      ..write(obj.playerRefs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
