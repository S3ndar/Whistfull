import 'package:hive/hive.dart';

part 'player.g.dart'; // Required for Hive generator

@HiveType(typeId: 0)
class Player extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late int gamesPlayed;

  @HiveField(3)
  late bool isFavorite;

  Player({
    required this.id,
    required this.name,
    this.gamesPlayed = 0,
    this.isFavorite = false,
  });
}
