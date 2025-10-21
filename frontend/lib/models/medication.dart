import 'package:flutter/material.dart';

class Medication {
  final String id;
  final String name;
  final TimeOfDay time;
  final bool isTaken;

  Medication({
    required this.id,
    required this.name,
    required this.time,
    this.isTaken = false,
  });

  String get formattedTime =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Medication copyWith({bool? isTaken}) {
    return Medication(
      id: id,
      name: name,
      time: time,
      isTaken: isTaken ?? this.isTaken,
    );
  }
}
