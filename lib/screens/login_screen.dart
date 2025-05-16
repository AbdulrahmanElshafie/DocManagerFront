import 'package:doc_manager/repository/user_repository.dart';
import 'package:doc_manager/screens/main_screen.dart'; // We'll create this later
import 'package:doc_manager/screens/signup_screen.dart';
import 'package:doc_manager/shared/services/auth_service.dart';
import 'package:doc_manager/shared/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:doc_manager/shared/components/responsive_builder.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(
      userRepository: UserRepository(), // Ideally injected
      secureStorageService: SecureStorageService(), // Ideally injected
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final success = await _authService.login(
          _usernameController.text,
          _passwordController.text,
        );
        
        setState(() => _isLoading = false);
        
        if (success && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login Failed. Please check your credentials.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        
        if (mounted) {
          String errorMessage = 'Login failed.';
          
          // Handle specific error messages
          if (e.toString().contains('Failed to connect to server')) {
            errorMessage = 'Could not connect to server. Please check your internet connection.';
          } else if (e.toString().contains('timed out')) {
            errorMessage = 'Connection timed out. Server may be unavailable.';
          } else if (e.toString().contains('Invalid response format')) {
            errorMessage = 'Server response was invalid. Please contact support.';
          } else {
            // Use the exception message directly
            errorMessage = e.toString().replaceAll('Exception: ', '');
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ResponsiveBuilder(
            desktop: _buildDesktopLayout(),
            tablet: _buildTabletLayout(),
            mobile: _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: _buildLoginForm(),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: _buildLoginForm(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _buildLoginForm();
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Login',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32.0),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your username';
              }
              return null;
            },
          ),
          const SizedBox(height: 16.0),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24.0),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 16.0),
                  ),
                  onPressed: _login,
                  child: const Text('Login'),
                ),
          const SizedBox(height: 16.0),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SignupScreen()),
              );
            },
            child: const Text('Don\'t have an account? Sign Up'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 