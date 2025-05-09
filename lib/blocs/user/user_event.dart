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

class UpdateUser extends UserEvent {
  final String id;
  final String parentId;
  final String name;
  
  const UpdateUser({
    required this.id,
    required this.parentId,
    required this.name
  });
  
  @override
  List<Object?> get props => [id, parentId, name];
}

class DeleteUser extends UserEvent {
  final String id;
  
  const DeleteUser(this.id);
  
  @override
  List<Object?> get props => [id];
} 