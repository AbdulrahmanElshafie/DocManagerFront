# DocManager - Flutter Frontend

A comprehensive document management application built with Flutter, featuring advanced document viewing, organization, and collaboration tools.

## 📋 Overview

DocManager is a cross-platform document management system that allows users to upload, organize, view, and share documents seamlessly. The app provides native-like experiences across Android, iOS, Web, and Desktop platforms with robust document viewing capabilities and intuitive folder organization.

## ✨ Features

### 🔐 Authentication & User Management
- User registration and login
- Profile management with personal information updates
- Password reset functionality
- Secure token-based authentication

### 📁 Document Management
- **Upload & Storage**: Support for PDF, CSV, and DOCX files
- **Folder Organization**: Hierarchical folder structure with create/rename/delete operations
- **Document Operations**: View, edit, delete, and move documents between folders
- **File Validation**: Automatic file type detection and validation
- **Cross-platform File Handling**: Optimized for web and mobile platforms

### 📊 Advanced Document Viewers

#### CSV Viewer
- **Interactive Spreadsheet**: Full-featured table with drag-to-resize columns and rows
- **Virtualized Rendering**: Optimized performance for large datasets
- **Pagination Controls**: Customizable rows per page (5-300 rows)
- **Search & Filter**: Quick data location within large CSV files
- **Export Options**: Download and share CSV data

#### PDF Viewer
- **Native PDF Rendering**: High-quality document display
- **Interactive Controls**: Zoom in/out, page navigation, search functionality
- **Text Selection**: Copy text directly from PDF documents
- **Toolbar Features**: Quick access to common PDF operations

#### DOCX Viewer
- **Platform-Adaptive**: Native viewing on mobile/desktop, browser fallback on web
- **Document Integrity**: Maintains original formatting and layout
- **External Integration**: Option to open in system default applications

### 🔗 Sharing & Collaboration
- **Shareable Links**: Generate time-limited links for document access
- **Permission Management**: Control access levels for shared documents
- **Activity Logging**: Track document access and modifications
- **User Activity Tracking**: Monitor document usage patterns

### 🎨 User Experience
- **Responsive Design**: Adaptive layouts for all screen sizes
- **Theme Support**: Light and dark mode with smooth transitions
- **Intuitive Navigation**: Clean, modern interface with logical workflows
- **Error Handling**: Comprehensive error messages and recovery options
- **Loading States**: Visual feedback during operations

### 🏗️ Technical Architecture
- **BLoC Pattern**: Predictable state management with flutter_bloc
- **Repository Pattern**: Clean separation of data access logic
- **Dependency Injection**: Centralized service management with Provider
- **Cross-platform Compatibility**: Single codebase for multiple platforms
- **Background Processing**: Compute-intensive operations moved to background threads

## 🚀 Future Updates

### 💬 Comments System
- **Document Comments**: Add threaded comments to any document
- **Real-time Collaboration**: Live comment updates and notifications
- **User Mentions**: Tag specific users in comments
- **Comment Resolution**: Mark comments as resolved or pending

### 📚 Version Management
- **Document History**: Track all document modifications
- **Version Comparison**: Visual diff between document versions
- **Rollback Capability**: Restore previous versions of documents
- **Change Annotations**: Add notes to version changes

### 📝 Enhanced DOCX Support
- **In-app Editing**: Native DOCX editing capabilities
- **Real-time Preview**: Live preview during document editing
- **Formatting Tools**: Rich text editing with formatting options
- **Collaborative Editing**: Multiple users editing simultaneously

### 🔄 Additional Features
- **Bulk Operations**: Multi-select documents for batch actions
- **Advanced Search**: Full-text search across all documents
- **Offline Support**: Local caching for offline document access
- **Integration APIs**: Third-party application integrations

## 📦 Dependencies

### Core Framework
- **flutter**: Cross-platform UI toolkit
- **flutter_bloc**: State management library
- **provider**: Dependency injection and state management
- **equatable**: Value equality for Dart objects

### Network & Data
- **http**: HTTP client for API communication
- **path_provider**: File system path access
- **csv**: CSV parsing and manipulation
- **path**: File path manipulation utilities

### Document Viewers
- **syncfusion_flutter_pdfviewer**: Professional PDF viewing
- **docx_viewer**: Microsoft Word document viewer
- **data_table_2**: Advanced data table with features
- **url_launcher**: External URL and app launching

### UI & UX
- **intl**: Internationalization and localization
- **cupertino_icons**: iOS-style icons
- **flutter_svg**: SVG image support (if used)

### Platform Integration
- **flutter_web_plugins**: Web platform integration
- **flutter_localizations**: Localization support

## 🛠️ Development Setup

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK (included with Flutter)
- Platform-specific tools:
  - Android Studio/VS Code with Flutter extensions
  - Xcode (for iOS development)
  - Chrome (for web development)

### Installation
1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure backend API endpoints in `lib/shared/network/api.dart`
4. Run the application:
   ```bash
   flutter run
   ```

## 🔗 Backend Integration

**Backend Repository**: [DocManager Backend](https://github.com/AbdulrahmanElshafie/DocManager)

The frontend communicates with a Django REST API backend. Ensure the backend is running and accessible before using the app.

### API Configuration
Update the base URL in `lib/shared/network/api.dart`:
```dart
class API {
  static const String baseUrl = 'YOUR_BACKEND_URL_HERE';
  // ... rest of the configuration
}
```

## 🏗️ Architecture Overview

```
lib/
├── blocs/           # Business Logic Components
├── models/          # Data models
├── repository/      # Data access layer
├── screens/         # UI screens
├── widgets/         # Reusable widgets
├── shared/          # Shared utilities and services
└── main.dart        # Application entry point
```

## 📱 Platform Support

- ✅ **Android**: Native performance with platform-specific optimizations
- ✅ **iOS**: Native iOS experience with Cupertino design elements
- ✅ **Web**: Progressive Web App with responsive design
- ✅ **Desktop**: Windows, macOS, and Linux support

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation for common solutions

---

**Built with ❤️ using Flutter**
