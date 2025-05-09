import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/user.dart';

abstract class UserState extends Equatable {
  const UserState();
  
  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {
  const UserInitial();
}

class UserLoading extends UserState {
  const UserLoading();
}

class UserLoaded extends UserState {
  final User user;
  
  const UserLoaded(this.user);
  
  @override
  List<Object?> get props => [user];
}

class UserCreated extends UserState {
  final User user;
  
  const UserCreated(this.user);
  
  @override
  List<Object?> get props => [user];
}

class UserUpdated extends UserState {
  final Map<String, dynamic> result;
  
  const UserUpdated(this.result);
  
  @override
  List<Object?> get props => [result];
}

class UserDeleted extends UserState {
  final Map<String, dynamic> result;
  
  const UserDeleted(this.result);
  
  @override
  List<Object?> get props => [result];
}

class UserOperationSuccess extends UserState {
  final String message;
  
  const UserOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class UserError extends UserState {
  final String error;
  
  const UserError(this.error);
  
  @override
  List<Object?> get props => [error];
} 