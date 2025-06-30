import 'package:doc_manager/screens/documents_screen.dart';
import 'package:doc_manager/screens/folders_screen.dart';
import 'package:doc_manager/screens/login_screen.dart';
import 'package:doc_manager/screens/shareable_links_screen.dart';
import 'package:doc_manager/screens/settings_screen.dart';
import 'package:doc_manager/shared/components/responsive_builder.dart';
import 'package:doc_manager/shared/services/auth_service.dart';
import 'package:doc_manager/repository/user_repository.dart';
import 'package:doc_manager/shared/services/secure_storage_service.dart';
import 'package:doc_manager/shared/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  late AuthService _authService;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    try {
      _authService = AuthService(
        userRepository: Provider.of<UserRepository>(context, listen: false),
        secureStorageService: SecureStorageService(),
      );
      _checkAuthStatus();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isAuthenticated = false;
        _errorMessage = "Error initializing authentication: $e";
      });
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      // First check if already authenticated
      final isAuthenticated = await _authService.isAuthenticated();
      
      if (isAuthenticated) {
        try {
          // Try to refresh token before proceeding
          final refreshedToken = await _authService.refreshToken();
          
          setState(() {
            _isAuthenticated = isAuthenticated && refreshedToken != null;
            _isLoading = false;
          });
        } catch (e) {
          // Handle token refresh error
          setState(() {
            _isAuthenticated = false;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle authentication check error
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
        _errorMessage = "Authentication error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Authentication Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _checkAuthStatus();
                },
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAuthenticated) {
      return const MainScreen();
    } else {
      return const LoginScreen();
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late AuthService _authService;
  
  @override
  void initState() {
    super.initState();
    _authService = AuthService(
      userRepository: Provider.of<UserRepository>(context, listen: false),
      secureStorageService: SecureStorageService(),
    );
  }
  
  final List<Widget> _desktopScreens = [
    const FoldersScreen(),
    const DocumentsScreen(),
    const ShareableLinksScreen(),
    const SettingsScreen(),
  ];
  
  final List<String> _screenTitles = [
    'Folders',
    'Documents',
    'Shared Links',
    'Settings',
  ];
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
  
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitles[_selectedIndex]),
        actions: [
          _buildThemeToggle(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _getSelectedScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Folders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Documents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share),
            label: 'Shared Links',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabletLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder),
                label: Text('Folders'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description),
                label: Text('Documents'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.share),
                label: Text('Shared Links'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(_screenTitles[_selectedIndex]),
                actions: [
                  _buildThemeToggle(),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: _logout,
                  ),
                ],
              ),
              body: _getSelectedScreen(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          Drawer(
            child: Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.description,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Doc Manager',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.folder),
                        title: const Text('Folders'),
                        selected: _selectedIndex == 0,
                        onTap: () => _onItemTapped(0),
                      ),
                      ListTile(
                        leading: const Icon(Icons.description),
                        title: const Text('Documents'),
                        selected: _selectedIndex == 1,
                        onTap: () => _onItemTapped(1),
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Settings'),
                        selected: _selectedIndex == 2,
                        onTap: () => _onItemTapped(2),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(_screenTitles[_selectedIndex]),
                actions: [
                  _buildThemeToggle(),
                ],
              ),
              body: _getSelectedScreen(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _getSelectedScreen() {
    return _desktopScreens[_selectedIndex];
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  Future<void> _logout() async {
    final success = await _authService.logout();
    if (success && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  Widget _buildThemeToggle() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        IconData icon;
        String tooltip;
        
        switch (themeProvider.themeMode) {
          case ThemeMode.light:
            icon = Icons.light_mode;
            tooltip = 'Light Mode (tap for Dark)';
            break;
          case ThemeMode.dark:
            icon = Icons.dark_mode;
            tooltip = 'Dark Mode (tap for System)';
            break;
          case ThemeMode.system:
          default:
            icon = Icons.brightness_auto;
            tooltip = 'System Mode (tap for Light)';
            break;
        }
        
        return IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: () => themeProvider.toggleTheme(),
        );
      },
    );
  }
} 