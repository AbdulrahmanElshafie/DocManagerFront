import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final DateTime? dateJoined;
  final bool isActive;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.dateJoined,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      dateJoined: json['date_joined'] != null ? DateTime.parse(json['date_joined']) : null,
      isActive: json['is_active'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'date_joined': dateJoined?.toIso8601String(),
    'is_active': isActive,
  };

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    DateTime? dateJoined,
    bool? isActive
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateJoined: dateJoined ?? this.dateJoined,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        firstName,
        lastName,
        dateJoined,
        isActive,
      ];
}

// class UserSettings extends Equatable {
//   final bool autoSync;
//   final bool compressFiles;
//   final int maxStorageGB;
//   final bool emailNotifications;
//   final bool pushNotifications;
//   final bool documentUpdates;
//   final bool sharingNotifications;
//
//   const UserSettings({
//     this.autoSync = true,
//     this.compressFiles = false,
//     this.maxStorageGB = 5,
//     this.emailNotifications = true,
//     this.pushNotifications = true,
//     this.documentUpdates = true,
//     this.sharingNotifications = true,
//   });
//
//   UserSettings copyWith({
//     bool? autoSync,
//     bool? compressFiles,
//     int? maxStorageGB,
//     bool? emailNotifications,
//     bool? pushNotifications,
//     bool? documentUpdates,
//     bool? sharingNotifications,
//   }) {
//     return UserSettings(
//       autoSync: autoSync ?? this.autoSync,
//       compressFiles: compressFiles ?? this.compressFiles,
//       maxStorageGB: maxStorageGB ?? this.maxStorageGB,
//       emailNotifications: emailNotifications ?? this.emailNotifications,
//       pushNotifications: pushNotifications ?? this.pushNotifications,
//       documentUpdates: documentUpdates ?? this.documentUpdates,
//       sharingNotifications: sharingNotifications ?? this.sharingNotifications,
//     );
//   }
//
//   @override
//   List<Object?> get props => [
//         autoSync,
//         compressFiles,
//         maxStorageGB,
//         emailNotifications,
//         pushNotifications,
//         documentUpdates,
//         sharingNotifications,
//       ];
// }