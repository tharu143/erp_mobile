import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file_plus/open_file_plus.dart';
import 'package:erp_mobile/services/api_client.dart';

class AddNewCustomerScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const AddNewCustomerScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  _AddNewCustomerScreenState createState() => _AddNewCustomerScreenState();
}

class _AddNewCustomerScreenState extends State<AddNewCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController customerNameController = TextEditingController();
  String? selectedCustomerType = 'Company';
  final TextEditingController addressLine1Controller = TextEditingController();
  final TextEditingController addressLine2Controller = TextEditingController();
  final TextEditingController addressLine3Controller = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  String? selectedPhoneCode = '+971';
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactPersonNameController =
      TextEditingController();
  String? selectedAccountManager;
  String? selectedCountry = 'United Arab Emirates';
  List<File> attachedFiles = [];
  List<String> accountManagerEmails = [];
  bool isLoading = false;

  // Dropdown Lists
  final List<String> customerTypes = ['Company', 'Individual', 'Partnership'];
  final List<String> addressTypes = [
    'Billing',
    'Shipping',
    'Office',
    'Personal',
    'Plant',
    'Postal',
    'Shop',
    'Subsidiary',
    'Warehouse',
    'Current',
    'Permanent',
    'Other',
  ];
  final Map<String, String> countryISDCodes = {
    'United Arab Emirates': '+971',
    'India': '+91',
    'United States': '+1',
    'United Kingdom': '+44',
    'Australia': '+61',
  };
  final List<String> countries = [
    'United Arab Emirates',
    'India',
    'United States',
    'United Kingdom',
    'Australia',
  ];
  final List<String> emirates = [
    'Abu Dhabi',
    'Dubai',
    'Sharjah',
    'Ajman',
    'Umm Al-Quwain',
    'Ras Al Khaimah',
    'Fujairah',
  ];
  String? selectedEmirate = 'Dubai';

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
    fetchEmails();
    customerNameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    customerNameController.removeListener(() => setState(() {}));
    customerNameController.dispose();
    addressLine1Controller.dispose();
    addressLine2Controller.dispose();
    addressLine3Controller.dispose();
    cityController.dispose();
    phoneController.dispose();
    emailController.dispose();
    contactPersonNameController.dispose();
    super.dispose();
  }

  // Error handling utilities
  String _parseFrappeException(String responseBody) {
    try {
      final data = json.decode(responseBody);
      if (data['exception'] != null && data['exception'] is String) {
        List parts = data['exception'].split(':');
        if (parts.length > 1) {
          return parts.sublist(1).join(':').trim();
        }
        return data['exception'];
      }
      if (data['_server_messages'] != null) {
        final serverMessages = json.decode(data['_server_messages']);
        if (serverMessages is List && serverMessages.isNotEmpty) {
          return serverMessages
              .map((msg) => json.decode(msg)['message'].toString())
              .join('\n');
        }
      }
      if (data['message'] != null && data['message'] is String) {
        return data['message'];
      }
      return responseBody;
    } catch (e) {
      return responseBody;
    }
  }

  String _stripHtmlIfNeeded(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  String getUserFriendlyMessage(int statusCode, String message) {
    final cleanMessage = _stripHtmlIfNeeded(_parseFrappeException(message));
    if (cleanMessage.contains('Incorrect date value')) {
      return "Invalid date format: Please ensure dates are valid and in the correct format (e.g., DD-MM-YYYY). $cleanMessage";
    }
    switch (statusCode) {
      case 200:
        return "Success: $cleanMessage";
      case 400:
        return "Bad Request: Please check your input. $cleanMessage";
      case 401:
        return "Unauthorized: Please check your credentials or session. $cleanMessage";
      case 403:
        return "Forbidden: You do not have permission to perform this action. $cleanMessage";
      case 404:
        return "Not Found: The requested resource could not be found. $cleanMessage";
      case 409:
        return "Conflict: The resource already exists or there is a conflict. $cleanMessage";
      case 417:
        return "Expectation Failed: The server could not meet the expectation. $cleanMessage";
      case 422:
        return "Unprocessable Entity: Please check the data you provided. $cleanMessage";
      case 500:
        return "Internal Server Error: Something went wrong on the server. Please try again later. $cleanMessage";
      default:
        return "An unexpected error occurred (Status Code: $statusCode). $cleanMessage";
    }
  }

  void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: title == 'Success'
                ? Theme.of(context).colorScheme.secondary
                : Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          _stripHtmlIfNeeded(message),
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

  void showApiErrorDialog(
    BuildContext context, {
    int? statusCode,
    String message = "An unknown error occurred.",
  }) {
    String friendlyMessage;
    if (statusCode != null) {
      friendlyMessage = getUserFriendlyMessage(statusCode, message);
    } else {
      friendlyMessage = _stripHtmlIfNeeded(_parseFrappeException(message));
    }
    showErrorDialog(context, 'Error', friendlyMessage);
  }

  Future<void> fetchEmails() async {
    final url =
        "${widget.serverUrl}/api/resource/User?fields=[\"email\"]&filters=[[\"enabled\",\"=\",1]]";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body)['data'] ?? [];
        setState(() {
          accountManagerEmails = data
              .map((user) => user['email'] as String? ?? '')
              .toList();
          if (accountManagerEmails.contains(widget.email)) {
            selectedAccountManager = widget.email;
          }
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      print('Error fetching emails: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        attachedFiles.addAll(result.paths.map((path) => File(path!)).toList());
      });
    }
  }

  Future<void> _openFile(File file) async {
    try {
      await OpenFile.open(file.path);
    } catch (e) {
      print('Error opening file: $e');
      if (!mounted) return;
      showErrorDialog(
        context,
        'Error',
        'Could not find an app to open this file.',
      );
    }
  }

  Future<void> addNewCustomer() async {
    if (!_formKey.currentState!.validate()) {
      showErrorDialog(
        context,
        'Form Error',
        'Please fix the errors in the form.',
      );
      return;
    }

    setState(() => isLoading = true);
    final url = "${widget.serverUrl}/api/resource/Customer";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final customerData = {
      'customer_name': customerNameController.text.isNotEmpty
          ? customerNameController.text
          : 'Untitled',
      'customer_type': selectedCustomerType ?? 'Company',
      'account_manager': selectedAccountManager,
    }..removeWhere((key, value) => value == null || value == '');

    try {
      // Create customer
      final customerResponse = await ApiClient.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(customerData),
      );
      if (customerResponse.statusCode != 200 &&
          customerResponse.statusCode != 201) {
        throw http.Response(customerResponse.body, customerResponse.statusCode);
      }
      final customerId =
          json.decode(customerResponse.body)['data']['name'] ?? '';

      // Create address if applicable
      String? addressId;
      try {
        if (addressLine1Controller.text.isNotEmpty ||
            cityController.text.isNotEmpty) {
          addressId = await _createAddress(customerId);
        }
      } catch (e) {
        print('Error creating address: $e');
        if (!mounted) return;
        showApiErrorDialog(
          context,
          statusCode: e is http.Response ? e.statusCode : null,
          message: e.toString(),
        );
      }

      // Create contact if applicable
      String? contactId;
      try {
        if (phoneController.text.isNotEmpty ||
            emailController.text.isNotEmpty) {
          contactId = await _createContact(customerId);
        }
      } catch (e) {
        print('Error creating contact: $e');
        if (!mounted) return;
        showApiErrorDialog(
          context,
          statusCode: e is http.Response ? e.statusCode : null,
          message: e.toString(),
        );
      }

      // Update customer with address/contact links
      if (addressId != null || contactId != null) {
        final updateCustomerData = {
          'name': customerId,
          if (addressId != null) 'customer_primary_address': addressId,
          if (contactId != null) 'customer_primary_contact': contactId,
        };
        final updateResponse = await ApiClient.put(
          Uri.parse('$url/$customerId'),
          headers: headers,
          body: json.encode(updateCustomerData),
        );
        if (updateResponse.statusCode != 200) {
          throw http.Response(updateResponse.body, updateResponse.statusCode);
        }
      }

      // Upload attachments
      for (var file in attachedFiles) {
        try {
          await _uploadAttachment(customerId, file);
        } catch (e) {
          print('Error uploading attachment: $e');
          if (!mounted) return;
          showApiErrorDialog(
            context,
            statusCode: e is http.Response ? e.statusCode : null,
            message: e.toString(),
          );
        }
      }

      // Show success dialog and delay navigation
      if (!mounted) return;
      showErrorDialog(context, 'Success', 'Customer added successfully!');
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Ensure dialog is visible for 2 seconds
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      print('Error adding customer: $e');
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<String> _createAddress(String customerId) async {
    final url = "${widget.serverUrl}/api/resource/Address";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final addressData = {
      'address_title': customerNameController.text.isNotEmpty
          ? customerNameController.text
          : 'Untitled',
      'address_type': 'Billing',
      'address_line1': addressLine1Controller.text.isNotEmpty
          ? addressLine1Controller.text
          : null,
      'address_line2': addressLine2Controller.text.isNotEmpty
          ? addressLine2Controller.text
          : null,
      'address_line3': addressLine3Controller.text.isNotEmpty
          ? addressLine3Controller.text
          : null,
      'city': cityController.text.isNotEmpty ? cityController.text : null,
      'country': selectedCountry ?? 'United Arab Emirates',
      'state': selectedCountry == 'United Arab Emirates'
          ? (selectedEmirate ?? 'Dubai')
          : null,
      'links': [
        {'link_doctype': 'Customer', 'link_name': customerId},
      ],
    }..removeWhere((key, value) => value == null || value == '');

    final response = await ApiClient.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(addressData),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body)['data']['name'] ?? '';
    } else {
      throw http.Response(response.body, response.statusCode);
    }
  }

  Future<String> _createContact(String customerId) async {
    final url = "${widget.serverUrl}/api/resource/Contact";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final contactData = {
      'first_name': contactPersonNameController.text.isNotEmpty
          ? contactPersonNameController.text
          : customerNameController.text.isNotEmpty
          ? customerNameController.text
          : 'Unknown',
      'email_ids': emailController.text.isNotEmpty
          ? [
              {'email_id': emailController.text, 'is_primary': true},
            ]
          : [],
      'phone_nos': phoneController.text.isNotEmpty
          ? [
              {
                'phone': '$selectedPhoneCode${phoneController.text}',
                'is_primary_phone': true,
              },
            ]
          : [],
      'links': [
        {'link_doctype': 'Customer', 'link_name': customerId},
      ],
    };

    final response = await ApiClient.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(contactData),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body)['data']['name'] ?? '';
    } else {
      throw http.Response(response.body, response.statusCode);
    }
  }

  Future<void> _uploadAttachment(String customerId, File file) async {
    final url = "${widget.serverUrl}/api/method/upload_file";
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Cookie'] = 'sid=${widget.sid}'
      ..fields['doctype'] = 'Customer'
      ..fields['docname'] = customerId
      ..fields['is_private'] = '0'
      ..fields['folder'] = 'Home/Attachments'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.path.split('/').last,
        ),
      );

    final response = await request.send();
    await ApiClient.checkStatus(response.statusCode);
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw http.Response(responseBody, response.statusCode);
    }
  }

  // Generate avatar text from the first letter of each word (up to two letters)
  String _getAvatarText(String name) {
    if (name.isEmpty) return 'N';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
    }
    return name[0].toUpperCase();
  }

  // Get avatar color based on the first letter of the name
  Color _getAvatarColor(String name) {
    if (name.isEmpty)
      return _letterColors['N'] ?? Theme.of(context).colorScheme.primary;
    return _letterColors[name[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    void Function()? onTap,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            errorStyle: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 12,
            ),
          ),
          validator: validator,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            errorStyle: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 12,
            ),
          ),
          value: value,
          items: items.isEmpty
              ? [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Loading...'),
                  ),
                ]
              : items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
          onChanged: items.isEmpty ? null : onChanged,
          validator: validator,
          style: Theme.of(context).textTheme.bodyMedium,
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    int phoneLengthLimit = selectedCountry == 'United Arab Emirates' ? 9 : 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              flex: 2,
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                ),
                value: selectedPhoneCode,
                items: countryISDCodes.values
                    .toSet()
                    .toList()
                    .map(
                      (code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selectedPhoneCode = value),
                style: Theme.of(context).textTheme.bodyMedium,
                isExpanded: true,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 5,
              child: TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(phoneLengthLimit),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  errorStyle: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                ),
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      int.tryParse(value) == null) {
                    return 'Please enter only digits';
                  }
                  return null;
                },
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _pickFiles,
          icon: const Icon(Icons.attach_file),
          label: const Text('Pick Files'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        if (attachedFiles.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: attachedFiles.map((file) {
                return ListTile(
                  leading: Icon(
                    Icons.insert_drive_file,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    file.path.split('/').last,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.open_in_new,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _openFile(file),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarText = _getAvatarText(customerNameController.text);
    final avatarColor = _getAvatarColor(customerNameController.text);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Add New Customer',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surface,
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
                      child: Row(
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
                              'Customer Info',
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Customer Details Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surface,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Details',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: customerNameController,
                            label: 'Customer Name*',
                            icon: Icons.business,
                            validator: (value) =>
                                value!.isEmpty ? 'Enter customer name' : null,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            label: 'Customer Type*',
                            value: selectedCustomerType,
                            items: customerTypes,
                            onChanged: (value) =>
                                setState(() => selectedCustomerType = value),
                            validator: (value) =>
                                value == null ? 'Select a customer type' : null,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            label: 'Account Manager*',
                            value: selectedAccountManager,
                            items: accountManagerEmails,
                            onChanged: (value) =>
                                setState(() => selectedAccountManager = value),
                            validator: (value) => value == null
                                ? 'Select an account manager'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Address Info Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surface,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Address Info',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: addressLine1Controller,
                            label: 'Address Line 1',
                            icon: Icons.location_on,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: addressLine2Controller,
                            label: 'Address Line 2',
                            icon: Icons.location_on,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: addressLine3Controller,
                            label: 'Address Line 3',
                            icon: Icons.location_on,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: cityController,
                            label: 'City',
                            icon: Icons.location_city,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // Contact Info Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surface,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Info',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildPhoneField(),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: emailController,
                            label: 'Email',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  !RegExp(
                                    r'^[^@]+@[^@]+\.[^@]+',
                                  ).hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: contactPersonNameController,
                            label: 'Contact Person Name',
                            icon: Icons.person,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Attachments Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surface,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attachments',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildFilePicker(),
                        ],
                      ),
                    ),
                  ),
                  // Submit Button
                  ElevatedButton(
                    onPressed: isLoading ? null : addNewCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isLoading ? 2 : 4,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : const Text(
                            'Add Customer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
