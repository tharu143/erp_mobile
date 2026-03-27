// import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:erp_mobile/utils/global_keys.dart';

class ApiClient {
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final response = await http.get(url, headers: headers);
    await _checkResponse(response);
    return response;
  }

  static Future<http.Response> post(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await http.post(url, headers: headers, body: body);
    await _checkResponse(response);
    return response;
  }

  static Future<http.Response> put(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await http.put(url, headers: headers, body: body);
    await _checkResponse(response);
    return response;
  }

  static Future<void> _checkResponse(http.Response response) async {
    await checkStatus(response.statusCode);
  }

  static Future<void> checkStatus(int statusCode) async {
    if (statusCode == 401) {
      // Session expired
      _handleSessionExpiry();
    }
    // Note: We ignore 403 (Forbidden) here as per user request,
    // because it might be a permission error, not a session expiry.
  }

  static void _handleSessionExpiry() {
    // Determine if we need to navigate.
    // We use a post frame callback or just run immediately if we are sure.
    // Check if we are already on login screen to prevent loop? (Login screen likely doesn't make auth calls usually)

    // Only navigate if we have a context or key
    if (navigatorKey.currentState != null) {
      // Avoid multiple redirects if multiple calls fail at once
      // This is a simple implementation.
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );

      // Show snackbar
      if (scaffoldMessengerKey.currentState != null) {
        scaffoldMessengerKey.currentState!.showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
