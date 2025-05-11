import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/shareable_link.dart';

abstract class ShareableLinkState extends Equatable {
  const ShareableLinkState();
  
  @override
  List<Object?> get props => [];
}

class ShareableLinkInitial extends ShareableLinkState {
  const ShareableLinkInitial();
}

class ShareableLinksLoading extends ShareableLinkState {
  const ShareableLinksLoading();
}

class ShareableLinkLoading extends ShareableLinkState {
  const ShareableLinkLoading();
}

class ShareableLinksLoaded extends ShareableLinkState {
  final List<ShareableLink> links;
  
  const ShareableLinksLoaded(this.links);
  
  @override
  List<Object?> get props => [links];
}

class ShareableLinkLoaded extends ShareableLinkState {
  final ShareableLink link;
  
  const ShareableLinkLoaded(this.link);
  
  @override
  List<Object?> get props => [link];
}

class ShareableLinkCreated extends ShareableLinkState {
  final ShareableLink link;
  
  const ShareableLinkCreated(this.link);
  
  @override
  List<Object?> get props => [link];
}

class ShareableLinkUpdated extends ShareableLinkState {
  final Map<String, dynamic> result;
  
  const ShareableLinkUpdated(this.result);
  
  @override
  List<Object?> get props => [result];
}

class ShareableLinkDeleted extends ShareableLinkState {
  final Map<String, dynamic> result;
  
  const ShareableLinkDeleted(this.result);
  
  @override
  List<Object?> get props => [result];
}

class ShareableLinkOperationSuccess extends ShareableLinkState {
  final String message;
  
  const ShareableLinkOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class ShareableLinkSuccess extends ShareableLinkState {
  final String message;
  
  const ShareableLinkSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class ShareableLinkError extends ShareableLinkState {
  final String error;
  
  const ShareableLinkError(this.error);
  
  @override
  List<Object?> get props => [error];
} 