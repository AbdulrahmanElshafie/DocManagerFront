import 'package:equatable/equatable.dart';

abstract class VersionEvent extends Equatable {
  const VersionEvent();
  
  @override
  List<Object?> get props => [];
}

class GetVersions extends VersionEvent {
  final String documentId;
  
  const GetVersions({required this.documentId});
  
  @override
  List<Object?> get props => [documentId];
}

class LoadVersions extends VersionEvent {
  final String documentId;
  
  const LoadVersions(this.documentId);
  
  @override
  List<Object?> get props => [documentId];
}

class LoadVersion extends VersionEvent {
  final String documentId;
  final String versionId;
  
  const LoadVersion({
    required this.documentId,
    required this.versionId,
  });
  
  @override
  List<Object?> get props => [documentId, versionId];
}

class CreateVersion extends VersionEvent {
  final String documentId;
  final String versionId;
  final String? comment;
  
  const CreateVersion({
    required this.documentId,
    required this.versionId,
    this.comment,
  });
  
  @override
  List<Object?> get props => [documentId, versionId, comment];
} 