import 'package:hive/hive.dart';

part 'round.g.dart';

@HiveType(typeId: 2)
class Round extends HiveObject {
  @HiveField(0)
  late String contractType;

  @HiveField(1)
  late String declarerId;

  @HiveField(2)
  late String? partnerId;

  @HiveField(3)
  late int tricksWon;

  @HiveField(4)
  late Map<String, int> scoreDeltas;

  @HiveField(5)
  late bool success;

  @HiveField(6)
  String? dealerId; // Nullable to handle migration from old rounds

  @HiveField(7)
  int? agreedTricks; // Nullable to handle migration from old rounds

  @HiveField(8)
  String? trump;

  @HiveField(9)
  int multiplier;

  Round({
    required this.contractType,
    required this.declarerId,
    this.partnerId,
    required this.tricksWon,
    required this.scoreDeltas,
    required this.success,
    this.dealerId,
    this.agreedTricks = 0,
    this.trump,
    this.multiplier = 1,
  });
}
