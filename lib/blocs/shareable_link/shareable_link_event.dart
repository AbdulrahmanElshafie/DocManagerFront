import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/shareable_link.dart';

abstract class ShareableLinkEvent extends Equatable {
  const ShareableLinkEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadShareableLinks extends ShareableLinkEvent {
  const LoadShareableLinks();
}

class LoadShareableLink extends ShareableLinkEvent {
  final String token;
  
  const LoadShareableLink(this.token);
  
  @override
  List<Object?> get props => [token];
}

class CreateShareableLink extends ShareableLinkEvent {
  final String? documentId;
  final DateTime? expiresAt;
  
  const CreateShareableLink({
    this.documentId,
    this.expiresAt
  });
  
  @override
  List<Object?> get props => [documentId, expiresAt];
}

class UpdateShareableLink extends ShareableLinkEvent {
  final String id;
  final String? documentId;
  final DateTime? expiresAt;
  final bool? isActive;
  
  const UpdateShareableLink({
    required this.id,
    this.documentId,
    this.expiresAt,
    this.isActive
  });
  
  @override
  List<Object?> get props => [id, documentId, expiresAt, isActive];
}

class DeleteShareableLink extends ShareableLinkEvent {
  final String id;
  
  const DeleteShareableLink(this.id);
  
  @override
  List<Object?> get props => [id];
} 