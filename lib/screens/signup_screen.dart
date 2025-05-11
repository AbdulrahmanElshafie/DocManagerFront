import 'package:doc_manager/repository/user_repository.dart';
import 'package:doc_manager/screens/login_screen.dart';
import 'package:doc_manager/screens/main_screen.dart';
import 'package:doc_manager/shared/components/responsive_builder.dart';
import 'package:doc_manager/shared/services/auth_service.dart';
import 'package:doc_manager/shared/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(
      userRepository: Provider.of<UserRepository>(context, listen: false),
      secureStorageService: SecureStorageService(),
    );
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final success = await _authService.signup(
        context,
        _firstNameController.text,
        _lastNameController.text,
        _emailController.text,
        _passwordController.text,
        _usernameController.text,
      );
      
      setState(() => _isLoading = false);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup Successful!')),
        );
        // Navigate directly to main screen since signup automatically logs in
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup Failed. Please try again.')),
        );
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
        constraints: const BoxConstraints(maxWidth: 450),
        child: _buildSignupForm(),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: _buildSignupForm(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _buildSignupForm();
  }

  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Create Account',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24.0),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
            validator: (value) => value == null || value.isEmpty ? 'Enter your first name' : null,
          ),
          const SizedBox(height: 16.0),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
            validator: (value) => value == null || value.isEmpty ? 'Enter your last name' : null,
          ),
          const SizedBox(height: 16.0),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_circle)),
            validator: (value) => value == null || value.isEmpty ? 'Enter a username' : null,
          ),
          const SizedBox(height: 16.0),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter your email';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16.0),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter a password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16.0),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Confirm your password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24.0),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16.0), textStyle: const TextStyle(fontSize: 16.0)),
                  onPressed: _signup,
                  child: const Text('Sign Up'),
                ),
          const SizedBox(height: 16.0),
          TextButton(
            onPressed: () {
               Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Already have an account? Login'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
} 