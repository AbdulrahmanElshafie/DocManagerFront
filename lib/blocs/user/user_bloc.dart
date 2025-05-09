import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/user/user_event.dart';
import 'package:doc_manager/blocs/user/user_state.dart';
import 'package:doc_manager/repository/user_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _userRepository;

  UserBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(const UserInitial()) {
    on<LoadUser>(_onLoadUser);
    on<CreateUser>(_onCreateUser);
    on<UpdateUser>(_onUpdateUser);
    on<DeleteUser>(_onDeleteUser);
  }

  Future<void> _onLoadUser(LoadUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final user = await _userRepository.getUser(event.id);
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
        event.username
      );
      emit(UserCreated(user));
      emit(const UserOperationSuccess('User created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create user: $error');
      emit(UserError('Failed to create user: $error'));
    }
  }

  Future<void> _onUpdateUser(UpdateUser event, Emitter<UserState> emit) async {
    try {
      emit(const UserLoading());
      final result = await _userRepository.updateUser(
        event.id,
        event.parentId,
        event.name
      );
      emit(UserUpdated(result));
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