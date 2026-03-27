import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // A small delay to show the splash screen nicely.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final String? sid = prefs.getString('sid');
    final String? savedServerUrl = prefs.getString('serverUrl');
    final String? fullName = prefs.getString('fullName');
    final String? email = prefs.getString('email');

    if (!mounted) return;

    if (sid != null && savedServerUrl != null && email != null) {
      // User is already logged in, navigate to the dashboard.
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: {
          'serverUrl': savedServerUrl,
          'sid': sid,
          'fullName': fullName ?? 'User',
          'email': email,
        },
      );
    } else {
      // User is not logged in, navigate to the login page.
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ensure you have a logo image at 'assets/images/logo.png'
            Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.business,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Loading...', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
