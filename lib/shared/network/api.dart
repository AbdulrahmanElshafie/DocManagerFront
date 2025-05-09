

class API {
  // Base URL for the API
  static const String baseUrl = 'https://api.example.com'; // TODO: Replace with actual base URL

  // Auth Endpoints
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String logout = '/auth/logout/';
  static const String refreshToken = '/auth/token/refresh/';
  static const String passwordReset = '/auth/password-reset/';

  // User Endpoints
  static const String userProfile = '/auth//user/';
  static const String updateProfile = '/auth//user/update';
  
  // Document Endpoints
  static const String document = '/manager/document/';
  // Folder Endpoints
  static const String folder = '/manager/folder/';
  // Backup Endpoints
  static const String backups = '/backups/backup/';
  // Permission Endpoints
  static const String permission = '/manager/permission/';
  // Share Endpoints
  static const String shareByToken = '/manager/share/';
  // Workflow Endpoints
  static const String workflows = '/workflows/template/';
  // Document Revision Endpoints
  static const String documentRevisions = '/manager/document/revision/';
  // comment Endpoints
  static const String comments = '/manager/comment/';


}