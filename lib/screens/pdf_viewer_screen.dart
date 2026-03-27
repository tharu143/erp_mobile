import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart'; // No longer needed
// import 'package:url_launcher/url_launcher.dart'; // No longer needed
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'package:package_info_plus/package_info_plus.dart'; // No longer needed
// import 'package:share_plus/share_plus.dart'; // No longer needed
// import 'dart:io'; // No longer needed
import 'dart:developer' as developer;
import 'dart:typed_data'; // Added for sharing
import 'package:printing/printing.dart'; // Added for sharing

import '../utils/error_handler.dart';
import 'package:erp_mobile/services/api_client.dart';

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final String fileName;
  final String sid; // Added sid

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.fileName,
    required this.sid, // Added sid
  });

  /// Fetch the PDF bytes from the URL.
  Future<Uint8List?> _fetchPdfBytesFromUrl(
      BuildContext context, String pdfUrl) async {
    final uri = Uri.parse(pdfUrl); // Use the full URL directly
    final headers = {
      'Cookie': 'sid=$sid',
      'Accept': 'application/pdf',
    };

    developer.log('Fetching PDF bytes from: $uri');

    try {
      final response = await ApiClient.get(uri, headers: headers);
      if (response.statusCode == 200 &&
          response.headers['content-type'] == 'application/pdf') {
        developer.log('PDF bytes fetched successfully');
        return response.bodyBytes;
      } else {
        developer.log(
            'Failed to download PDF: ${response.statusCode}, Content-Type: ${response.headers['content-type']}');
        if (context.mounted) {
          showApiErrorDialog(context,
              message: 'Failed to fetch PDF: ${response.statusCode}.');
        }
        return null;
      }
    } catch (e) {
      developer.log('Error fetching PDF bytes: $e');
      if (context.mounted) {
        showApiErrorDialog(context, message: e.toString());
      }
      return null;
    }
  }

  /// Share Report
  Future<void> _shareReport(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Preparing file to share...')),
    );
    try {
      // Step 1: Get PDF Bytes
      final bytes = await _fetchPdfBytesFromUrl(context, pdfUrl);
      if (bytes != null && context.mounted) {
        // Step 2: Share Bytes
        await Printing.sharePdf(
          bytes: bytes,
          filename: fileName,
        );
      }
    } catch (e) {
      developer.log('Error in _shareReport: $e');
      if (context.mounted) {
        showApiErrorDialog(context, message: e.toString());
      }
    }
  }

  // Removed _downloadPdf function
  // Future<void> _downloadPdf(BuildContext context) async { ... }

  // Removed old _sharePdf function
  // Future<void> _sharePdf(BuildContext context) async { ... }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 16 : 20,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Added new Share button
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareReport(context),
            tooltip: 'Share PDF',
            iconSize: isMobile ? 20 : 24,
          ),
          // Removed old Share button
          // IconButton(
          //   icon: const Icon(Icons.share, color: Colors.white),
          //   onPressed: () => _sharePdf(context),
          //   tooltip: 'Share PDF',
          //   iconSize: isMobile ? 20 : 24,
          // ),
          // Removed Download button
          // IconButton(
          //   icon: const Icon(Icons.download, color: Colors.white),
          //   onPressed: () => _downloadPdf(context),
          //   tooltip: 'Save to Device',
          //   iconSize: isMobile ? 20 : 24,
          // ),
        ],
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        key: UniqueKey(), // Ensures reload on navigation
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        canShowScrollHead: true,
        canShowPaginationDialog: true,
        interactionMode: PdfInteractionMode.pan,
        // Pass headers to SfPdfViewer as well
        headers: {'Cookie': 'sid=$sid'},
      ),
    );
  }
}
