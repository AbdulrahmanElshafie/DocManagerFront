import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/user/user_event.dart';
import 'package:doc_manager/blocs/user/user_state.dart';
import 'package:doc_manager/models/user.dart';
import 'package:doc_manager/repository/user_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';
import 'dart:developer' as developer;

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _userRepository;
  User? _currentUser;

  UserBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(const UserInitial()) {
    on<LoadUser>(_onLoadUser);
    on<GetCurrentUser>(_onGetCurrentUser);
    on<CreateUser>(_onCreateUser);
    on<UpdateUser>(_onUpdateUser);
    on<UpdateUserProfile>(_onUpdateUserProfile);
    on<UpdateUserPassword>(_onUpdateUserPassword);
    on<DeleteUser>(_onDeleteUser);
  }

  Future<void> _onLoadUser(LoadUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final user = await _userRepository.getUser(event.id);
      _currentUser = user;
      emit(UserLoaded(user));
    } catch (error) {
      LoggerUtil.error('Failed to load user: $error');
      emit(UserError('Failed to load user: $error'));
    }
  }

  Future<void> _onGetCurrentUser(GetCurrentUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      // Use empty string for current user - API will use auth token
      final user = await _userRepository.getUser("");
      _currentUser = user;
      emit(UserLoaded(user));
    } catch (error) {
      developer.log('Failed to get current user: $error', name: 'UserBloc');
      emit(UserError('Failed to get current user: $error'));
    }
  }

  Future<void> _onCreateUser(CreateUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final user = await _userRepository.createUser(
        event.firstName,
        event.lastName,
        event.email,
        event.password,
        event.password2,
        event.username
      );
      emit(UserCreated(user));
      emit(const UserOperationSuccess('User created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create user: $error');
      emit(UserError('Failed to create user: $error'));
    }
  }

  Future<void> _onUpdateUserProfile(UpdateUserProfile event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      
      if (_currentUser == null) {
        throw Exception("No current user available");
      }
      
      // Create updated user object with the new profile data
      final updatedUser = _currentUser!.copyWith(
        firstName: event.firstName ?? _currentUser!.firstName,
        lastName: event.lastName ?? _currentUser!.lastName,
        email: event.email ?? _currentUser!.email,
        username: event.username ?? _currentUser!.username,
      );
      
      final user = await _userRepository.updateUser(updatedUser);
      _currentUser = user;
      
      emit(UserUpdated({'user': user.toJson()}));
      emit(const UserOperationSuccess('Profile updated successfully'));
    } catch (error) {
      developer.log('Failed to update user profile: $error', name: 'UserBloc');
      emit(UserError('Failed to update profile: $error'));
    }
  }

  Future<void> _onUpdateUserPassword(UpdateUserPassword event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());

      // Validate passwords match
      if (event.newPassword != event.confirmPassword) {
        throw Exception("New password and confirmation do not match");
      }
      
      // Call the password reset API
      await _userRepository.resetPassword(
        event.currentPassword, 
        event.newPassword, 
        event.confirmPassword
      );
      
      emit(const UserOperationSuccess('Password updated successfully'));
    } catch (error) {
      developer.log('Failed to update password: $error', name: 'UserBloc');
      emit(UserError('Failed to update password: $error'));
    }
  }

  Future<void> _onUpdateUser(UpdateUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      
      // This is for backward compatibility with existing code
      if (_currentUser == null) {
        throw Exception("No current user available");
      }
      
      // Create a user object from the current user with updated name
      final userToUpdate = _currentUser!.copyWith(
        firstName: event.name,
        lastName: _currentUser!.lastName,
      );
      
      final updatedUser = await _userRepository.updateUser(userToUpdate);
      _currentUser = updatedUser;
      
      emit(UserUpdated({'user': updatedUser.toJson()}));
      emit(const UserOperationSuccess('User updated successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to update user: $error');
      emit(UserError('Failed to update user: $error'));
    }
  }

  Future<void> _onDeleteUser(DeleteUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final result = await _userRepository.deleteUser(event.id);
      emit(UserDeleted(result));
      emit(const UserOperationSuccess('User deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete user: $error');
      emit(UserError('Failed to delete user: $error'));
    }
  }
} 