import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- 1. ADDED THIS IMPORT
import 'package:webview_flutter/webview_flutter.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

// Add 'with SingleTickerProviderStateMixin' for the animation
class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isButtonExpanded = false; // State for the button

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // You can show an error message to the user here
            debugPrint('''
              Page resource error:
              code: ${error.errorCode}
              description: ${error.description}
              errorType: ${error.errorType}
              isForMainFrame: ${error.isForMainFrame}
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.VPStechllc.com/'));
  }

  // 3. ADDED THIS FUNCTION
  // This function is called when the user presses the system back button
  Future<bool> _onWillPop() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Close App',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        content: const Text('Are you sure you want to close the app?'),
        actions: [
          // "No" button
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Just close the dialog
            child: Text(
              'No',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          // "Yes" (Close App) button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              SystemNavigator.pop(); // <-- This line closes the app
            },
            child: Text(
              'Yes',
              style: TextStyle(
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );

    // We return 'false' to prevent the default back button behavior
    // because we are handling it manually (with the dialog).
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // 2. WRAPPED THE SCAFFOLD WITH WILLPOPSCOPE
    return WillPopScope(
      onWillPop: _onWillPop, // This links the back button to our new function
      child: Scaffold(
        // We use a Stack to overlay the button and gradient on the WebView
        body: SafeArea(
          child: Stack(
            children: [
              // The WebView is the base layer
              WebViewWidget(controller: _controller),

              // Gradient Overlay for better button visibility
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 128, // Matches h-32 from the design
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        // Use surface color from theme to match design
                        Theme.of(context).colorScheme.surface.withOpacity(0.6),
                      ],
                    ),
                  ),
                  // We don't want the gradient to block webview clicks
                  child: IgnorePointer(),
                ),
              ),

              // --- Animated Floating Login Button ---
              Align(
                // *** MODIFICATION 1: Moved to bottom-left ***
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 32.0),
                  // Material widget provides elevation and clipping
                  child: Material(
                    elevation: 5.0,
                    // Animate the border radius
                    borderRadius:
                        BorderRadius.circular(_isButtonExpanded ? 12 : 28),
                    color: Theme.of(context).colorScheme.primary,
                    child: InkWell(
                      // Animate border radius for the ripple effect
                      borderRadius:
                          BorderRadius.circular(_isButtonExpanded ? 12 : 28),
                      // *** MODIFICATION 2: Updated click logic ***
                      onTap: () {
                        if (_isButtonExpanded) {
                          // 2. If it's already expanded, a second click navigates
                          Navigator.pushReplacementNamed(context, '/login');
                        } else {
                          // 1. If it's collapsed, the first click expands it
                          setState(() {
                            _isButtonExpanded = true;
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: 56.0,
                        // Animate the padding
                        padding: EdgeInsets.symmetric(
                          horizontal: _isButtonExpanded ? 24 : 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(_isButtonExpanded ? 12 : 28),
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min, // Fit to content size
                          children: [
                            Icon(
                              Icons.login_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                            // This widget animates the size change when the text appears
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _isButtonExpanded
                                  ? Padding(
                                      padding:
                                          const EdgeInsets.only(left: 12.0),
                                      child: Text(
                                        'Employee Login',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : SizedBox.shrink(), // Take no space when collapsed
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Loading Overlay
              if (_isLoading)
                Container(
                  // Covers the whole screen with a semi-transparent background
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ), // Replaces Loader2
                        const SizedBox(height: 24),
                        Text(
                          'Loading VPS Businesssolution...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

