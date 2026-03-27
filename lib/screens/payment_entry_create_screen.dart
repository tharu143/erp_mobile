import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http; // Removed unused
import 'package:erp_mobile/models/customer_model.dart';
import 'package:erp_mobile/models/outstanding_invoice_model.dart';
import 'package:erp_mobile/models/payment_entry_model.dart';
import 'package:erp_mobile/widgets/custom_dropdown.dart';
import 'package:erp_mobile/widgets/custom_text_field.dart';
import 'package:erp_mobile/models/payment_entry_reference_model.dart';
import 'package:erp_mobile/utils/global_keys.dart'; // Import global keys directly
import 'package:erp_mobile/services/api_client.dart'; // Import ApiClient

class PaymentEntryCreateScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String company;

  const PaymentEntryCreateScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.company,
  }) : super(key: key);

  @override
  State<PaymentEntryCreateScreen> createState() =>
      _PaymentEntryCreateScreenState();
}

class _PaymentEntryCreateScreenState extends State<PaymentEntryCreateScreen> {
  // --- Controllers ---
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _referenceNoController = TextEditingController();
  final TextEditingController _referenceDateController =
      TextEditingController();
  final Map<String, TextEditingController> _allocationControllers = {};

  // --- State Variables ---
  String? _selectedPartyType = 'Customer';
  Customer? _selectedCustomer;
  String? _selectedNamingSeries;
  String? _selectedCostCenter;
  String? _selectedPaidToAccount;
  String? _selectedModeOfPayment;
  String _partyAccount = '';
  List<Customer> _customers = [];
  List<OutstandingInvoice> _outstandingInvoices = [];
  List<PaymentEntryReference> _selectedReferences = [];
  List<String> _accountOptions = [];
  bool _isLoading = true;
  bool _isFetchingInvoices = false;
  String? _errorMessage;
  bool _isBankAccount = false;

  // --- Options ---
  final List<String> _modeOfPaymentOptions = ['Cash', 'PDC Receive'];
  final List<String> _namingSeriesOptions = ['ACC-PAY-.YYYY.-'];
  List<String> _costCenterOptions = [];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() {
    _fetchCustomers();
    _fetchNamingSeries();
    _fetchCostCenters().then((_) {
      if (mounted) _fetchDefaults();
    });
    _fetchPaymentAccounts().then((_) {
      if (mounted) _updatePaymentAccountForMode(_selectedModeOfPayment);
    });
    _fromDateController.text = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .split('T')[0];
    _toDateController.text = DateTime.now().toIso8601String().split('T')[0];
    _referenceDateController.text = DateTime.now().toIso8601String().split(
      'T',
    )[0];
    _selectedModeOfPayment = _modeOfPaymentOptions.first;
  }

  Future<void> _fetchDefaults() async {
    // Standard ERPNext doesn't have a simple "get_user_cost_center" without custom app, 
    // but we can try to get it from the User document or just use a default list.
    // For now, we'll rely on the _fetchCostCenters results.
  }

  void _updatePaymentAccountForMode(String? mode) {
    if (mode == 'Cash') {
      _setPaymentAccount('Cash - VPS');
    } else if (mode == 'PDC Receive') {
      _setPaymentAccount('PDC Received - VPS');
    }
  }

  void _setPaymentAccount(String accountName) {
    if (mounted) {
      setState(() {
        if (!_accountOptions.contains(accountName)) {
          _accountOptions.add(accountName);
        }
        _selectedPaidToAccount = accountName;
        _isBankAccount = accountName.toLowerCase().contains('bank');
      });
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
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  // --- Data Fetching Methods ---

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = '${widget.serverUrl}/api/resource/Customer?fields=["name","customer_name"]&limit_page_length=0';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          if (!mounted) return;
          setState(() {
            _customers =
                (data['data'] as List<dynamic>?)
                    ?.map<Customer>((json) => Customer.fromJson(json))
                    .toList() ??
                [];
            _customers.sort(
              (a, b) => (a.customerName ?? '').toLowerCase().compareTo(
                (b.customerName ?? '').toLowerCase(),
              ),
            );
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      debugPrint('Error in _fetchCustomers: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error fetching customers: $_errorMessage')),
        );
      }
    }
  }

  Future<void> _fetchPartyDetails(String partyName) async {
    final url =
        '${widget.serverUrl}/api/method/erpnext.accounts.doctype.payment_entry.payment_entry.get_party_details';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode({
      'company': widget.company,
      'party_type': 'Customer',
      'party': partyName,
      'date': DateTime.now().toIso8601String().split('T')[0],
    });

    try {
      final response = await ApiClient.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && mounted) {
          setState(() {
            _partyAccount = data['message']['party_account'] ?? '';
          });
        }
      } else {
        debugPrint('Failed to fetch party details: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error in _fetchPartyDetails: $error');
    }
  }

  Future<void> _fetchPaymentAccounts() async {
    final url =
        '${widget.serverUrl}/api/resource/Account?fields=["name","account_type"]&filters=[["account_type","in","Bank,Cash"],["is_group","=","0"]]';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _accountOptions =
                (data['data'] as List<dynamic>?)
                    ?.map<String>((item) => item['name'] as String)
                    .toList() ??
                [];
            if (_accountOptions.isNotEmpty) {
              _selectedPaidToAccount = _accountOptions.first;
              _isBankAccount =
                  (data['data'] as List<dynamic>?)?.firstWhere(
                    (item) => item['name'] == _selectedPaidToAccount,
                    orElse: () => {},
                  )['account_type'] ==
                  'Bank';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error in _fetchPaymentAccounts: $e');
      if (mounted) {
        setState(() {
          _accountOptions.add('Cash - VPS');
          _selectedPaidToAccount = _accountOptions.first;
          _isBankAccount = false;
        });
      }
    }
  }

  Future<void> _fetchNamingSeries() async {
    if (mounted) {
      setState(() {
        _selectedNamingSeries = _namingSeriesOptions.first;
      });
    }
  }

  Future<void> _fetchCostCenters() async {
    final url =
        '${widget.serverUrl}/api/resource/Cost Center?fields=["name"]&filters=[["is_group","=","0"]]';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _costCenterOptions =
                (data['data'] as List<dynamic>?)
                    ?.map<String>((item) => item['name'] as String)
                    .toList() ??
                [];
            if (_costCenterOptions.isNotEmpty) {
              _selectedCostCenter = _costCenterOptions.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error in _fetchCostCenters: $e');
      if (mounted) {
        setState(() {
          _costCenterOptions = ['Main - VPS']; // Fallback
          _selectedCostCenter = _costCenterOptions.first;
        });
      }
    }
  }

  Future<void> _fetchOutstandingInvoices() async {
    if (_selectedCustomer == null) {
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Please select a customer first')),
      );
      return;
    }

    if (_partyAccount.isEmpty) {
      await _fetchPartyDetails(_selectedCustomer!.name);
      if (!mounted) return;
      if (_partyAccount.isEmpty) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Could not fetch party account')),
        );
        return;
      }
    }

    setState(() {
      _isFetchingInvoices = true;
      _errorMessage = null;
    });

    final args = {
      'party_type': 'Customer',
      'party': _selectedCustomer!.name,
      'get_outstanding_invoices': true,
      'posting_date': DateTime.now().toIso8601String().split('T')[0],
      'company': widget.company,
      'party_account': _partyAccount,
      'from_date': _fromDateController.text,
      'to_date': _toDateController.text,
    };

    final url =
        '${widget.serverUrl}/api/method/erpnext.accounts.doctype.payment_entry.payment_entry.get_outstanding_reference_documents';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode({'args': args});

    try {
      final response = await ApiClient.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final outstandingList = data['message'] as List<dynamic>? ?? [];

        if (mounted) {
          setState(() {
            for (final controller in _allocationControllers.values) {
              controller.dispose();
            }
            _allocationControllers.clear();
            _selectedReferences.clear();

            _outstandingInvoices = outstandingList
                .map<OutstandingInvoice>(
                  (json) => OutstandingInvoice.fromJson(json),
                )
                .where((inv) => (inv.outstandingAmount ?? 0) > 0)
                .toList();
            _isFetchingInvoices = false;
          });
        }
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      debugPrint('Error in _fetchOutstandingInvoices: $error');
      if (mounted) {
        setState(() {
          _isFetchingInvoices = false;
          _errorMessage = error.toString();
        });
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error fetching invoices: $_errorMessage')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchInvoiceDetails(String invoiceId) async {
    final url = '${widget.serverUrl}/api/resource/Sales Invoice/$invoiceId';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to fetch invoice details: ${response.body}');
      }
    } catch (error) {
      debugPrint('Error in _fetchInvoiceDetails: $error');
      if (mounted)
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error fetching invoice details: $error')),
        );
      return null;
    }
  }

  void _showInvoiceDetailsDialog(Map<String, dynamic> invoiceData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Invoice Details: ${invoiceData['name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${invoiceData['customer'] ?? 'N/A'}'),
              Text('Posting Date: ${invoiceData['posting_date'] ?? 'N/A'}'),
              Text('Due Date: ${invoiceData['due_date'] ?? 'N/A'}'),
              Text(
                'Total: INR ${invoiceData['grand_total']?.toStringAsFixed(2) ?? '0.00'}',
              ),
              Text(
                'Outstanding: INR ${invoiceData['outstanding_amount']?.toStringAsFixed(2) ?? '0.00'}',
              ),
              Text('Status: ${invoiceData['status'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(invoiceData['items'] as List<dynamic>?)?.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${item['item_name'] ?? 'N/A'}: INR ${item['amount']?.toStringAsFixed(2) ?? '0.00'}',
                      ),
                    ),
                  ) ??
                  [const Text('No items')],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  void _allocateToSelectedInvoices() {
    if (_selectedReferences.isEmpty) return;
    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
    if (paidAmount <= 0) {
      if (mounted)
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Please enter a paid amount to allocate.'),
          ),
        );
      return;
    }

    double remainingAmount = paidAmount;
    for (final ref in _selectedReferences) {
      final outstanding = ref.outstandingAmount;
      final allocation = (remainingAmount > outstanding)
          ? outstanding
          : remainingAmount;
      ref.allocatedAmount = allocation;
      _allocationControllers[ref.referenceName]?.text = allocation
          .toStringAsFixed(2);
      remainingAmount -= allocation;
      if (remainingAmount <= 0) break;
    }
    setState(() {});
  }

  Future<void> _createPaymentEntry() async {
    FocusScope.of(context).unfocus();

    if (_selectedCostCenter == null || _selectedCostCenter!.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Please select a Cost Center.')),
      );
      return;
    }
    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
    if (paidAmount <= 0) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Please enter a valid paid amount')),
      );
      return;
    }
    if (_selectedReferences.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Please fetch and select outstanding invoices'),
        ),
      );
      return;
    }
    if (_selectedCustomer == null || _partyAccount.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Customer or party account is missing')),
      );
      return;
    }
    if (_selectedPaidToAccount == null || _selectedModeOfPayment == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Payment account or mode of payment is missing'),
        ),
      );
      return;
    }
    if (_isBankAccount &&
        (_referenceNoController.text.isEmpty ||
            _referenceDateController.text.isEmpty)) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Reference No and Date are required for bank transactions',
          ),
        ),
      );
      return;
    }

    double totalAllocated = 0.0;
    for (var ref in _selectedReferences) {
      final allocated =
          double.tryParse(
            _allocationControllers[ref.referenceName]?.text ?? '0',
          ) ??
          0.0;
      if (allocated > ref.outstandingAmount) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Allocation for ${ref.referenceName} exceeds outstanding amount',
            ),
          ),
        );
        return;
      }
      ref.allocatedAmount = allocated;
      totalAllocated += allocated;
    }
    if (totalAllocated > paidAmount) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Total allocated amount exceeds paid amount'),
        ),
      );
      return;
    }

    final paymentEntry = PaymentEntry(
      namingSeries: _selectedNamingSeries ?? 'ACC-PAY-.YYYY.-',
      paymentType: 'Receive',
      partyType: _selectedPartyType ?? 'Customer',
      party: _selectedCustomer!.name,
      paidAmount: paidAmount,
      receivedAmount: paidAmount,
      paidFrom: _partyAccount,
      paidTo: _selectedPaidToAccount!,
      postingDate: DateTime.now().toIso8601String().split('T')[0],
      costCenter: _selectedCostCenter ?? '',
      modeOfPayment: _selectedModeOfPayment!,
      referenceNo: _isBankAccount ? _referenceNoController.text : null,
      referenceDate: _isBankAccount ? _referenceDateController.text : null,
      references: _selectedReferences
          .where((ref) => ref.allocatedAmount > 0)
          .map((ref) => ref.toJson())
          .toList(),
      remarks: _remarksController.text,
    );

    final url = '${widget.serverUrl}/api/resource/Payment Entry';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode(paymentEntry.toJson());

    // FIX: Capture context-dependent objects before the async call.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await ApiClient.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment Entry created successfully!'),
            backgroundColor: Color(0xFF14B8A6),
            duration: Duration(seconds: 2),
          ),
        );
        // Use a post-frame callback to pop the screen after the current frame is built.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigator.canPop()) {
            navigator.pop();
          }
        });
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      debugPrint('Error in _createPaymentEntry: $error');
      if (mounted) {
        // mounted check is still useful here
        messenger.showSnackBar(
          SnackBar(content: Text('Error creating payment: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Payment Entry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Naming Series & Party Type Hidden

                      // Party (Customer) Searchable Dropdown
                      CustomDropdown<Customer>(
                        label: 'Customer',
                        value: _selectedCustomer,
                        hint: 'Search and select customer',
                        items: _customers
                            .map(
                              (customer) => DropdownMenuItem(
                                value: customer,
                                child: Text(customer.customerName ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCustomer = value;
                            _outstandingInvoices
                                .clear(); // Clear old invoices on customer change
                            _selectedReferences.clear();
                          });
                          if (value != null) {
                            _fetchPartyDetails(value.name);
                          }
                        },
                        isSearchable: true,
                      ),
                      const SizedBox(height: 16),

                      // Invoice Filter Group Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Filter Invoices',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Fetch Invoices Button
                            ElevatedButton.icon(
                              onPressed: _isFetchingInvoices
                                  ? null
                                  : _fetchOutstandingInvoices,
                              icon: _isFetchingInvoices
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: const Text('Fetch Outstanding Invoices'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0074c9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // From Date & To Date
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: _fromDateController,
                                    label: 'From Date',
                                    prefixIcon: Icons.calendar_today,
                                    readOnly: true,
                                    onTap: () => _selectDate(
                                      context,
                                      _fromDateController,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _toDateController,
                                    label: 'To Date',
                                    prefixIcon: Icons.calendar_today,
                                    readOnly: true,
                                    onTap: () =>
                                        _selectDate(context, _toDateController),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Paid Amount
                      CustomTextField(
                        controller: _paidAmountController,
                        label: 'Paid Amount (INR)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.currency_exchange,
                      ),
                      const SizedBox(height: 16),

                      // Cost Center
                      if (_costCenterOptions.isNotEmpty)
                        CustomDropdown<String>(
                          label: 'Cost Center',
                          value: _selectedCostCenter,
                          items: _costCenterOptions
                              .map(
                                (cc) => DropdownMenuItem(
                                  value: cc,
                                  child: Text(cc),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCostCenter = val;
                              });
                            }
                          },
                        ),
                      if (_costCenterOptions.isNotEmpty)
                        const SizedBox(height: 16),
                      // Mode of Payment (Payment Account hidden but saved)
                      CustomDropdown<String>(
                        label: 'Mode of Payment',
                        value: _selectedModeOfPayment,
                        items: _modeOfPaymentOptions
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(mode),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedModeOfPayment = value);
                          _updatePaymentAccountForMode(value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Reference No & Date (conditional)
                      if (_isBankAccount)
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _referenceNoController,
                                label: 'Reference No',
                                prefixIcon: Icons.receipt,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _referenceDateController,
                                label: 'Reference Date',
                                prefixIcon: Icons.calendar_today,
                                readOnly: true,
                                onTap: () => _selectDate(
                                  context,
                                  _referenceDateController,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_isBankAccount) const SizedBox(height: 16),

                      // Outstanding Invoices List
                      if (_outstandingInvoices.isNotEmpty) ...[
                        const Text(
                          'Outstanding Invoices:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _outstandingInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _outstandingInvoices[index];
                            final isSelected = _selectedReferences.any(
                              (ref) => ref.referenceName == invoice.voucherNo,
                            );
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                title: Text(
                                  invoice.voucherNo ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Outstanding: INR ${invoice.outstandingAmount?.toStringAsFixed(2) ?? '0.00'}',
                                ),
                                trailing: Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedReferences.add(
                                          PaymentEntryReference(
                                            referenceDoctype:
                                                invoice.voucherType ??
                                                'Sales Invoice',
                                            referenceName:
                                                invoice.voucherNo ?? '',
                                            outstandingAmount:
                                                invoice.outstandingAmount ?? 0,
                                            allocatedAmount: 0,
                                          ),
                                        );
                                        _allocationControllers[invoice
                                                .voucherNo ??
                                            ''] = TextEditingController(
                                          text: '0.00',
                                        );
                                      } else {
                                        _selectedReferences.removeWhere(
                                          (ref) =>
                                              ref.referenceName ==
                                              invoice.voucherNo,
                                        );
                                        _allocationControllers
                                            .remove(invoice.voucherNo)
                                            ?.dispose();
                                      }
                                    });
                                  },
                                ),
                                onTap: () async {
                                  final invoiceData =
                                      await _fetchInvoiceDetails(
                                        invoice.voucherNo ?? '',
                                      );
                                  if (invoiceData != null && mounted) {
                                    _showInvoiceDetailsDialog(invoiceData);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Allocate Button
                        ElevatedButton.icon(
                          onPressed: _allocateToSelectedInvoices,
                          icon: const Icon(Icons.playlist_add_check_circle),
                          label: const Text('Auto Allocate Amount'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0074c9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Allocated References Summary
                        if (_selectedReferences.isNotEmpty) ...[
                          const Text(
                            'Allocated References:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _selectedReferences.length,
                            itemBuilder: (context, index) {
                              final ref = _selectedReferences[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  title: Text(
                                    '${ref.referenceDoctype}: ${ref.referenceName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Outstanding: INR ${ref.outstandingAmount.toStringAsFixed(2)}',
                                  ),
                                  trailing: SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller:
                                          _allocationControllers[ref
                                                  .referenceName] ??=
                                              TextEditingController(
                                                text: ref.allocatedAmount
                                                    .toStringAsFixed(2),
                                              ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Allocated',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),

                      // Remarks
                      CustomTextField(
                        controller: _remarksController,
                        label: 'Remarks',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton.icon(
                        onPressed: _createPaymentEntry,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Payment Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _remarksController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _referenceNoController.dispose();
    _referenceDateController.dispose();
    for (final controller in _allocationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
