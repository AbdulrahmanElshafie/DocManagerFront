import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/shareable_link/shareable_link_event.dart';
import 'package:doc_manager/blocs/shareable_link/shareable_link_state.dart';
import 'package:doc_manager/repository/shareable_link_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class ShareableLinkBloc extends Bloc<ShareableLinkEvent, ShareableLinkState> {
  final ShareableLinkRepository _shareableLinkRepository;

  ShareableLinkBloc({required ShareableLinkRepository shareableLinkRepository})
      : _shareableLinkRepository = shareableLinkRepository,
        super(const ShareableLinkInitial()) {
    on<LoadShareableLinks>(_onLoadShareableLinks);
    on<LoadShareableLink>(_onLoadShareableLink);
    on<CreateShareableLink>(_onCreateShareableLink);
    on<UpdateShareableLink>(_onUpdateShareableLink);
    on<DeleteShareableLink>(_onDeleteShareableLink);
  }

  Future<void> _onLoadShareableLinks(LoadShareableLinks event, Emitter<ShareableLinkState> emit) async {
    try {
      emit(const ShareableLinksLoading());
      final links = await _shareableLinkRepository.getShareableLinks();
      emit(ShareableLinksLoaded(links));
    } catch (error) {
      LoggerUtil.error('Failed to load shareable links: $error');
      emit(ShareableLinkError('Failed to load shareable links: $error'));
    }
  }

  Future<void> _onLoadShareableLink(LoadShareableLink event, Emitter<ShareableLinkState> emit) async {
    try {
      emit(const ShareableLinkLoading());
      final link = await _shareableLinkRepository.getShareableLink(event.token);
      emit(ShareableLinkLoaded(link));
    } catch (error) {
      LoggerUtil.error('Failed to load shareable link: $error');
      emit(ShareableLinkError('Failed to load shareable link: $error'));
    }
  }

  Future<void> _onCreateShareableLink(CreateShareableLink event, Emitter<ShareableLinkState> emit) async {
    try {
      emit(const ShareableLinksLoading());
      final link = await _shareableLinkRepository.createShareableLink(
        event.documentId,
        event.expiresAt
      );
      emit(ShareableLinkCreated(link));
      emit(const ShareableLinkOperationSuccess('Shareable link created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create shareable link: $error');
      emit(ShareableLinkError('Failed to create shareable link: $error'));
    }
  }

  Future<void> _onUpdateShareableLink(UpdateShareableLink event, Emitter<ShareableLinkState> emit) async {
    try {
      emit(const ShareableLinksLoading());
      final result = await _shareableLinkRepository.updateShareableLink(
        event.id,
        event.documentId,
        event.expiresAt,
        event.isActive
      );
      emit(ShareableLinkUpdated(result));
      emit(const ShareableLinkOperationSuccess('Shareable link updated successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to update shareable link: $error');
      emit(ShareableLinkError('Failed to update shareable link: $error'));
    }
  }

  Future<void> _onDeleteShareableLink(DeleteShareableLink event, Emitter<ShareableLinkState> emit) async {
    try {
      emit(const ShareableLinksLoading());
      final result = await _shareableLinkRepository.deleteShareableLink(event.id);
      emit(ShareableLinkDeleted(result));
      emit(const ShareableLinkOperationSuccess('Shareable link deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete shareable link: $error');
      emit(ShareableLinkError('Failed to delete shareable link: $error'));
    }
  }
} 