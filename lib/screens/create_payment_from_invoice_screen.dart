import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'unpaid_sales_invoice_list_screen.dart'; // To reuse the SalesInvoice model
import '../services/api_service.dart'; // Assuming ApiService is here

class CreatePaymentFromInvoiceScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final SalesInvoice invoice;

  const CreatePaymentFromInvoiceScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.invoice,
  }) : super(key: key);

  @override
  _CreatePaymentFromInvoiceScreenState createState() =>
      _CreatePaymentFromInvoiceScreenState();
}

class _CreatePaymentFromInvoiceScreenState
    extends State<CreatePaymentFromInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _payingAmountController;
  final TextEditingController _referenceNoController = TextEditingController();
  final TextEditingController _referenceDateController = TextEditingController();
  final TextEditingController _costCenterController = TextEditingController();

  final String _namingSeries = 'ACC-PAY-.YYYY.-'; // Default non-editable series
  String _selectedModeOfPayment = 'Cash';
  String _paidToAccount = 'Cash - VPS';
  String? _selectedCostCenter;
  bool _isLoading = false;
  bool _isInitializing = true;
  double _remainingBalance = 0.0;

  List<String> _costCenterOptions = [];

  @override
  void initState() {
    super.initState();
    _payingAmountController = TextEditingController();
    _payingAmountController.addListener(_updateRemainingBalance);
    _remainingBalance = widget.invoice.outstandingAmount;
    _fetchInitialData();
  }

  @override
  void dispose() {
    _payingAmountController.removeListener(_updateRemainingBalance);
    _payingAmountController.dispose();
    _referenceNoController.dispose();
    _referenceDateController.dispose();
    _costCenterController.dispose();
    super.dispose();
  }

  void _updateRemainingBalance() {
    final outstanding = widget.invoice.outstandingAmount;
    final paying = double.tryParse(_payingAmountController.text) ?? 0.0;
    setState(() {
      _remainingBalance = outstanding - paying;
    });
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isInitializing = true);
    try {
      final costCentersData =
          await ApiService.fetchCostCenters(widget.serverUrl, widget.sid);

      if (mounted) {
        setState(() {
          final List<dynamic> costCenterList = costCentersData['message'];
          _costCenterOptions =
              costCenterList.map((item) => item['name'].toString()).toList();
          if (_costCenterOptions.isNotEmpty) {
            _selectedCostCenter = _costCenterOptions.firstWhere(
                (cc) => cc == 'Main - VPS',
                orElse: () => _costCenterOptions.first);
            _costCenterController.text = _selectedCostCenter!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching initial data: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SearchDialog(
          items: _costCenterOptions,
          title: 'Select Cost Center',
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedCostCenter = selected;
        _costCenterController.text = selected;
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String company = widget.invoice.company.isNotEmpty
          ? widget.invoice.company
          : 'VPS Businesssolution';

      // Standard ERPNext Payment Entry Structure
      final Map<String, dynamic> paymentEntryData = {
        'doctype': 'Payment Entry',
        'naming_series': _namingSeries,
        'payment_type': 'Receive',
        'party_type': 'Customer',
        'party': widget.invoice.customerName,
        'paid_amount': double.parse(_payingAmountController.text),
        'received_amount': double.parse(_payingAmountController.text),
        'target_exchange_rate': 1.0,
        'paid_to': _paidToAccount,
        'paid_from': widget.invoice.debitTo,
        'posting_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'company': company,
        'cost_center': _selectedCostCenter ?? '',
        'mode_of_payment': _selectedModeOfPayment,
        'references': [
          {
            'reference_doctype': 'Sales Invoice',
            'reference_name': widget.invoice.name,
            'allocated_amount': double.parse(_payingAmountController.text),
          }
        ],
        if (_selectedModeOfPayment == 'PDC Receive') ...{
          'reference_no': _referenceNoController.text,
          'reference_date': _referenceDateController.text,
        }
      };

      debugPrint("--- Sending Payment Entry Data ---\nData: ${json.encode(paymentEntryData)}");

      await ApiService.createPaymentEntry(
        widget.serverUrl,
        widget.sid,
        paymentEntryData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Entry created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint("--- CAUGHT ERROR ---\nError: ${e.toString()}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating payment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectReferenceDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        _referenceDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // --- UI HELPER WIDGETS ---
  Widget _buildInfoRow(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 16),
          Text('$label:',
              style:
                  theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField(BuildContext context,
      {required String label, required Widget child}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }

  // --- MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Payment Entry'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Invoice Info Card ---
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Invoice Details',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(color: theme.colorScheme.primary)),
                            const Divider(height: 20),
                            _buildInfoRow(context,
                                icon: Icons.receipt_long,
                                label: 'Invoice No',
                                value: widget.invoice.name),
                            _buildInfoRow(context,
                                icon: Icons.business,
                                label: 'Customer',
                                value: widget.invoice.customerName),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Account & Other Details Card ---
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Accounting',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(color: theme.colorScheme.primary)),
                            const Divider(height: 20),
                            _buildLabeledField(context,
                                label: 'Naming Series',
                                child: TextFormField(
                                  initialValue: _namingSeries,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.format_list_numbered),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                     border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                )),
                            const SizedBox(height: 16),
                            _buildLabeledField(context,
                                label: 'Mode of Payment',
                                child: DropdownButtonFormField<String>(
                                  value: _selectedModeOfPayment,
                                  decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.credit_card)),
                                  items: ['Cash', 'PDC Receive']
                                      .map((String value) {
                                    return DropdownMenuItem<String>(
                                        value: value, child: Text(value));
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      _selectedModeOfPayment = newValue!;
                                      _paidToAccount = (newValue == 'Cash')
                                          ? 'Cash - VPS'
                                          : 'PDC Received - VPS';
                                    });
                                  },
                                )),
                            const SizedBox(height: 16),
                            if (_selectedModeOfPayment == 'PDC Receive') ...[
                              _buildLabeledField(context,
                                  label: 'Reference / Cheque No',
                                  child: TextFormField(
                                    controller: _referenceNoController,
                                    decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.pin)),
                                    validator: (value) =>
                                        (value == null || value.isEmpty)
                                            ? 'This field is required.'
                                            : null,
                                  )),
                              const SizedBox(height: 16),
                              _buildLabeledField(context,
                                  label: 'Reference / Cheque Date',
                                  child: TextFormField(
                                    controller: _referenceDateController,
                                    decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.calendar_today)),
                                    readOnly: true,
                                    onTap: () => _selectReferenceDate(context),
                                    validator: (value) =>
                                        (value == null || value.isEmpty)
                                            ? 'Please select a date.'
                                            : null,
                                  )),
                              const SizedBox(height: 16),
                            ],
                            _buildLabeledField(context,
                                label: 'Cost Center',
                                child: TextFormField(
                                  controller: _costCenterController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.business_center),
                                      suffixIcon: Icon(Icons.search)),
                                  onTap: () => _showSearchDialog(context),
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Please select a cost center.'
                                          : null,
                                )),
                            const SizedBox(height: 16),
                            _buildLabeledField(context,
                                label: 'Paid To Account',
                                child: TextFormField(
                                  key: Key(_paidToAccount),
                                  initialValue: _paidToAccount,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.arrow_downward),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                     border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Payment Details Card ---
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment Details',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(color: theme.colorScheme.primary)),
                            const Divider(height: 20),
                            _buildLabeledField(context,
                                label: 'Outstanding Amount (INR)',
                                child: TextFormField(
                                  initialValue: widget.invoice.outstandingAmount
                                      .toStringAsFixed(2),
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(
                                        Icons.account_balance_wallet_outlined),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                )),
                            const SizedBox(height: 16),
                            _buildLabeledField(context,
                                label: 'Amount Being Paid Now (INR)',
                                child: TextFormField(
                                  controller: _payingAmountController,
                                  decoration: const InputDecoration(
                                      hintText: 'Enter amount to pay',
                                      prefixIcon: Icon(Icons.payment)),
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty)
                                      return 'Please enter an amount.';
                                    final amount = double.tryParse(value);
                                    if (amount == null)
                                      return 'Please enter a valid number.';
                                    if (amount <= 0)
                                      return 'Amount must be greater than zero.';
                                    if (amount >
                                        widget.invoice.outstandingAmount)
                                      return 'Amount cannot exceed outstanding amount.';
                                    return null;
                                  },
                                )),
                            const SizedBox(height: 16),
                            _buildLabeledField(
                              context,
                              label: 'Remaining Balance (INR)',
                              child: TextFormField(
                                key: Key(_remainingBalance.toString()),
                                initialValue: _remainingBalance.toStringAsFixed(2),
                                readOnly: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.show_chart),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                   border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton(
                        onPressed: _submitPayment,
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Submit Payment',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class SearchDialog extends StatefulWidget {
  final List<String> items;
  final String title;

  const SearchDialog({Key? key, required this.items, required this.title})
      : super(key: key);

  @override
  _SearchDialogState createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  late List<String> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
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
  }
}

