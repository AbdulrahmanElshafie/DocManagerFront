# Document Manager

A Flutter document management application with BLoC state management.

## Architecture

This project follows a clean architecture approach with the following components:

- **Models**: Data structures representing the domain entities
- **Repositories**: Data access layer that communicates with the backend
- **BLoCs**: Business logic components that handle state management
- **Services**: High-level interfaces for common operations
- **Screens**: UI components that interact with BLoCs

## BLoC Pattern Implementation

The state management is implemented using the BLoC (Business Logic Component) pattern:

- **Events**: Objects that represent something that happened in the UI
- **States**: Objects that represent the current state of the application
- **BLoC**: Components that convert events into states

### Directory Structure

```
lib/
├── blocs/
│   ├── document/
│   │   ├── document_bloc.dart
│   │   ├── document_event.dart
│   │   ├── document_state.dart
│   ├── user/
│   │   ├── user_bloc.dart
│   │   ├── user_event.dart
│   │   ├── user_state.dart
│   ├── ...
│   ├── bloc.dart (exports)
│   ├── bloc_providers.dart
├── models/
│   ├── document.dart
│   ├── user.dart
│   ├── ...
├── repository/
│   ├── document_repository.dart
│   ├── user_repository.dart
│   ├── ...
├── shared/
│   ├── network/
│   ├── services/
│   ├── swagger/
│   ├── utils/
├── screens/
│   ├── documents_screen.dart
│   ├── ...
```

### Example Usage

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentBloc, DocumentState>(
      builder: (context, state) {
        if (state is DocumentsLoading) {
          return CircularProgressIndicator();
        } else if (state is DocumentsLoaded) {
          return ListView.builder(
            itemCount: state.documents.length,
            itemBuilder: (context, index) {
              return Text(state.documents[index].name);
            }
          );
        } else if (state is DocumentError) {
          return Text('Error: ${state.error}');
        } else {
          return Container();
        }
      },
    );
  }
}
```

## Security Features

- Secure storage implementation using `flutter_secure_storage`
- API authentication handling
- Input validation and sanitization

## API Documentation

The API is documented using Swagger/OpenAPI specifications. The documentation is generated dynamically and can be accessed through the `/api/docs` endpoint.

## Getting Started

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the application
