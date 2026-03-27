import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


class CustomerListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const CustomerListScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<dynamic> _customers = [];
  List<dynamic> _filteredCustomers = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  // Define unique colors for each of the 26 English letters (blue-centric)
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
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _parseError(dynamic error) {
    String errorString = error.toString();
    try {
      int jsonStartIndex = errorString.indexOf('{');
      if (jsonStartIndex != -1) {
        final jsonPart = errorString.substring(jsonStartIndex);
        final decoded = json.decode(jsonPart);
        if (decoded['message'] is Map &&
            decoded['message']['message'] is String) {
          return decoded['message']['message'];
        }
        if (decoded['exc_type']?.toString().contains('PermissionError') ==
                true ||
            decoded['_error_message']?.toString().contains('No permission') ==
                true) {
          return 'Permission Denied: You do not have access to this resource.';
        }
        if (decoded['_server_messages'] != null) {
          final serverMessageJson = json.decode(decoded['_server_messages'])[0];
          final serverMessage = json.decode(serverMessageJson);
          String message = serverMessage['message'] ?? 'An error occurred.';
          final htmlTagRegex = RegExp(r'<[^>]*>');
          return message.replaceAll(htmlTagRegex, '');
        }
      }
    } catch (_) {}
    if (errorString.contains('SocketException') ||
        errorString.contains('TimeoutException') ||
        errorString.contains('HandshakeException')) {
      return 'Network Error: Please check your connection and try again.';
    }
    if (errorString.contains('403')) {
      return 'Permission Denied: You do not have access to this resource.';
    }
    if (errorString.contains('404')) {
      return 'Error: The requested resource was not found on the server.';
    }
    if (errorString.contains('500')) {
      return 'Server Error: An issue occurred on the server. Please try again later.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> _fetchCustomers() async {
    final url =
        '${widget.serverUrl}/api/resource/Customer?fields=["name","customer_name","customer_type","customer_group","territory"]&limit_page_length=0';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          setState(() {
            _customers = List.from(data['data'] ?? []);
            _customers.sort(
              (a, b) => (a['customer_name'] ?? '').toLowerCase().compareTo(
                (b['customer_name'] ?? '').toLowerCase(),
              ),
            );
            _filteredCustomers = List.from(_customers);
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          throw Exception(response.body);
        }
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = _parseError(error);
      });
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      _filteredCustomers = query.isEmpty
          ? List.from(_customers)
          : _customers
                .where(
                  (c) => (c['customer_name'] ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .toList();
      _filteredCustomers.sort(
        (a, b) => (a['customer_name'] ?? '').toLowerCase().compareTo(
          (b['customer_name'] ?? '').toLowerCase(),
        ),
      );
    });
  }

  // Location update methods removed for standard compatibility.

  void _showCustomerDetailsDialog(
    BuildContext context,
    Map<String, dynamic> customer,
  ) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            customer['customer_name'] ?? 'Customer Details',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Customer Name', customer['customer_name']),
                _buildInfoRow('Customer Type', customer['customer_type']),
                _buildInfoRow('Customer Group', customer['customer_group']),
                _buildInfoRow('Territory', customer['territory']),

                const SizedBox(height: 16),
                const Center(
                  child: Text('Location features removed for standard compatibility.'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/customerDetail',
                  arguments: {
                    'customer': customer,
                    'serverUrl': widget.serverUrl,
                    'sid': widget.sid,
                  },
                );
              },
              child: Text(
                'Details',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Generate avatar text from the first letter of each word (up to two letters)
  String _getAvatarText(String name) {
    if (name.isEmpty) return 'N';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      // Take first letter of first two words (e.g., "Th Apt" -> "TA")
      return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
    }
    // Single word: take first letter (e.g., "Customer" -> "C")
    return name[0].toUpperCase();
  }

  // Get avatar color based on the first letter of the name
  Color _getAvatarColor(String name) {
    if (name.isEmpty)
      return _letterColors['N'] ?? Theme.of(context).colorScheme.primary;
    return _letterColors[name[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Customer List',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
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
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/addNewCustomer',
                arguments: {
                  'serverUrl': widget.serverUrl,
                  'sid': widget.sid,
                  'email': widget.email,
                },
              );
            },
            tooltip: 'Add New Customer',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Container(
              //   padding: const EdgeInsets.all(16.0),
              //   decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(12),
              //     color: Theme.of(context).colorScheme.surface,
              //     boxShadow: [
              //       BoxShadow(
              //         color: Colors.black.withOpacity(0.1),
              //         blurRadius: 10,
              //         offset: const Offset(0, 4),
              //       ),
              //     ],
              //   ),
              //   // child: Text(
              //   //   'Customer Hub',
              //   //   style: Theme.of(context).textTheme.titleLarge!.copyWith(
              //   //     color: Theme.of(context).colorScheme.primary,
              //   //     fontWeight: FontWeight.bold,
              //   //     fontSize: 22,
              //   //   ),
              //   //   textAlign: TextAlign.center,
              //   // ),
              // ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: _filterCustomers,
                decoration: InputDecoration(
                  hintText: 'Enter customer name',
                  hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                    fontSize: 18,
                                  ),
                            ),
                          ),
                        )
                      : _filteredCustomers.isEmpty
                      ? Center(
                          child: Text(
                            'No customers available',
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground,
                                  fontSize: 18,
                                ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (ctx, index) {
                            final customer = _filteredCustomers[index];
                            final avatarText = _getAvatarText(
                              customer['customer_name'] ?? 'N',
                            );
                            final avatarColor = _getAvatarColor(
                              customer['customer_name'] ?? 'N',
                            );

                            return Card(
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(
                                vertical: 12,
                              ), // Increased spacing
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: avatarColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      avatarText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            18, // Adjusted for multi-letter display
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    customer['customer_name'] ?? 'No name',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontSize:
                                              18, // Increased for readability
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    customer['customer_group'] ?? 'No Group',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onBackground
                                              .withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Icon(
                                    Icons.info_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  onTap: () => _showCustomerDetailsDialog(
                                    context,
                                    customer,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
