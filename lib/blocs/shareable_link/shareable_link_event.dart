import 'package:equatable/equatable.dart';

abstract class ShareableLinkEvent extends Equatable {
  const ShareableLinkEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadShareableLinks extends ShareableLinkEvent {
  const LoadShareableLinks();
}

class GetShareableLinks extends ShareableLinkEvent {
  final String resourceId;
  
  const GetShareableLinks({required this.resourceId});
  
  @override
  List<Object?> get props => [resourceId];
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
  final String? resourceId;
  final String? permissionType;
  
  const CreateShareableLink({
    this.documentId,
    this.expiresAt,
    this.resourceId,
    this.permissionType,
  });
  
  @override
  List<Object?> get props => [documentId, expiresAt, resourceId, permissionType];
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
  
  const DeleteShareableLink({required this.id});
  
  @override
  List<Object?> get props => [id];
} 