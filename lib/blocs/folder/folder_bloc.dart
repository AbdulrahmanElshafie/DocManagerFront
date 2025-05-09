import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/folder/folder_event.dart';
import 'package:doc_manager/blocs/folder/folder_state.dart';
import 'package:doc_manager/repository/folder_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class FolderBloc extends Bloc<FolderEvent, FolderState> {
  final FolderRepository _folderRepository;

  FolderBloc({required FolderRepository folderRepository})
      : _folderRepository = folderRepository,
        super(const FolderInitial()) {
    on<LoadFolders>(_onLoadFolders);
    on<LoadFolder>(_onLoadFolder);
    on<CreateFolder>(_onCreateFolder);
    on<UpdateFolder>(_onUpdateFolder);
    on<DeleteFolder>(_onDeleteFolder);
  }

  Future<void> _onLoadFolders(LoadFolders event, Emitter<FolderState> emit) async {
    try {
      emit(const FoldersLoading());
      final folders = await _folderRepository.getFolders();
      emit(FoldersLoaded(folders));
    } catch (error) {
      LoggerUtil.error('Failed to load folders: $error');
      emit(FolderError('Failed to load folders: $error'));
    }
  }

  Future<void> _onLoadFolder(LoadFolder event, Emitter<FolderState> emit) async {
    try {
      emit(const FolderLoading());
      final folder = await _folderRepository.getFolder(event.id);
      emit(FolderLoaded(folder));
    } catch (error) {
      LoggerUtil.error('Failed to load folder: $error');
      emit(FolderError('Failed to load folder: $error'));
    }
  }

  Future<void> _onCreateFolder(CreateFolder event, Emitter<FolderState> emit) async {
    try {
      emit(const FoldersLoading());
      final folder = await _folderRepository.createFolder(
        event.parentId, 
        event.name
      );
      emit(FolderCreated(folder));
      emit(const FolderOperationSuccess('Folder created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create folder: $error');
      emit(FolderError('Failed to create folder: $error'));
    }
  }

  Future<void> _onUpdateFolder(UpdateFolder event, Emitter<FolderState> emit) async {
    try {
      emit(const FoldersLoading());
      final result = await _folderRepository.updateFolder(
        event.id,
        event.parentId,
        event.name
      );
      emit(FolderUpdated(result));
      emit(const FolderOperationSuccess('Folder updated successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to update folder: $error');
      emit(FolderError('Failed to update folder: $error'));
    }
  }

  Future<void> _onDeleteFolder(DeleteFolder event, Emitter<FolderState> emit) async {
    try {
      emit(const FoldersLoading());
      final result = await _folderRepository.deleteFolder(event.id);
      emit(FolderDeleted(result));
      emit(const FolderOperationSuccess('Folder deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete folder: $error');
      emit(FolderError('Failed to delete folder: $error'));
    }
  }
} 