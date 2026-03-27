import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:erp_mobile/services/api_client.dart';
import 'package:erp_mobile/services/api_service.dart';

class CreateSalesOrderScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  const CreateSalesOrderScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CreateSalesOrderScreenState createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends State<CreateSalesOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _series;
  final TextEditingController _transactionDateController =
      TextEditingController();
  String? _customer;
  String? _orderType = 'Sales';
  String? _costCenter;
  String? _salesPerson;
  final TextEditingController _poNoController = TextEditingController();
  final TextEditingController _poDateController = TextEditingController();

  // --- Focus Nodes for main form fields ---
  late FocusNode _poNoFocusNode;
  late FocusNode _poDateFocusNode;

  final List<Map<String, dynamic>> _items = [];
  List<String> seriesList = [];
  List<String> customerList = [];
  List<Map<String, dynamic>> itemList = [];
  List<String> costCenterList = [];
  List<String> salesPersonList = [];

  List<Map<String, dynamic>> _taxTemplates = [];
  List<Map<String, dynamic>> _taxesAndCharges = [];
  String? _selectedTaxTemplateName;

  bool isLoading = false;
  String? _existingSalesOrderId; // Track created order ID for updates

  final Map<String, Color> _letterColors = {
    'A': const Color(0xFF0074c9),
    'B': const Color(0xFF005B99),
    'C': const Color(0xFF003087),
    'D': const Color(0xFF1E90FF),
    'E': const Color(0xFF4682B4),
    'F': const Color(0xFF6495ED),
    'G': const Color(0xFF00B7EB),
    'H': const Color(0xFF4169E1),
    'I': const Color(0xFF87CEEB),
    'J': const Color(0xFF1C86EE),
    'K': const Color(0xFF104E8B),
    'L': const Color(0xFF63B8FF),
    'M': const Color(0xFF00CED1),
    'N': const Color(0xFF5CACEE),
    'O': const Color(0xFF1874CD),
    'P': const Color(0xFF7B68EE),
    'Q': const Color(0xFF8470FF),
    'R': const Color(0xFF6A5ACD),
    'S': const Color(0xFF483D8B),
    'T': const Color(0xFF00BFFF),
    'U': const Color(0xFF20B2AA),
    'V': const Color(0xFF3A5FCD),
    'W': const Color(0xFF4A708B),
    'X': const Color(0xFF607B8B),
    'Y': const Color(0xFF7A67EE),
    'Z': const Color(0xFF1034A6),
  };

  @override
  void initState() {
    super.initState();
    _transactionDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());

    // Initialize FocusNodes
    _poNoFocusNode = FocusNode();
    _poDateFocusNode = FocusNode();

    // Add one initial item row
    _addItemRow(isInitial: true);

    fetchNamingSeries();
    fetchCustomers();
    fetchItems();
    fetchCostCenters();
    fetchSalesPersons();
    fetchSalesTaxesTemplates();
  }

  @override
  void dispose() {
    _transactionDateController.dispose();
    _poNoController.dispose();
    _poDateController.dispose();

    // Dispose main form FocusNodes
    _poNoFocusNode.dispose();
    _poDateFocusNode.dispose();

    // Dispose all controllers and FocusNodes in the _items list
    for (var item in _items) {
      item['deliveryDate'].dispose();
      item['qty'].dispose();
      item['rateController'].dispose();
      item['qtyFocusNode'].dispose();
      item['rateFocusNode'].dispose();
    }
    super.dispose();
  }

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
      return "Invalid date format: Please ensure dates are valid and in the correct format (e.g., YYYY-MM-DD). $cleanMessage";
    }
    if (cleanMessage.contains('LinkValidationError')) {
      return "Invalid reference: One or more linked fields (e.g., Customer, Cost Center) do not exist in ERPNext. $cleanMessage";
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

  Future<void> fetchNamingSeries() async {
    final url = '${widget.serverUrl}/api/resource/DocType/Sales Order';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fields = data['data']['fields'] as List;
        final nsField = fields.firstWhere(
          (f) => f['fieldname'] == 'naming_series',
          orElse: () => null,
        );
        if (nsField != null && nsField['options'] != null) {
          setState(() {
            seriesList = (nsField['options'] as String)
                .split('\n')
                .where((s) => s.isNotEmpty)
                .toList();
            _series = seriesList.isNotEmpty ? seriesList[0] : null;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(context, message: e.toString());
    }
  }

  Future<void> fetchCustomers() async {
    final url =
        '${widget.serverUrl}/api/resource/Customer?fields=["name","customer_name"]&limit_page_length=200';
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
          customerList = List<String>.from(
            (data['data'] ?? []).map((item) => item['name']),
          );
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e is http.Response ? e.body : e.toString(),
      );
    }
  }

  Future<void> fetchItems() async {
    final url =
        '${widget.serverUrl}/api/resource/Item?fields=["name","item_name","uom"]&limit_page_length=200';
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
          itemList = (data['data'] as List).map<Map<String, dynamic>>((item) => {
            'item_code': item['name'],
            'item_name': item['item_name'],
            'uom': item['uom'],
            'latest_price': {'price_list_rate': 0.0, 'currency': 'INR'},
          }).toList();
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e is http.Response ? e.body : e.toString(),
      );
    }
  }

  Future<void> fetchCostCenters() async {
    final url =
        '${widget.serverUrl}/api/resource/Cost Center?fields=["name"]&limit_page_length=100';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final loadedCostCenters = List<String>.from(
          (data['data'] ?? []).map((item) => item['name']),
        );

        String? defaultCostCenter = loadedCostCenters.isNotEmpty
            ? loadedCostCenters[0]
            : null;

        try {
          final userCC = await ApiService.getUserCostCenter(
            widget.serverUrl,
            widget.sid,
          );
          if (userCC != null && userCC.isNotEmpty) {
            defaultCostCenter = userCC;
            if (!loadedCostCenters.contains(userCC)) {
              loadedCostCenters.add(userCC);
            }
          }
        } catch (e) {
          debugPrint("Failed to fetch user cost center: $e");
        }

        setState(() {
          costCenterList = loadedCostCenters;
          _costCenter = defaultCostCenter;
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e is http.Response ? e.body : e.toString(),
      );
    }
  }

  Future<void> fetchSalesPersons() async {
    final url =
        '${widget.serverUrl}/api/resource/Sales Person?fields=["name"]&limit_page_length=100';
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
          salesPersonList = List<String>.from(
            (data['data'] ?? []).map((item) => item['name']),
          );
          if (salesPersonList.isNotEmpty) _salesPerson = salesPersonList[0];
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e is http.Response ? e.body : e.toString(),
      );
    }
  }

  Future<void> fetchSalesTaxesTemplates() async {
    final url =
        '${widget.serverUrl}/api/resource/Sales Taxes and Charges Template?fields=["name","title","taxes_and_charges"]&limit_page_length=100';
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
          _taxTemplates = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e is http.Response ? e.body : e.toString(),
      );
    }
  }

  Future<void> fetchLast10Sales(String itemCode, int index) async {
    if (_customer == null) {
      showErrorDialog(context, 'Error', 'Please select a customer first.');
      return;
    }

    final url =
        '${widget.serverUrl}/api/resource/Sales Order Item?fields=["rate","transaction_date"]&filters=[["item_code","=","$itemCode"],["customer","=","$_customer"]]&order_by=transaction_date desc&limit_page_length=10';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> rawSalesHistory = data['data'] ?? [];
        final priceHistory = rawSalesHistory.map<Map<String, dynamic>>((sale) => {
          'rate': (sale['rate'] as num? ?? 0).toDouble(),
          'date': sale['transaction_date'] as String? ?? '',
        }).toList();
        priceHistory.sort((a, b) => b['date'].compareTo(a['date']));

        if (!mounted) return;
        setState(() {
          final item = _items[index];
          item['priceHistory'] = priceHistory;
          item['rate'] = priceHistory.isNotEmpty ? priceHistory.first['rate'] : 0.0;
          item['rateController'].text = item['rate'].toStringAsFixed(2);
          final qty = double.tryParse(item['qty'].text) ?? 1.0;
          item['amount'] = qty * item['rate'];
        });
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e is http.Response ? e.body : e.toString(),
      );
    }
  }

  Future<String?> _showSearchableDropdown({
    required BuildContext context,
    required String title,
    required List<String> items,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = items
                .where(
                  (item) =>
                      item.toLowerCase().contains(searchQuery.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setDialogState(() => searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return ListTile(
                            title: Text(item),
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitDraftOrder(String salesOrderId) async {
    setState(() => isLoading = true);
    final url = "${widget.serverUrl}/api/resource/Sales Order/$salesOrderId";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
    };
    final body = json.encode({'docstatus': 1});

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          showErrorDialog(
            context,
            'Success',
            'Sales Order $salesOrderId submitted successfully!',
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(
          context,
          statusCode: e is http.Response ? e.statusCode : null,
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _createSalesOrder({bool submitImmediately = false}) async {
    if (!_formKey.currentState!.validate()) {
      showErrorDialog(
        context,
        'Form Error',
        'Please fix the errors in the form.',
      );
      return;
    }
    setState(() => isLoading = true);

    // Determine method and URL based on whether we are creating or updating
    final isUpdate = _existingSalesOrderId != null;
    final url = isUpdate
        ? "${widget.serverUrl}/api/resource/Sales Order/$_existingSalesOrderId"
        : "${widget.serverUrl}/api/resource/Sales Order";

    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final items = _items.map((item) {
      return {
        "item_code": item['itemCode'],
        "item_name": item['itemName'],
        "delivery_date": item['deliveryDate'].text,
        "qty": double.tryParse(item['qty'].text) ?? 0.0,
        "uom": item['uom'],
        "rate": item['rate'],
        "amount": item['amount'],
      };
    }).toList();
    final salesTeam = _salesPerson != null
        ? [
            {"sales_person": _salesPerson, "allocated_percentage": 100.00},
          ]
        : [];

    _calculateAndApplyTaxes(getNetTotal());

    final Map<String, dynamic> data = {
      "naming_series": _series,
      "transaction_date": _transactionDateController.text,
      "customer": _customer,
      "order_type": _orderType,
      "po_no": _poNoController.text.isNotEmpty ? _poNoController.text : null,
      "po_date": _poDateController.text.isNotEmpty
          ? _poDateController.text
          : null,
      "items": items,
      "taxes_and_charges": _selectedTaxTemplateName,
      "taxes": _taxesAndCharges,
      "company": "VPS Businesssolution",
      "currency": "INR",
      "selling_price_list": "CLARITY CRYSTAL PHOTO STUDIO - BRANCH",
      "cost_center": _costCenter,
      // "status": "Draft", // Status is managed by docstatus
      "sales_team": salesTeam,
    };

    // Only send docstatus 1 if submitting immediately, otherwise 0 (Draft)
    // Actually, for creation, default is 0.
    // If update, we don't send status unless we want to submit.
    // If submitImmediately is true, we will handle submission in a subsequent call if creating,
    // or just rely on _submitDraftOrder.
    // Standard ERPNext: Creates as Draft (0). Submit is a separate state change (1).

    // So logic:
    // 1. Create/Update as Draft.
    // 2. If success:
    //    If submitImmediately -> Call submit.
    //    Else -> Show dialog.

    final body = jsonEncode(data);
    try {
      final response = isUpdate
          ? await ApiClient.put(Uri.parse(url), headers: headers, body: body)
          : await ApiClient.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final savedName = responseData['data']['name'];

        if (!mounted) return;

        setState(() {
          _existingSalesOrderId = savedName;
        });

        if (submitImmediately) {
          await _submitDraftOrder(savedName);
          return;
        }

        // Show Success Options Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved Successfully',
                    style: TextStyle(color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales Order $savedName has been saved as Draft.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('What would you like to do next?'),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0.0,
                  vertical: 8.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.grey.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Edit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _submitDraftOrder(savedName);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Submit'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        throw http.Response(response.body, response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      showApiErrorDialog(
        context,
        statusCode: e is http.Response ? e.statusCode : null,
        message: e is http.Response ? e.body : e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onBackground,
            ),
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addItemRow({bool isInitial = false}) {
    setState(() {
      for (var item in _items) {
        item['isExpanded'] = false;
      }
      _items.add({
        'itemCode': null,
        'itemName': null,
        'deliveryDate': TextEditingController(
          text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        ),
        'qty': TextEditingController(),
        'uom': null,
        'rate': 0.0,
        'rateController': TextEditingController(text: '0.00'),
        'priceHistory': <Map<String, dynamic>>[],
        'amount': 0.0,
        'isExpanded': true,
        'qtyFocusNode': FocusNode(), // Add FocusNode for quantity
        'rateFocusNode': FocusNode(), // Add FocusNode for rate
      });
    });

    if (!isInitial) {
      // If we are adding a new row, request focus for its quantity field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _items.isNotEmpty) {
          FocusScope.of(context).requestFocus(_items.last['qtyFocusNode']);
        }
      });
    }
  }

  void _removeItemRow(int index) {
    setState(() {
      if (_items.length > 1) {
        // Dispose controllers and FocusNodes before removing
        _items[index]['deliveryDate'].dispose();
        _items[index]['qty'].dispose();
        _items[index]['rateController'].dispose();
        _items[index]['qtyFocusNode'].dispose();
        _items[index]['rateFocusNode'].dispose();

        _items.removeAt(index);
      }
    });
  }

  double getTotalQuantity() {
    return _items.fold(
      0.0,
      (sum, item) => sum + (double.tryParse(item['qty'].text) ?? 0.0),
    );
  }

  double getNetTotal() {
    return _items.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  double _calculateAndApplyTaxes(double netTotal) {
    double totalTaxAmount = 0;
    if (_taxesAndCharges.isNotEmpty) {
      for (var tax in _taxesAndCharges) {
        if (tax['charge_type'] == 'On Net Total') {
          final rate = (tax['rate'] as num?)?.toDouble() ?? 0.0;
          final taxAmount = (netTotal * rate) / 100.0;
          tax['tax_amount'] = taxAmount;
          tax['total'] = taxAmount;
          totalTaxAmount += taxAmount;
        }
      }
    }
    return totalTaxAmount;
  }

  String _getAvatarText(String? customer) {
    if (customer != null && customer.isNotEmpty) {
      final words = customer.trim().split(RegExp(r'\s+'));
      if (words.length >= 2) {
        return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
      }
      return customer[0].toUpperCase();
    }
    return 'N';
  }

  Color _getAvatarColor(String? customer) {
    // MODIFIED: Changed return type from String to Color
    if (customer == null || customer.isEmpty)
      return _letterColors['N'] ?? Theme.of(context).colorScheme.primary;
    return _letterColors[customer[0].toUpperCase()] ??
        Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final avatarText = _getAvatarText(_customer);
    final avatarColor = _getAvatarColor(_customer);

    final netTotal = getNetTotal();
    final totalTaxes = _calculateAndApplyTaxes(netTotal);
    final grandTotal = netTotal + totalTaxes;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Create Sales Order',
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
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                            'Sales Order Info',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                          'Naming Series',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          value: _series,
                          items: seriesList,
                          onChanged: (value) => setState(() => _series = value),
                          validator: (value) => value == null
                              ? 'Please select a naming series'
                              : null,
                          icon: Icons.format_list_numbered,
                        ),
                      ],
                    ),
                  ),
                ),
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
                          'Transaction Date',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _transactionDateController,
                          icon: Icons.calendar_today,
                          readOnly: true,
                          onTap: () =>
                              _selectDate(context, _transactionDateController),
                          validator: (value) =>
                              value!.isEmpty ? 'Please select a date' : null,
                        ),
                      ],
                    ),
                  ),
                ),
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
                    child: _buildSearchableDropdownField(
                      label: 'Customer',
                      value: _customer,
                      items: customerList,
                      onChanged: (value) => setState(() {
                        _customer = value;
                      }),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please select a customer'
                          : null,
                      icon: Icons.person,
                    ),
                  ),
                ),
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
                          'Order Type',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          value: _orderType,
                          items: ['Sales', 'Maintenance', 'Shopping Cart'],
                          onChanged: (value) =>
                              setState(() => _orderType = value),
                          validator: (value) => value == null
                              ? 'Please select an order type'
                              : null,
                          icon: Icons.category,
                        ),
                      ],
                    ),
                  ),
                ),
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
                          'Purchase Order Details',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _poNoController,
                          icon: Icons.receipt,
                          onChanged: (value) => setState(() {}),
                          // --- Add FocusNode, TextInputAction, onEditingComplete ---
                          focusNode: _poNoFocusNode,
                          textInputAction: TextInputAction.next,
                          onEditingComplete: () {
                            if (_poNoController.text.isNotEmpty) {
                              // If PO No is filled, move to PO Date
                              FocusScope.of(
                                context,
                              ).requestFocus(_poDateFocusNode);
                            } else {
                              // If PO No is empty, skip to first item's quantity
                              if (_items.isNotEmpty) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_items[0]['qtyFocusNode']);
                              }
                            }
                          },
                        ),
                        if (_poNoController.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _poDateController,
                            icon: Icons.calendar_today,
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, _poDateController),
                            // --- Add FocusNode, TextInputAction, onEditingComplete ---
                            // Note: Date pickers don't use keyboard, so these are
                            // for when focus lands here from PO No.
                            focusNode: _poDateFocusNode,
                            onEditingComplete: () {
                              if (_items.isNotEmpty) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_items[0]['qtyFocusNode']);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
                    child: _buildSearchableDropdownField(
                      label: 'Cost Center',
                      value: _costCenter,
                      items: costCenterList,
                      onChanged: (value) => setState(() => _costCenter = value),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please select a cost center'
                          : null,
                      icon: Icons.account_balance,
                    ),
                  ),
                ),
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
                    child: _buildSearchableDropdownField(
                      label: 'Sales Person',
                      value: _salesPerson,
                      items: salesPersonList,
                      onChanged: (value) =>
                          setState(() => _salesPerson = value),
                      icon: Icons.person_outline,
                    ),
                  ),
                ),
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
                          'Items',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildItemsList(context),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _addItemRow(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Item'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- TAXES AND CHARGES SECTION ---
                _buildTaxesSection(),

                // --- TOTALS SECTION ---
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
                          'Totals',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildTotalRow(
                          'Total Quantity',
                          getTotalQuantity().toStringAsFixed(3),
                        ),
                        const Divider(),
                        _buildTotalRow(
                          'Net Total',
                          'INR ${netTotal.toStringAsFixed(2)}',
                        ),
                        const Divider(),
                        _buildTotalRow(
                          'Taxes and Charges',
                          'INR ${totalTaxes.toStringAsFixed(2)}',
                        ),
                        const Divider(),
                        _buildTotalRow(
                          'Grand Total',
                          'INR ${grandTotal.toStringAsFixed(2)}',
                          isGrandTotal: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => _createSalesOrder(submitImmediately: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: isLoading ? 2 : 4,
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                _existingSalesOrderId == null
                                    ? 'Save (Draft)'
                                    : 'Update (Draft)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => _createSalesOrder(submitImmediately: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: isLoading ? 2 : 4,
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Save & Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // MODIFICATION: Removed FloatingActionButton
    );
  }

  Widget _buildTaxesSection() {
    return Container(
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
              'Taxes and Charges',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTaxTemplateName,
              items: _taxTemplates.map((template) {
                return DropdownMenuItem<String>(
                  value: template['template_name'],
                  child: Text(template['title'] ?? template['template_name']),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedTaxTemplateName = newValue;
                  if (newValue == null) {
                    _taxesAndCharges.clear();
                  } else {
                    final selectedTemplate = _taxTemplates.firstWhere(
                      (t) => t['template_name'] == newValue,
                    );
                    _taxesAndCharges = List<Map<String, dynamic>>.from(
                      selectedTemplate['taxes'] ?? [],
                    );
                  }
                });
              },
              decoration: InputDecoration(
                labelText: 'Select Tax Template',
                prefixIcon: Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              isExpanded: true,
            ),
            if (_taxesAndCharges.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._taxesAndCharges.map((tax) {
                return ListTile(
                  title: Text(tax['description'] ?? 'No description'),
                  subtitle: Text('${tax['account_head']} @ ${tax['rate']}%'),
                  trailing: Text(
                    'INR ${(tax['tax_amount'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isGrandTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
              color: isGrandTotal
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onBackground,
              fontSize: isGrandTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    FocusNode? focusNode, // Added
    TextInputAction? textInputAction, // Added
    VoidCallback? onEditingComplete, // Added
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller == _transactionDateController
              ? "Transaction Date"
              : controller == _poNoController
              ? "Customer's Purchase Order (PO No)"
              : "Customer's Purchase Order Date",
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            focusNode: focusNode, // Assign FocusNode
            textInputAction: textInputAction, // Assign TextInputAction
            onEditingComplete: onEditingComplete, // Assign onEditingComplete
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 12,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              errorStyle: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value == _series ? 'Naming Series' : 'Order Type',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
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
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              errorStyle: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            validator: validator,
            style: Theme.of(context).textTheme.bodyMedium,
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
        FormField<String>(
          validator: validator,
          initialValue: value,
          builder: (FormFieldState<String> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final selectedValue = await _showSearchableDropdown(
                      context: context,
                      title: 'Select $label',
                      items: items,
                    );
                    if (selectedValue != null) {
                      onChanged?.call(selectedValue);
                      state.didChange(selectedValue);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: state.hasError
                          ? Border.all(
                              color: Theme.of(context).colorScheme.error,
                              width: 1,
                            )
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            value ?? 'Select',
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: value == null
                                      ? Colors.grey.shade600
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 8),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context) {
    return Column(
      children: _items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        /*
        // BUGGY BLOCK REMOVED
        if (item['rateController'].text.isEmpty ||
            double.tryParse(item['rateController'].text) != item['rate']) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                item['rateController'].text = item['rate'].toStringAsFixed(2);
              });
            }
          });
        }
        */

        final Map<double, String> uniqueRateMap = {};
        final List<Map<String, dynamic>> priceHistory = List.from(
          item['priceHistory'] ?? [],
        );

        for (var historyItem in priceHistory) {
          final rate = historyItem['rate'] as double;
          final dateString = historyItem['date'] as String;
          String formattedDate;
          try {
            final parsedDate = DateTime.parse(dateString);
            formattedDate = DateFormat('dd-MM-yyyy').format(parsedDate);
          } catch (e) {
            formattedDate = dateString;
          }

          if (!uniqueRateMap.containsKey(rate)) {
            uniqueRateMap[rate] = formattedDate;
          }
        }
        final rateItems = uniqueRateMap.keys.toList();
        rateItems.sort((a, b) => b.compareTo(a));

        if (item['rate'] != 0.0 && !rateItems.contains(item['rate'])) {
          rateItems.insert(0, item['rate']);
          uniqueRateMap[item['rate']] = 'Manual';
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  item['itemCode'] ?? 'Select Item',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item['itemCode'] == null
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount: INR ${item['amount'].toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item['qty'].text.isNotEmpty)
                      Text(
                        'Qty: ${item['qty'].text}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        item['isExpanded'] ? Icons.expand_less : Icons.edit,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          item['isExpanded'] = !item['isExpanded'];
                        });
                      },
                    ),
                    if (_items.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeItemRow(index),
                      ),
                  ],
                ),
              ),
              if (item['isExpanded'])
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormField<String>(
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select an item'
                            : null,
                        initialValue: item['itemCode'],
                        builder: (FormFieldState<String> state) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () async {
                                  final selectedValue =
                                      await _showSearchableDropdown(
                                        context: context,
                                        title: 'Select Item Code',
                                        items: itemList
                                            .map(
                                              (i) => i['item_code'] as String,
                                            )
                                            .toList(),
                                      );

                                  if (selectedValue != null) {
                                    state.didChange(selectedValue);
                                    final selectedItemData = itemList
                                        .firstWhere(
                                          (element) =>
                                              element['item_code'] ==
                                              selectedValue,
                                          orElse: () => {
                                            'item_name': 'Unknown',
                                            'uom': '',
                                          },
                                        );
                                    setState(() {
                                      final currentItem = _items[index];
                                      currentItem['itemCode'] = selectedValue;
                                      currentItem['itemName'] =
                                          selectedItemData['item_name'];
                                      currentItem['uom'] =
                                          selectedItemData['uom'];

                                      if (currentItem['qty'].text.isEmpty) {
                                        currentItem['qty'].text = '1.000';
                                      }
                                      currentItem['priceHistory'] = [];
                                      currentItem['rate'] = 0.0;
                                      currentItem['amount'] = 0.0;
                                      currentItem['rateController'].text =
                                          '0.00';

                                      fetchLast10Sales(selectedValue, index);
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: "Item Code",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 12,
                                    ),
                                    errorText: state.errorText,
                                  ),
                                  child: Text(
                                    item['itemCode'] ?? 'Select Item Code',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                          color: item['itemCode'] == null
                                              ? Colors.grey.shade600
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onBackground,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item['deliveryDate'],
                        decoration: InputDecoration(
                          labelText: 'Delivery Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context, item['deliveryDate']),
                        validator: (value) =>
                            value!.isEmpty ? 'Select a delivery date' : null,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item['qty'],
                        focusNode: item['qtyFocusNode'], // Assign FocusNode
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                        keyboardType: TextInputType
                            .phone, // MODIFIED: Use phone keyboard for iOS action button
                        validator: (value) =>
                            value!.isEmpty || double.tryParse(value) == null
                            ? 'Enter a valid quantity'
                            : null,
                        onChanged: (value) {
                          setState(() {
                            final qty = double.tryParse(value) ?? 0.0;
                            item['amount'] = qty * item['rate'];
                          });
                        },
                        // --- Add TextInputAction and onEditingComplete ---
                        textInputAction: TextInputAction.next,
                        onEditingComplete: () {
                          // Move focus to this item's rate
                          FocusScope.of(
                            context,
                          ).requestFocus(item['rateFocusNode']);
                        },
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<double>(
                            value:
                                rateItems.isNotEmpty &&
                                    rateItems.contains(item['rate'])
                                ? item['rate']
                                : rateItems.isNotEmpty
                                ? rateItems[0]
                                : null,
                            items: rateItems.map<DropdownMenuItem<double>>((
                              rate,
                            ) {
                              return DropdownMenuItem<double>(
                                value: rate,
                                child: Text(
                                  'INR ${rate.toStringAsFixed(2)} (${uniqueRateMap[rate]})',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: rateItems.isNotEmpty
                                ? (value) {
                                    setState(() {
                                      item['rate'] = value ?? rateItems[0];
                                      item['rateController'].text = item['rate']
                                          .toStringAsFixed(2);
                                      final qty =
                                          double.tryParse(item['qty'].text) ??
                                          0.0;
                                      item['amount'] = qty * item['rate'];
                                    });
                                  }
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Rate (INR)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                            isExpanded: true,
                            disabledHint: Text(
                              'No rates',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: item['rateController'],
                            focusNode:
                                item['rateFocusNode'], // Assign FocusNode
                            decoration: InputDecoration(
                              labelText: 'VPS Rate',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                            keyboardType: TextInputType
                                .phone, // MODIFIED: Use phone keyboard for iOS action button
                            validator: (value) =>
                                value!.isEmpty || double.tryParse(value) == null
                                ? 'Enter a valid rate'
                                : null,

                            // --- NEW: Added onChanged for instant calculation ---
                            onChanged: (value) {
                              setState(() {
                                final rate = double.tryParse(value) ?? 0.0;
                                item['rate'] = rate;
                                final qty =
                                    double.tryParse(item['qty'].text) ?? 0.0;
                                item['amount'] = qty * item['rate'];
                                // We don't format the text (like adding .00) here
                                // as it would interrupt typing.
                              });
                            },

                            // --- End of new onChanged ---
                            textInputAction:
                                // If this is the last item, show "done" (tick)
                                index == _items.length - 1
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onEditingComplete: () {
                              setState(() {
                                final rate =
                                    double.tryParse(
                                      item['rateController'].text,
                                    ) ??
                                    0.0;
                                item['rate'] = rate;
                                // Format the text *after* editing is complete
                                if (rate == rate.truncateToDouble()) {
                                  item['rateController'].text = rate
                                      .toStringAsFixed(2);
                                }
                                final qty =
                                    double.tryParse(item['qty'].text) ?? 0.0;
                                item['amount'] = qty * item['rate'];
                              });

                              // Logic to move focus
                              if (index == _items.length - 1) {
                                // Last item, so dismiss keyboard
                                FocusScope.of(context).unfocus();
                              } else {
                                // Not last item, move to next item's quantity
                                FocusScope.of(context).requestFocus(
                                  _items[index + 1]['qtyFocusNode'],
                                );
                              }
                            },
                            onTap: () {
                              item['rateController'].selection = TextSelection(
                                baseOffset: 0,
                                extentOffset:
                                    item['rateController'].text.length,
                              );
                            },
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
