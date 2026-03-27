import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:erp_mobile/services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class CustomUpgraderMessages extends UpgraderMessages {
  @override
  String get body =>
      'A new version is available! Please update to continue using the app.';

  @override
  String get buttonTitleUpdate => 'Update Now';

  @override
  String get buttonTitleIgnore => 'Ignore';

  @override
  String get buttonTitleLater => 'Later';

  @override
  String get prompt =>
      'Please update to the latest version for the best experience.';

  @override
  String get title => 'Update Available';
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedProtocol = 'https://';
  bool _isLoading = false;
  String _appVersion = 'Loading...';
  bool _isPasswordVisible = false;
  bool _rememberMe = false; // Added for Remember Me functionality
  late AnimationController _lockAnimationController;
  late Animation<double> _lockAnimation;

  @override
  void initState() {
    super.initState();
    _ipController.text = 'vps-mobile.vpsbusinesssolution.com';
    _initPackageInfo();
    _loadCredentials();
    _lockAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _lockAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _lockAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _loadCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe) {
      final String? savedUrl = prefs.getString('serverUrl');
      setState(() {
        if (savedUrl != null && savedUrl.isNotEmpty) {
          if (savedUrl.startsWith('https://')) {
            _selectedProtocol = 'https://';
            _ipController.text = savedUrl.substring(8);
            _lockAnimationController.forward();
          } else if (savedUrl.startsWith('http://')) {
            _selectedProtocol = 'http://';
            _ipController.text = savedUrl.substring(7);
            _lockAnimationController.reverse();
          }
        }
        _usernameController.text = prefs.getString('username') ?? '';
        _passwordController.text = prefs.getString('password') ?? '';
        _rememberMe = rememberMe;
      });
    }
  }

  Future<void> _saveCredentials(String serverUrl) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', true);
    await prefs.setString('serverUrl', serverUrl);
    await prefs.setString('username', _usernameController.text.trim());
    await prefs.setString('password', _passwordController.text.trim());
  }

  Future<void> _clearCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('rememberMe');
    await prefs.remove('serverUrl');
    await prefs.remove('username');
    await prefs.remove('password');
  }

  Future<void> _initPackageInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      debugPrint('Error getting package info: $e');
      setState(() {
        _appVersion = 'Version unavailable';
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _lockAnimationController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Error',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_ipController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields.');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final String serverUrl = '$_selectedProtocol${_ipController.text}';
      final String apiUrl = '$serverUrl/api/method/login';
      print('Sending request to: $apiUrl');

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'usr': _usernameController.text.trim(),
              'pwd': _passwordController.text.trim(),
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your internet connection or server URL.',
              );
            },
          );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Extract SID from cookies
        String? sid;
        String? setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          final sidMatch = RegExp(r'sid=([^;]+)').firstMatch(setCookie);
          if (sidMatch != null) {
            sid = sidMatch.group(1);
          }
        }

        if (sid != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('sid', sid);
          await prefs.setString('fullName', _usernameController.text.trim());
          await prefs.setString('email', _usernameController.text.trim());
          String email = _usernameController.text.trim();

          if (_rememberMe) {
            await _saveCredentials(serverUrl);
          } else {
            await _clearCredentials();
          }

          // Fetch Employee ID via standard API (used for prefs/profile features)
          try {
            await ApiService.getEmployeeIdByUser(serverUrl, sid, email);
          } catch (e) {
            print('Could not fetch employee ID: $e');
          }

          // Background location service disabled as it depends on custom Doctypes
          /*
          try {
            // ...
          } catch (e) {
            print('Error starting background service: $e');
          }
          */

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Login successful! Welcome, $email',
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          Navigator.pushReplacementNamed(
            context,
            '/dashboard',
            arguments: {
              'serverUrl': serverUrl,
              'sid': sid,
              'fullName': email,
              'email': email,
            },
          );
        } else {
          _showErrorDialog(
            'Login failed. Session ID not found in the response.',
          );
        }
      } else {
        _showErrorDialog(
          'Server error: ${response.statusCode}. Please try again later.',
        );
      }
    } catch (e) {
      _showErrorDialog('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // *** THIS FUNCTION IS NOW UPDATED ***
  // It will show a dialog with 3 options: Cancel, Go Back, and Close App
  Future<bool> _onWillPop() async {
    // Show a custom dialog
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Confirmation',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        content: const Text('What would you like to do?'),
        actions: [
          // 1. Cancel button (Stays on Login Screen)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(), // Just close the dialog
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
          ),
          // 2. "Go Back" (to Landing Screen) button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              // This navigates back to the Landing Screen
              // Assumes your main.dart has a route named '/landing'
              Navigator.pushReplacementNamed(context, '/landing');
            },
            child: Text(
              'Go Back', // "back na landing screen ponum"
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          // 3. "Close App" button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              SystemNavigator.pop(); // Exit the app
            },
            child: Text(
              'Close App', // "close na app total close agnum"
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );

    // We return 'false' because we are handling all navigation
    // manually and don't want the default 'pop' to happen.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Theme.of(context).colorScheme.background,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    final upgrader = Upgrader(
      messages: CustomUpgraderMessages(),
      durationUntilAlertAgain: const Duration(days: 1),
    );
    return UpgradeAlert(
      upgrader: upgrader,
      // This WillPopScope now calls your new _onWillPop function
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 32),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildLoginCard(),

                    _buildCompanyInfo(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(20),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.business,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'VPS Businesssolution',
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge!.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildServerUrlField(),
            const SizedBox(height: 24),
            _buildUsernameField(),
            const SizedBox(height: 24),
            _buildPasswordField(),
            const SizedBox(height: 16),
            _buildOptionsRow(),
            const SizedBox(height: 32),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server URL',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedProtocol = _selectedProtocol == 'https://'
                          ? 'http://'
                          : 'https://';
                      if (_selectedProtocol == 'https://') {
                        _lockAnimationController.forward();
                      } else {
                        _lockAnimationController.reverse();
                      }
                    });
                  },
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _lockAnimation,
                        builder: (context, child) => Icon(
                          _selectedProtocol == 'https://'
                              ? Icons.lock_outline
                              : Icons.lock_open_outlined,
                          size: 18,
                          color: _selectedProtocol == 'https://'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedProtocol.replaceAll('://', ''),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _ipController,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'domain.com',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Username',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        LoginTextField(
          controller: _usernameController,
          hintText: 'email@example.com',
          prefixIcon: Icons.person_outline,
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        LoginTextField(
          controller: _passwordController,
          hintText: 'Enter your password',
          prefixIcon: Icons.lock_outline,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsRow() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text('Remember me', style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text(
            'Powered by VPS Businesssolution',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          Text(
            'v$_appVersion',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final IconData? prefixIcon;
  final String? hintText;
  final bool obscureText;
  final Widget? suffixIcon;

  const LoginTextField({
    Key? key,
    required this.controller,
    this.prefixIcon,
    this.hintText,
    this.obscureText = false,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Colors.grey.shade500, size: 20)
              : null,
          suffixIcon: suffixIcon,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
