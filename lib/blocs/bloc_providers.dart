import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Import repositories
import 'package:doc_manager/repository/document_repository.dart';
import 'package:doc_manager/repository/user_repository.dart';
import 'package:doc_manager/repository/folder_repository.dart';
import 'package:doc_manager/repository/permission_repository.dart';
import 'package:doc_manager/repository/version_repository.dart';
import 'package:doc_manager/repository/comment_repository.dart';
import 'package:doc_manager/repository/shareable_link_repository.dart';
import 'package:doc_manager/repository/backup_repository.dart';

// Import blocs
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/user/user_bloc.dart';
import 'package:doc_manager/blocs/folder/folder_bloc.dart';
import 'package:doc_manager/blocs/permission/permission_bloc.dart';
import 'package:doc_manager/blocs/version/version_bloc.dart';
import 'package:doc_manager/blocs/comment/comment_bloc.dart';
import 'package:doc_manager/blocs/shareable_link/shareable_link_bloc.dart';
import 'package:doc_manager/blocs/backup/backup_bloc.dart';

class AppBlocProviders {
  static List<SingleChildWidget> get repositoryProviders {
    return [
      Provider<DocumentRepository>(
        create: (_) => DocumentRepository(),
      ),
      Provider<UserRepository>(
        create: (_) => UserRepository(),
      ),
      Provider<FolderRepository>(
        create: (_) => FolderRepository(),
      ),
      Provider<PermissionRepository>(
        create: (_) => PermissionRepository(),
      ),
      Provider<VersionRepository>(
        create: (_) => VersionRepository(),
      ),
      Provider<CommentRepository>(
        create: (_) => CommentRepository(),
      ),
      Provider<ShareableLinkRepository>(
        create: (_) => ShareableLinkRepository(),
      ),
      Provider<BackupRepository>(
        create: (_) => BackupRepository(),
      ),
    ];
  }

  static List<SingleChildWidget> get blocProviders {
    return [
      BlocProvider<DocumentBloc>(
        create: (context) => DocumentBloc(
          documentRepository: context.read<DocumentRepository>(),
        ),
      ),
      BlocProvider<UserBloc>(
        create: (context) => UserBloc(
          userRepository: context.read<UserRepository>(),
        ),
      ),
      BlocProvider<FolderBloc>(
        create: (context) => FolderBloc(
          folderRepository: context.read<FolderRepository>(),
        ),
      ),
      BlocProvider<PermissionBloc>(
        create: (context) => PermissionBloc(
          permissionRepository: context.read<PermissionRepository>(),
        ),
      ),
      BlocProvider<VersionBloc>(
        create: (context) => VersionBloc(
          versionRepository: context.read<VersionRepository>(),
        ),
      ),
      BlocProvider<CommentBloc>(
        create: (context) => CommentBloc(
          commentRepository: context.read<CommentRepository>(),
        ),
      ),
      BlocProvider<ShareableLinkBloc>(
        create: (context) => ShareableLinkBloc(
          shareableLinkRepository: context.read<ShareableLinkRepository>(),
        ),
      ),
      BlocProvider<BackupBloc>(
        create: (context) => BackupBloc(
          backupRepository: context.read<BackupRepository>(),
        ),
      ),
    ];
  }
  
  static List<SingleChildWidget> get providers {
    return [...repositoryProviders, ...blocProviders];
  }
} 