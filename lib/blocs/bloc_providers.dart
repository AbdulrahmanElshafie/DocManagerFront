import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  static List<BlocProvider> providers = [
    BlocProvider<DocumentBloc>(
      create: (context) => DocumentBloc(
        documentRepository: DocumentRepository(),
      ),
    ),
    BlocProvider<UserBloc>(
      create: (context) => UserBloc(
        userRepository: UserRepository(),
      ),
    ),
    BlocProvider<FolderBloc>(
      create: (context) => FolderBloc(
        folderRepository: FolderRepository(),
      ),
    ),
    BlocProvider<PermissionBloc>(
      create: (context) => PermissionBloc(
        permissionRepository: PermissionRepository(),
      ),
    ),
    BlocProvider<VersionBloc>(
      create: (context) => VersionBloc(
        versionRepository: VersionRepository(),
      ),
    ),
    BlocProvider<CommentBloc>(
      create: (context) => CommentBloc(
        commentRepository: CommentRepository(),
      ),
    ),
    BlocProvider<ShareableLinkBloc>(
      create: (context) => ShareableLinkBloc(
        shareableLinkRepository: ShareableLinkRepository(),
      ),
    ),
    BlocProvider<BackupBloc>(
      create: (context) => BackupBloc(
        backupRepository: BackupRepository(),
      ),
    ),
  ];
} 