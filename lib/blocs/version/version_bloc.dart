import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/version/version_event.dart';
import 'package:doc_manager/blocs/version/version_state.dart';
import 'package:doc_manager/repository/version_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class VersionBloc extends Bloc<VersionEvent, VersionState> {
  final VersionRepository _versionRepository;

  VersionBloc({required VersionRepository versionRepository})
      : _versionRepository = versionRepository,
        super(const VersionInitial()) {
    on<LoadVersions>(_onLoadVersions);
    on<LoadVersion>(_onLoadVersion);
    on<CreateVersion>(_onCreateVersion);
  }

  Future<void> _onLoadVersions(LoadVersions event, Emitter<VersionState> emit) async {
    try {
      emit(const VersionsLoading());
      final versions = await _versionRepository.getVersions(event.documentId);
      emit(VersionsLoaded(versions));
    } catch (error) {
      LoggerUtil.error('Failed to load versions: $error');
      emit(VersionError('Failed to load versions: $error'));
    }
  }

  Future<void> _onLoadVersion(LoadVersion event, Emitter<VersionState> emit) async {
    try {
      emit(const VersionLoading());
      final version = await _versionRepository.getVersion(
        event.documentId, 
        event.versionId
      );
      emit(VersionLoaded(version));
    } catch (error) {
      LoggerUtil.error('Failed to load version: $error');
      emit(VersionError('Failed to load version: $error'));
    }
  }

  Future<void> _onCreateVersion(CreateVersion event, Emitter<VersionState> emit) async {
    try {
      emit(const VersionsLoading());
      final document = await _versionRepository.createVersion(
        event.documentId, 
        event.versionId
      );
      emit(VersionCreated(document));
      emit(const VersionOperationSuccess('Version created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create version: $error');
      emit(VersionError('Failed to create version: $error'));
    }
  }
} 