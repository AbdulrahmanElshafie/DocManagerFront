import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/user.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadUser extends UserEvent {
  final String id;
  
  const LoadUser(this.id);
  
  @override
  List<Object?> get props => [id];
}

class LoadUsers extends UserEvent {
  const LoadUsers();
}

class GetCurrentUser extends UserEvent {
  const GetCurrentUser();
}

class CreateUser extends UserEvent {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String password2;
  final String username;
  
  const CreateUser({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.password2,
    required this.username,
  });
  
  @override
  List<Object?> get props => [firstName, lastName, email, username, password, password2];
}

class UpdateUserProfile extends UserEvent {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? username;
  
  const UpdateUserProfile({
    this.firstName,
    this.lastName,
    this.email,
    this.username,
  });
  
  @override
  List<Object?> get props => [firstName, lastName, email, username];
}

class UpdateUserPassword extends UserEvent {
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
  
  const UpdateUserPassword({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });
  
  @override
  List<Object?> get props => [currentPassword, newPassword, confirmPassword];
}

class UpdateUser extends UserEvent {
  final User user;
  
  const UpdateUser(this.user);
  
  @override
  List<Object?> get props => [user];
}

class ResetPassword extends UserEvent {
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
  
  const ResetPassword({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });
  
  @override
  List<Object?> get props => [currentPassword, newPassword, confirmPassword];
}

class DeleteUser extends UserEvent {
  final String id;
  
  const DeleteUser(this.id);
  
  @override
  List<Object?> get props => [id];
} 