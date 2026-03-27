import 'dart:convert';
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart'; // Keep for layoutPdf and sharePdf
import 'package:erp_mobile/services/api_client.dart';

class SalesInvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  final String serverUrl;
  final String sid;

  const SalesInvoiceDetailScreen({
    Key? key,
    required this.invoiceId,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _SalesInvoiceDetailScreenState createState() =>
      _SalesInvoiceDetailScreenState();
}

class _SalesInvoiceDetailScreenState extends State<SalesInvoiceDetailScreen> {
  Map<String, dynamic> invoiceDetails = {};
  bool isLoading = true;
  bool _isDownloadingPdf = false; // State for PDF download
  String errorMessage = '';

  // Define unique colors for each of the 26 English letters (blue-centric, same as other screens)
  final Map<String, Color> _letterColors = {
    'A': const Color(0xFF0074c9), // Primary blue
    'B': const Color(0xFF005B99), // Secondary blue
    'C': const Color(0xFF003087), // Darker blue
    'D': const Color(0xFF1E90FF), // Dodger blue
    'E': const Color(0xFF4682B4), // Steel blue
    'F': const Color(0xFF6495ED), // Cornflower blue
    'G': const Color(0xFF00B7EB), // Cyan blue
    'H': const Color(0xFF4169E1), // Royal blue
    'I': const Color(0xFF87CEEB), // Sky blue
    'J': const Color(0xFF1C86EE), // Bright blue
    'K': const Color(0xFF104E8B), // Navy blue
    'L': const Color(0xFF63B8FF), // Light blue
    'M': const Color(0xFF00CED1), // Dark cyan (blue-ish)
    'N': const Color(0xFF5CACEE), // Soft blue
    'O': const Color(0xFF1874CD), // Medium blue
    'P': const Color(0xFF7B68EE), // Medium slate blue
    'Q': const Color(0xFF8470FF), // Light slate blue
    'R': const Color(0xFF6A5ACD), // Slate blue
    'S': const Color(0xFF483D8B), // Dark slate blue
    'T': const Color(0xFF00BFFF), // Deep sky blue
    'U': const Color(0xFF20B2AA), // Light sea blue
    'V': const Color(0xFF3A5FCD), // Medium blue
    'W': const Color(0xFF4A708B), // Dark blue-gray
    'X': const Color(0xFF607B8B), // Blue-gray
    'Y': const Color(0xFF7A67EE), // Soft slate blue
    'Z': const Color(0xFF1034A6), // Deep blue
  };

  @override
  void initState() {
    super.initState();
    fetchInvoiceDetails();
  }

  Future<void> fetchInvoiceDetails() async {
    final url =
        "${widget.serverUrl}/api/resource/Sales Invoice/${widget.invoiceId}";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          invoiceDetails = data['data'] ?? {};
          isLoading = false;
          errorMessage = '';
        });
      } else {
        throw Exception(
          'Failed to load sales invoice details: ${response.statusCode}',
        );
      }
    } catch (error) {
      print('Error: $error');
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching sales invoice details: $error';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching sales invoice details: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Fetches the PDF from the server API.
  Future<Uint8List?> _fetchPdfBytes() async {
    setState(() {
      _isDownloadingPdf = true;
    });

    // Build the query parameters
    final Map<String, String> queryParams = {
      'doctype': 'Sales Invoice',
      'name': widget.invoiceId,
      'format': 'SALES INVOICE NEW FORMART',
      'no_letterhead': '0',
      'letterhead': 'VPS Businesssolution',
      'language': 'en',
    };

    // Create the URI with encoded query parameters
    final uri = Uri.parse(
            "${widget.serverUrl}/api/method/frappe.utils.print_format.download_pdf")
        .replace(queryParameters: queryParams);

    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Accept': 'application/pdf', // We expect a PDF response
    };

    print('Fetching PDF from: $uri');

    try {
      final response = await ApiClient.get(uri, headers: headers);

      if (response.statusCode == 200) {
        // Check if the response is actually a PDF
        if (response.headers['content-type'] == 'application/pdf') {
          print('PDF fetched successfully (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        } else {
          // The server returned 200 but not a PDF. It's probably a JSON error.
          String responseBody = 'Unknown error: Server did not return a PDF.';
          try {
            // Try to decode as JSON error
            final data = json.decode(utf8.decode(response.bodyBytes));
            responseBody = data['message'] ??
                data['exc'] ??
                'Server returned an unknown error.';
          } catch (e) {
            // Not JSON, just use the raw body (or part of it)
            responseBody =
                utf8.decode(response.bodyBytes, allowMalformed: true);
            if (responseBody.length > 200) {
              responseBody = responseBody.substring(0, 200) + "...";
            }
          }
          throw Exception('Failed to get PDF: $responseBody');
        }
      } else {
        // Handle non-200 status codes
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching PDF: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
        });
      }
    }
  }

  /// Prints the fetched sales invoice PDF.
  Future<void> _printSalesInvoice() async {
    if (invoiceDetails.isEmpty || _isDownloadingPdf) return;

    final Uint8List? bytes = await _fetchPdfBytes();

    if (bytes != null && mounted) {
      await Printing.layoutPdf(onLayout: (format) => bytes);
    }
  }

  /// Shares or saves the fetched sales invoice PDF.
  Future<void> _shareOrDownloadPdf() async {
    if (invoiceDetails.isEmpty || _isDownloadingPdf) return;

    final Uint8List? bytes = await _fetchPdfBytes();

    if (bytes != null && mounted) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'sales_invoice_${invoiceDetails['name']}.pdf',
      );
    }
  }

  // Utility functions (remain the same)
  String removeHtmlTags(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return 'N/A';
    final RegExp exp = RegExp(
      r'<[^>]*>',
      multiLine: true,
      caseSensitive: false,
    );
    return htmlString.replaceAll(exp, '').trim();
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getAvatarText(String? customerName, String invoiceId) {
    if (customerName == null || customerName.isEmpty) {
      return invoiceId.isNotEmpty ? invoiceId[0].toUpperCase() : 'N';
    }
    final words = customerName.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
    }
    return customerName[0].toUpperCase();
  }

  Color _getAvatarColor(String? customerName, String invoiceId) {
    final name = customerName ?? (invoiceId.isNotEmpty ? invoiceId : 'N');
    return _letterColors[name[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
              // Allow text to wrap if it's long (like an address)
              // overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // *** NEW WIDGET METHOD for displaying a single item ***
  Widget _buildItemCard(Map<String, dynamic> item, String currency) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['item_name']?.toString() ?? 'N/A',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
            const SizedBox(height: 8),
            _buildItemDetailRow(
              'Item Code',
              item['item_code'],
            ),
            _buildItemDetailRow(
              'Brand',
              item['brand'],
            ),
            _buildItemDetailRow(
              'Group',
              item['item_group'],
            ),
            _buildItemDetailRow(
              'Qty',
              item['qty']?.toString(),
            ),
            _buildItemDetailRow(
              'Amount',
              '${item['amount']} $currency',
            ),
            _buildItemDetailRow(
              'Total Amount',
              '${item['total_amount']} $currency',
            ),
          ],
        ),
      ),
    );
  }

  // *** NEW HELPER WIDGET for item details ***
  Widget _buildItemDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarText = _getAvatarText(
      invoiceDetails['customer_name'],
      invoiceDetails['name'] ?? 'N',
    );
    final avatarColor = _getAvatarColor(
      invoiceDetails['customer_name'],
      invoiceDetails['name'] ?? 'N',
    );
    // *** NEW: Extract items list safely ***
    final List<dynamic> items = invoiceDetails['items'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          invoiceDetails['name'] ?? 'Sales Invoice Details',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary, // 0xFF0074c9
                Theme.of(
                  context,
                ).colorScheme.secondary.withOpacity(0.8), // 0xFF005B99
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _isDownloadingPdf
                ? null
                : _printSalesInvoice, // Disable when downloading
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white), // Changed icon
            onPressed: _isDownloadingPdf
                ? null
                : _shareOrDownloadPdf, // Disable when downloading
            tooltip: 'Share/Download PDF', // Updated tooltip
          ),
        ],
      ),
      body: Stack(
        // Use Stack for loading overlay
        children: [
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                errorMessage,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      color: Colors.red,
                                      fontSize: 18,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: fetchInvoiceDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : invoiceDetails.isEmpty
                          ? Center(
                              child: Text(
                                'Sales invoice not found',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground,
                                      fontSize: 18,
                                    ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Invoice Info Section
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: avatarColor,
                                                radius: 30,
                                                child: Text(
                                                  avatarText,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Invoice Info',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge!
                                                      .copyWith(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildInfoRow(
                                            'Invoice ID',
                                            invoiceDetails['name'],
                                          ),
                                          _buildInfoRow(
                                            'Customer',
                                            invoiceDetails['customer'],
                                          ),
                                          _buildInfoRow(
                                            'Customer Name',
                                            invoiceDetails['customer_name'],
                                          ),
                                          _buildInfoRow(
                                              'Status', invoiceDetails['status']),
                                          _buildInfoRow(
                                            'Posting Date',
                                            formatDate(
                                                invoiceDetails['posting_date']),
                                          ),
                                          // Add address
                                          _buildInfoRow(
                                            'Address',
                                            removeHtmlTags(invoiceDetails[
                                                'address_display']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Financial Info Section
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Financial Info',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge!
                                                .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                          ),
                                          const SizedBox(height: 12),
                                          _buildInfoRow(
                                            'Grand Total',
                                            '${invoiceDetails['grand_total']} ${invoiceDetails['currency']}',
                                          ),
                                          _buildInfoRow(
                                            'Net Total',
                                            '${invoiceDetails['net_total']} ${invoiceDetails['currency']}',
                                          ),
                                          _buildInfoRow(
                                            'Base Grand Total',
                                            '${invoiceDetails['base_grand_total']} ${invoiceDetails['currency']}',
                                          ),
                                          _buildInfoRow(
                                            'Base Net Total',
                                            '${invoiceDetails['base_net_total']} ${invoiceDetails['currency']}',
                                          ),
                                          _buildInfoRow(
                                            'Total Taxes and Charges',
                                            '${invoiceDetails['total_taxes_and_charges']} ${invoiceDetails['currency']}',
                                          ),
                                          _buildInfoRow(
                                            'Payment Terms',
                                            invoiceDetails[
                                                'payment_terms_template'],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // *** NEW ITEMS SECTION ***
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Items', // Title for the new section
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge!
                                                .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (items.isEmpty)
                                            Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                  'No items found in this invoice.',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ),
                                            )
                                          else
                                            ListView.builder(
                                              // Use ListView.builder to display all items
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: items.length,
                                              itemBuilder: (context, index) {
                                                final item = items[index]
                                                    as Map<String, dynamic>;
                                                return _buildItemCard(
                                                  item,
                                                  invoiceDetails['currency'] ??
                                                      'INR',
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // *** END OF NEW ITEMS SECTION ***
                                ],
                              ),
                            ),
            ),
          ),
          // PDF Downloading Overlay
          if (_isDownloadingPdf)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Generating PDF...',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
