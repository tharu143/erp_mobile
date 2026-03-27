import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:ui';

// A dialog to show API errors
void showApiErrorDialog(
  BuildContext context, {
  int? statusCode,
  required String message,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(statusCode != null ? 'Error: $statusCode' : 'Error'),
        content: SingleChildScrollView(child: Text(message)),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

class HRScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const HRScreen({
    required this.serverUrl,
    required this.sid,
    required this.email,
    super.key,
  });

  @override
  State<HRScreen> createState() => _HRScreenState();
}

class _HRScreenState extends State<HRScreen> with TickerProviderStateMixin {
  // State variables
  String? checkInTime; // Today's last check-in
  String? checkOutTime; // Today's last check-out
  bool isCheckedIn = false; // Is user currently checked-in *today*?
  bool _isLoading = true;

  String employeeName = 'Loading...';
  String employeeId = 'Loading...';
  String? latitude;
  String? longitude;
  String? customLocation;
  String? customMapLink;

  // --- New state variables for check-in restriction ---
  bool _isBlockedFromCheckIn = false;
  String? _blockReasonDate; // Date of the missed check-out

  // Animation controller for the punch button
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  // Initial data fetching
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchUserInfo();
    await _fetchCheckIns(); // This now contains the restriction logic
    await _getCurrentLocation();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- Data Fetching Logic ---

  Future<void> _fetchUserInfo() async {
    // Standard way to get employee ID from user email
    final url =
        '${widget.serverUrl}/api/resource/Employee?filters=[["user_id","=","${widget.email}"]]&fields=["name","employee_name"]';
    final headers = {'Cookie': 'sid=${widget.sid}'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final employee = data['data'][0];
          if (!mounted) return;
          setState(() {
            employeeName = employee['employee_name'] ?? 'Unknown User';
            employeeId = employee['name'] ?? 'N/A';
          });
        } else {
          if (!mounted) return;
          showApiErrorDialog(context, message: 'Employee record not found for this user.');
        }
      } else {
        if (!mounted) return;
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: e.toString());
    }
  }

  /// Fetches all check-ins and determines both today's status
  /// and if the user is blocked from checking in due to a missed checkout.
  Future<void> _fetchCheckIns() async {
    if (employeeId == 'Loading...' || employeeId == 'N/A') return;
    
    final url =
        '${widget.serverUrl}/api/resource/Employee Checkin?filters=[["employee","=","$employeeId"]]&fields=["time","log_type"]&order_by=time desc&limit_page_length=20';
    final headers = {'Cookie': 'sid=${widget.sid}'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          final List<dynamic> checkins = data['data'];
          final currentDateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
          
          final List<DateTime> allInTimes = checkins
              .where((c) => c['log_type'] == 'IN')
              .map((c) => DateTime.parse(c['time']))
              .toList();
          final List<DateTime> allOutTimes = checkins
              .where((c) => c['log_type'] == 'OUT')
              .map((c) => DateTime.parse(c['time']))
              .toList();

          allInTimes.sort((a, b) => a.compareTo(b));
          allOutTimes.sort((a, b) => a.compareTo(b));

          final DateTime? latestIn = allInTimes.isNotEmpty ? allInTimes.last : null;
          final DateTime? latestOut = allOutTimes.isNotEmpty ? allOutTimes.last : null;

          final todayIn = allInTimes.where((t) => t.toIso8601String().startsWith(currentDateString)).toList();
          final todayOut = allOutTimes.where((t) => t.toIso8601String().startsWith(currentDateString)).toList();

          DateTime? lastInToday = todayIn.isNotEmpty ? todayIn.last : null;
          DateTime? lastOutToday = todayOut.isNotEmpty ? todayOut.last : null;

          bool isCheckedInToday = false;
          if (lastInToday != null) {
            isCheckedInToday = lastOutToday == null || lastInToday.isAfter(lastOutToday);
          }

          bool isBlocked = false;
          String? blockDate;
          if (latestIn != null) {
            if (latestOut == null || latestIn.isAfter(latestOut)) {
              final latestInDateStr = DateFormat('yyyy-MM-dd').format(latestIn);
              if (latestInDateStr != currentDateString) {
                isBlocked = true;
                blockDate = latestInDateStr;
              }
            }
          }

          if (!mounted) return;
          setState(() {
            checkInTime = lastInToday?.toIso8601String();
            checkOutTime = lastOutToday?.toIso8601String();
            isCheckedIn = isCheckedInToday;
            _isBlockedFromCheckIn = isBlocked;
            _blockReasonDate = blockDate;
          });
        }
      }
    } catch (e) {
       print('Error fetching check-ins: $e');
    }
  }

  // --- Location & Check-in/out Logic ---

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    // Check service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('To check in/out, please enable location services.'),
          ),
        );
      }
      setState(() => _isLocationLoading = false);
      return;
    }

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        setState(() => _isLocationLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
        await openAppSettings();
      }
      setState(() => _isLocationLoading = false);
      return;
    }

    // Get current location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String? placeName = await _getPlaceName(
        position.latitude,
        position.longitude,
      );
      String mapLink = _generateMapLink(
        position.latitude.toString(),
        position.longitude.toString(),
      );

      if (!mounted) return;
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
        customLocation = placeName;
        customMapLink = mapLink;
      });
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: 'Error getting location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  Future<String?> _getPlaceName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        // Combine more details for a better location string
        String locality = p.locality ?? '';
        String country = p.country ?? '';
        String subLocality = p.subLocality ?? '';
        String street = p.street ?? '';

        String address = [
          street,
          subLocality,
          locality,
          country,
        ].where((s) => s.isNotEmpty).join(', ');
        return address.isNotEmpty ? address : 'Unknown Location';
      }
      return 'Unknown Location';
    } catch (e) {
      return 'Could not get location name';
    }
  }

  String _generateMapLink(String lat, String lon) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }

  /// Shows the warning dialog for a missed check-out.
  void _showMissedCheckoutDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2), // subtle overlay
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5,
            sigmaY: 5,
          ), // 🔥 blurred background
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),

            // 🔹 Centered Title
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
                SizedBox(height: 10),
                Text(
                  'Check-in Restricted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'You did not check out on '),
                      TextSpan(text: _blockReasonDate ?? 'a previous day'),
                      TextSpan(text: '.\n\n'),
                      TextSpan(
                        text: 'Because of this, you cannot check in today.\n\n',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please contact the administrative office to resolve this issue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ],
            ),

            actions: [
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF0074c9),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCheckInOut(bool isCheckIn) async {
    _animationController.forward().then((_) => _animationController.reverse());

    // --- START: New restriction logic ---
    if (isCheckIn && _isBlockedFromCheckIn) {
      _showMissedCheckoutDialog();
      return; // Stop the check-in process
    }
    // --- END: New restriction logic ---

    // Ensure location is available
    if (latitude == null || longitude == null) {
      await _getCurrentLocation();
      if (latitude == null || longitude == null) {
        if (!mounted) return;
        showApiErrorDialog(
          context,
          message:
              'Location unavailable. Please check permissions and try again.',
        );
        return;
      }
    }

    // Set loading state for check-in/out
    setState(() {
      _isLoading = true;
    });

    final url = '${widget.serverUrl}/api/resource/Employee Checkin';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'employee': employeeId,
      'log_type': isCheckIn ? 'IN' : 'OUT',
      'time': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'device_id': 'mobile_app',
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCheckIn
                  ? 'Checked In Successfully'
                  : 'Checked Out Successfully',
            ),
            backgroundColor: isCheckIn ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh state
        await _fetchCheckIns();
        // Get fresh location for next action
        await _getCurrentLocation();
      } else {
        if (!mounted) return;
        showApiErrorDialog(
          context,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Helpers & UI Builders ---

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _navigateTo(String routeName) {
    Navigator.pushNamed(
      context,
      routeName,
      arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'HR Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildUserInfoCard(),
                    const SizedBox(height: 30),
                    _buildAttendanceAction(),
                    const SizedBox(height: 30),
                    _buildNavigationGrid(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserInfoCard() {
    final greeting = _getGreeting();
    final formattedDate = DateFormat('EEE, d MMM yyyy').format(DateTime.now());
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      employeeName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Show Today's last check-in time if checked in
          if (checkInTime != null && isCheckedIn) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.login, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Check-in (Today)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      DateFormat(
                        'h:mm a',
                      ).format(DateTime.parse(checkInTime!).toLocal()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceAction() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          // Show a warning if blocked
          _isBlockedFromCheckIn
              ? 'Check-in Disabled'
              : "Ready to start your day?",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: _isBlockedFromCheckIn ? Colors.red : null,
          ),
        ),
        if (_isBlockedFromCheckIn)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Missed checkout on $_blockReasonDate',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        const SizedBox(height: 20),
        ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: () {
              if (isCheckedIn) {
                _handleCheckInOut(false); // Check out
              } else {
                _handleCheckInOut(true); // Check in (will be blocked if needed)
              }
            },
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100, width: 1),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isCheckedIn
                          ? [Colors.orange.shade600, Colors.red.shade400]
                          : _isBlockedFromCheckIn
                          ? [Colors.grey.shade600, Colors.grey.shade400]
                          : [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCheckedIn
                            ? Icons.logout
                            : _isBlockedFromCheckIn
                            ? Icons.lock
                            : Icons.login,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isCheckedIn ? 'PUNCH OUT' : 'PUNCH IN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationGrid() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            ActionCard(
              title: 'Leave',
              icon: FontAwesomeIcons.calendarDay,
              onTap: () => _navigateTo('/leaveApplicationList'),
              color: Colors.blue,
            ),
            ActionCard(
              title: 'Employees',
              icon: FontAwesomeIcons.users,
              onTap: () => _navigateTo('/employeeList'),
              color: Colors.orange,
            ),
            ActionCard(
              title: 'Attendance',
              icon: FontAwesomeIcons.clipboardCheck,
              onTap: () => _navigateTo('/attendanceList'),
              color: Colors.green,
            ),
            /*
            ActionCard(
              title: 'Leave Dashboard',
              icon: Icons.dashboard_customize,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/leaveDashboard',
                  arguments: {
                    'serverUrl': widget.serverUrl,
                    'sid': widget.sid,
                    'email': widget.email,
                  },
                );
              },
              color: Colors.purple,
            ),
            */
          ],
        ),
      ],
    );
  }
}

// Card for quick actions
class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.color = Colors.blue,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
