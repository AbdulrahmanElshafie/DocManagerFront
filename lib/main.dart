import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doc_manager/blocs/bloc_providers.dart';
import 'package:doc_manager/screens/main_screen.dart';
import 'package:doc_manager/shared/providers/theme_provider.dart';

void main() {
  // It's good practice to ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Normalize TextTheme to ensure consistent inherit values
  TextTheme _normalizedTextTheme(TextTheme textTheme) {
    return textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(inherit: true),
      displayMedium: textTheme.displayMedium?.copyWith(inherit: true),
      displaySmall: textTheme.displaySmall?.copyWith(inherit: true),
      headlineLarge: textTheme.headlineLarge?.copyWith(inherit: true),
      headlineMedium: textTheme.headlineMedium?.copyWith(inherit: true),
      headlineSmall: textTheme.headlineSmall?.copyWith(inherit: true),
      titleLarge: textTheme.titleLarge?.copyWith(inherit: true),
      titleMedium: textTheme.titleMedium?.copyWith(inherit: true),
      titleSmall: textTheme.titleSmall?.copyWith(inherit: true),
      bodyLarge: textTheme.bodyLarge?.copyWith(inherit: true),
      bodyMedium: textTheme.bodyMedium?.copyWith(inherit: true),
      bodySmall: textTheme.bodySmall?.copyWith(inherit: true),
      labelLarge: textTheme.labelLarge?.copyWith(inherit: true),
      labelMedium: textTheme.labelMedium?.copyWith(inherit: true),
      labelSmall: textTheme.labelSmall?.copyWith(inherit: true),
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      //  ─── TURN OFF ALL RIPPLE SPLASHES ───────────────────────────────
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
    
    return base.copyWith(
      textTheme: _normalizedTextTheme(base.textTheme),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: Colors.deepPurple, width: 2.0),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.deepPurple,
        )
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        iconTheme: IconThemeData(color: Colors.deepPurple),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: Colors.deepPurple,
        unselectedLabelColor: Colors.grey,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      //  ─── TURN OFF ALL RIPPLE SPLASHES ───────────────────────────────
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
    
    return base.copyWith(
      textTheme: _normalizedTextTheme(base.textTheme),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: Colors.deepPurpleAccent, width: 2.0),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurpleAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ...AppBlocProviders.providers,
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Document Manager',
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            // Restored smooth theme animation
            themeAnimationDuration: const Duration(milliseconds: 300),
            themeAnimationCurve: Curves.easeInOut,
            debugShowCheckedModeBanner: false,
            home: const MainScreen(), // Use MainScreen as the initial screen
          );
        },
      ),
    );
  }
}

// HomePage is no longer directly used as the entry but can be part of MainScreen later.
// class HomePage extends StatelessWidget {
//   const HomePage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Document Manager'),
//       ),
//       body: const Center(
//         child: Text('Document Manager App'),
//       ),
//     );
//   }
// }
