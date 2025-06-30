import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/user/user_event.dart';
import 'package:doc_manager/blocs/user/user_state.dart';
import 'package:doc_manager/models/user.dart';
import 'package:doc_manager/repository/user_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _userRepository;
  User? _currentUser;

  UserBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(const UserInitial()) {
    on<LoadUsers>(_onLoadUsers);
    on<GetCurrentUser>(_onGetCurrentUser);
    on<LoadUser>(_onLoadUser);
    on<CreateUser>(_onCreateUser);
    on<UpdateUser>(_onUpdateUser);
    on<UpdateUserPassword>(_onUpdateUserPassword);
    on<DeleteUser>(_onDeleteUser);
    on<ResetPassword>(_onResetPassword);
  }

  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserState> emit) async {
    try {
      emit(const UsersLoading());
      final users = await _userRepository.getUsers();
      emit(UsersLoaded(users));
    } catch (error) {
      LoggerUtil.error('Failed to load users: $error');
      emit(UserError('Failed to load users: $error'));
    }
  }

  Future<void> _onGetCurrentUser(GetCurrentUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final user = await _userRepository.getUser('current');
      emit(UserLoaded(user));
    } catch (error) {
      LoggerUtil.error('Failed to get current user: $error');
      emit(UserError('Failed to get current user: $error'));
    }
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

  Future<void> _onCreateUser(CreateUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final user = await _userRepository.createUser(
        event.firstName,
        event.lastName,
        event.email,
        event.password,
        event.password2,
        event.username,
      );
      emit(UserCreated(user));
      emit(const UserSuccess('User created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create user: $error');
      emit(UserError('Failed to create user: $error'));
    }
  }

  Future<void> _onUpdateUser(UpdateUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final updatedUser = await _userRepository.updateUser(event.user);
      _currentUser = updatedUser;
      emit(UserLoaded(updatedUser));
      emit(const UserSuccess('User updated successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to update user: $error');
      emit(UserError('Failed to update user: $error'));
    }
  }

  Future<void> _onUpdateUserPassword(UpdateUserPassword event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final result = await _userRepository.resetPassword(
        event.currentPassword,
        event.newPassword,
        event.confirmPassword,
      );
      emit(PasswordResetSuccess(result));
      emit(const UserSuccess('Password updated successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to update password: $error');
      emit(UserError('Failed to update password: $error'));
    }
  }

  Future<void> _onDeleteUser(DeleteUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final result = await _userRepository.deleteUser(event.id);
      emit(UserDeleted(result));
      emit(const UserSuccess('User deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete user: $error');
      emit(UserError('Failed to delete user: $error'));
    }
  }

  Future<void> _onResetPassword(ResetPassword event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final result = await _userRepository.resetPassword(
        event.currentPassword,
        event.newPassword,
        event.confirmPassword,
      );
      emit(PasswordResetSuccess(result));
      emit(const UserSuccess('Password reset successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to reset password: $error');
      emit(UserError('Failed to reset password: $error'));
    }
  }
} 