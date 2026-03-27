import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:erp_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Top-level function for iOS background execution
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// Top-level function for background service start
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  print("🚀 Background service started");

  // Load .env if possible, otherwise use hardcoded or passed key
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: Could not load .env in background: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('force_log').listen((event) async {
    print('FLUTTER_BACKGROUND_SERVICE: force_log called with event: $event');
    if (event != null) {
      final p = await SharedPreferences.getInstance();
      if (event['sid'] != null) await p.setString('sid', event['sid']);
      if (event['serverUrl'] != null)
        await p.setString('serverUrl', event['serverUrl']);
      if (event['email'] != null) await p.setString('email', event['email']);
      if (event['employeeId'] != null)
        await p.setString('employeeId', event['employeeId']);
      await p.reload();
      await _logLocation(service, overrides: event);
    } else {
      await _logLocation(service);
    }
  });

  // Perform initial log
  await _logLocation(service);

  // Periodic log - Updated to 15 minutes
  Timer.periodic(const Duration(hours: 1), (timer) async {
    print("⏰ Periodic Timer Triggered");
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        /// OPTIONAL for use custom notification
      }
    }

    await _logLocation(service);

    // Check if we should stop (if user logged out)
    final p = await SharedPreferences.getInstance();
    await p.reload();
    String? sid = p.getString('sid');
    if (sid == null || sid.isEmpty) {
      print("🛑 Stopping background service (No SID)");
      service.stopSelf();
      timer.cancel();
    }
  });
}

Future<void> _logLocation(
  ServiceInstance service, {
  Map<String, dynamic>? overrides,
}) async {
  try {
    print("📍 _logLocation called");
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final String? serverUrl =
        overrides?['serverUrl'] ?? prefs.getString('serverUrl');
    final String? sid = overrides?['sid'] ?? prefs.getString('sid');
    final String? email = overrides?['email'] ?? prefs.getString('email');
    final String? employeeId =
        overrides?['employeeId'] ?? prefs.getString('employeeId');

    if (serverUrl == null || sid == null || email == null) {
      if (service is AndroidServiceInstance || overrides != null) {
        print("❌ Missing credentials in background service (skipping log)");
      }
      return;
    }

    // Check permission (safe)
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("❌ Location permission denied in background");
      return;
    }

    print("🛰️ Fetching current position...");
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
    print("✅ Position fetched: ${position.latitude}, ${position.longitude}");

    // --- SAFE FETCHING OF EXTRA DATA ---

    // 1. Battery
    int batteryLevel = 0;
    try {
      var battery = Battery();
      batteryLevel = await battery.batteryLevel;
    } catch (e) {
      print("⚠️ Could not fetch battery: $e");
    }

    // 2. Device Info
    String deviceId = 'Unknown';
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = '${iosInfo.name} ${iosInfo.model}';
      }
    } catch (e) {
      print("⚠️ Could not fetch device info: $e");
    }

    // 3. Network Info
    String networkType = 'Unknown';
    try {
      final ConnectivityResult connectivityResult = await (Connectivity()
          .checkConnectivity());
      if (connectivityResult == ConnectivityResult.mobile) {
        networkType = 'Mobile';
      } else if (connectivityResult == ConnectivityResult.wifi) {
        networkType = 'WiFi';
      } else {
        networkType = 'None';
      }
    } catch (e) {
      print("⚠️ Could not fetch network info: $e");
    }

    // 4. Address (Via Google Maps API - HTTP)
    String address = "Lat: ${position.latitude}, Lng: ${position.longitude}";
    try {
      // Use the key we found or a fallback/env load
      // Note: In background isolate, dotenv might need explicit load or we pass the key.
      // For now, I will try to read it or use a known procedure.
      String apiKey =
          dotenv.env['GOOGLE_MAPS_API_KEY'] ??
          'AIzaSyCdFNwtk2D39JYUd4xgDunueRPGqaa83Jc'; // Fallback to what we saw in .env

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          address = data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      print("⚠️ Geocoding failed: $e");
    }

    final logData = {
      "employee": employeeId ?? email,
      "user": email,
      "log_date_time": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      "latitude": position.latitude,
      "longitude": position.longitude,
      "accuracy_meters": position.accuracy,
      "location_address": address,
      "map_link":
          "https://www.google.com/maps?q=${position.latitude},${position.longitude}",
      "log_type": "Periodic",
      "device_id": deviceId,
      "battery_percentage": batteryLevel,
      "network_type": networkType,
      "is_mobile": 1,
      "is_mock_location": position.isMocked ? 1 : 0,
    };

    await ApiService.postLocationLog(serverUrl, sid, logData);
    print("✅ Background location logged: $logData");
  } catch (e) {
    print("❌ BG error: $e");
  }
}

class LocationBackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'MY FOREGROUND SERVICE', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'Location Tracking',
        initialNotificationContent: 'Tracking your location in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}
