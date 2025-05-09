import 'package:equatable/equatable.dart';

class Backup extends Equatable {
  final String id;
  final DateTime createdAt;

  const Backup({
    required this.id,
    required this.createdAt,
  });

  factory Backup.fromJson(Map<String, dynamic> json) => Backup(
      id: json['id'],
      createdAt: DateTime.parse(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
  };

  Backup copyWith({
    String? id,
    DateTime? createdAt,
  }) {
    return Backup(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    createdAt,
  ];
}