import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:erp_mobile/services/api_client.dart';

class CreateOpportunityScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;
  final String? partyName;
  final String? initialOpportunityDiscussion;
  final String? customVisitId;
  final String? opportunityOwner;
  final String? opportunityFromType;

  const CreateOpportunityScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
    this.partyName,
    this.initialOpportunityDiscussion,
    this.customVisitId,
    this.opportunityOwner,
    this.opportunityFromType,
  }) : super(key: key);

  @override
  _CreateOpportunityScreenState createState() =>
      _CreateOpportunityScreenState();
}

class _CreateOpportunityScreenState extends State<CreateOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();

  // Opportunity fields
  String? _series;
  String? _opportunityFrom = 'Visit';
  String? _partyName;
  String? _status = 'Open';
  String _company = 'VPS Businesssolution';
  final TextEditingController _transactionDateController =
      TextEditingController();
  final TextEditingController _opportunityDiscussionController =
      TextEditingController();
  final TextEditingController _customVisitIdController =
      TextEditingController();
  final TextEditingController _customRemarksController =
      TextEditingController();
  String? _selectedOpportunityOwner;

  // Item table fields
  final List<Map<String, dynamic>> _items = [
    {
      'itemCode': null,
      'itemName': null,
      'uom': null,
      'qty': TextEditingController(text: '1.000'),
      'rate': 0.0,
      'rateController': TextEditingController(text: '0.00'),
      'amount': 0.0,
      'qtyFocusNode': FocusNode(),
      'rateFocusNode': FocusNode(),
    },
  ];

  // API-fetched data
  List<String> seriesList = [];
  List<Map<String, dynamic>> itemList = [];
  List<String> opportunityOwnerEmails = [];

  bool isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _partyName = widget.partyName;
    _opportunityDiscussionController.text =
        widget.initialOpportunityDiscussion ?? '';
    _transactionDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    _customVisitIdController.text = widget.customVisitId ?? '';
    _selectedOpportunityOwner = widget.opportunityOwner;

    if (widget.opportunityFromType != null) {
      _opportunityFrom = widget.opportunityFromType;
    }

    _fetchNamingSeries();
    _fetchItems();
    _fetchOpportunityOwners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _transactionDateController.dispose();
    _opportunityDiscussionController.dispose();
    _customVisitIdController.dispose();
    _customRemarksController.dispose();
    for (var item in _items) {
      item['qty'].dispose();
      item['rateController'].dispose();
      item['qtyFocusNode'].dispose();
      item['rateFocusNode'].dispose();
    }
    super.dispose();
  }

  String getUserFriendlyMessage(int statusCode, String message) {
    switch (statusCode) {
      case 200:
        return "Success. $message";
      case 201:
        return "Created. $message";
      // ... (other cases)
      default:
        return "Unexpected error. $message";
    }
  }

  String _getFriendlyErrorMessage(dynamic error) {
    if (error is SocketException || error is TimeoutException) {
      return 'No internet connection. Please check your network.';
    }
    if (error is http.Response) {
      return getUserFriendlyMessage(error.statusCode, 'Please try again.');
    }
    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> _fetchNamingSeries() async {
    final url = '${widget.serverUrl}/api/resource/DocType/Opportunity';
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
        final data = json.decode(response.body);
        final fields = data['data']['fields'] as List;
        final namingSeriesField = fields.firstWhere(
          (f) => f['fieldname'] == 'naming_series',
          orElse: () => null,
        );

        if (namingSeriesField != null && namingSeriesField['options'] != null) {
          setState(() {
            seriesList = (namingSeriesField['options'] as String)
                .split('\n')
                .where((s) => s.isNotEmpty)
                .toList();
            _series = seriesList.isNotEmpty ? seriesList[0] : null;
          });
        }
      } else {
        setState(() {
          seriesList = ['CRM-OPP-.YYYY.-'];
          _series = seriesList.isNotEmpty ? seriesList[0] : null;
        });
      }
    } catch (e) {
      setState(() {
        seriesList = ['CRM-OPP-.YYYY.-'];
        _series = seriesList.isNotEmpty ? seriesList[0] : null;
      });
    }
  }

  Future<void> _fetchOpportunityOwners() async {
    final url =
        "${widget.serverUrl}/api/resource/User?fields=[\"email\"]&filters=[[\"enabled\",\"=\",1]]";
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
        List<dynamic> data = json.decode(response.body)['data'];
        if (mounted) {
          setState(() {
            opportunityOwnerEmails = data
                .map((user) => user['email'] as String)
                .toList();
            if (_selectedOpportunityOwner != null &&
                !opportunityOwnerEmails.contains(_selectedOpportunityOwner)) {
              opportunityOwnerEmails.add(_selectedOpportunityOwner!);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching opportunity owners: $e');
    }
  }

  Future<void> _fetchItems() async {
    final url =
        '${widget.serverUrl}/api/resource/Item?fields=["name","item_name","uom"]&limit_page_length=100';
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
          itemList = (data['data'] as List).map((item) {
            return {
              'item_code': item['name'],
              'item_name': item['item_name'],
              'uom': item['uom'],
              'latest_price': {'price_list_rate': 0.0, 'currency': 'INR'}
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Exception during _fetchItems: $e');
    }
  }

  Future<void> _createOpportunity({bool andContinue = false}) async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors before saving.', isSuccess: false);
      return;
    }

    setState(() => isLoading = true);

    final url = "${widget.serverUrl}/api/resource/Opportunity";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final items = _items.map((item) {
      return {
        "item_code": item['itemCode'],
        "item_name": item['itemName'],
        "uom": item['uom'],
        "qty": double.tryParse(item['qty'].text) ?? 0.0,
        "rate": item['rate'],
        "amount": item['amount'],
      };
    }).toList();

    final body = jsonEncode({
      "naming_series": _series,
      "opportunity_from": _opportunityFrom,
      "party_name": _partyName,
      "status": _status,
      "company": _company,
      "transaction_date": _transactionDateController.text,
      "items": items,
      "opportunity_discussion": _opportunityDiscussionController.text,
      "custom_visit_id": widget.customVisitId,
      "opportunity_owner": _selectedOpportunityOwner,
      "custom_remarks": _customRemarksController.text,
    });

    debugPrint('Sending Opportunity payload: $body');

    try {
      final response = await ApiClient.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar('Opportunity created successfully!', isSuccess: true);
        if (andContinue) {
          _formKey.currentState?.reset();
          setState(() {
            _transactionDateController.text = DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.now());
            _opportunityDiscussionController.clear();
            _customRemarksController.clear();
            _items.clear();
            _items.add({
              'itemCode': null,
              'itemName': null,
              'uom': null,
              'qty': TextEditingController(text: '1.000'),
              'rate': 0.0,
              'rateController': TextEditingController(text: '0.00'),
              'amount': 0.0,
              'qtyFocusNode': FocusNode(),
              'rateFocusNode': FocusNode(),
            });
            _status = 'Open';
            _series = seriesList.isNotEmpty ? seriesList[0] : null;
          });
        } else {
          Navigator.pop(context, true);
        }
      } else {
        final errorMessage = _getFriendlyErrorMessage(response);
        _showSnackBar(errorMessage, isSuccess: false);
        debugPrint(
          'Create Opportunity failed: Status Code: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      final errorMessage = _getFriendlyErrorMessage(e);
      _showSnackBar(errorMessage, isSuccess: false);
      debugPrint('Exception during _createOpportunity: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
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
            ),
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

  void _addItemRow() {
    setState(() {
      _items.add({
        'itemCode': null,
        'itemName': null,
        'uom': null,
        'qty': TextEditingController(text: '1.000'),
        'rate': 0.0,
        'rateController': TextEditingController(text: '0.00'),
        'amount': 0.0,
        'qtyFocusNode': FocusNode(),
        'rateFocusNode': FocusNode(),
      });
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      if (_items.length > 1) {
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

  double getTotalAmount() {
    return _items.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  Widget _buildModuleCard({
    required String title,
    required Widget child,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 24, thickness: 1, color: Colors.grey),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
    IconData? prefixIcon,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    VoidCallback? onEditingComplete,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      onTap: onTap,
      onChanged: onChanged != null
          ? (value) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                onChanged(value);
              });
            }
          : null,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
    );
  }

  Widget _buildDropdownField({
    required String labelText,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    String? Function(String?)? validator,
    IconData? prefixIcon,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
    );
  }

  Widget _buildItemsTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      'No.',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: Text(
                      'Item Details',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              // MODIFIED: Removed the problematic if-block that resets the controller text

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownSearch<String>(
                            asyncItems: (String filter) => Future.value(
                              itemList
                                  .map((item) => item['item_code'] as String)
                                  .where(
                                    (code) => code.toLowerCase().contains(
                                      filter.toLowerCase(),
                                    ),
                                  )
                                  .toList(),
                            ),
                            selectedItem: item['itemCode'],
                            onChanged: (value) {
                              if (_debounce?.isActive ?? false)
                                _debounce!.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  setState(() {
                                    final selectedItem = itemList.firstWhere(
                                      (element) =>
                                          element['item_code'] == value,
                                      orElse: () => {
                                        'item_code': '',
                                        'item_name': '',
                                        'uom': '',
                                        'latest_price': {
                                          'price_list_rate': 0.0,
                                          'currency': '',
                                        },
                                      },
                                    );

                                    item['itemCode'] = value;
                                    item['itemName'] =
                                        selectedItem['item_name'] ?? '';
                                    item['uom'] = selectedItem['uom'] ?? '';
                                    item['rate'] =
                                        (selectedItem['latest_price'] != null &&
                                            selectedItem['latest_price']['currency'] ==
                                                'INR')
                                        ? (selectedItem['latest_price']['price_list_rate']
                                                  as num)
                                              .toDouble()
                                        : 0.0;
                                    item['rateController'].text = item['rate']
                                        .toStringAsFixed(2);
                                    if (item['qty'].text.isEmpty) {
                                      item['qty'].text = '1.000';
                                    }
                                    final qty =
                                        double.tryParse(item['qty'].text) ??
                                        0.0;
                                    item['amount'] = qty * item['rate'];
                                  });
                                },
                              );
                            },
                            validator: (value) =>
                                value == null ? 'Select an item' : null,
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  labelText: 'Search Item Code',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                            dropdownBuilder: (context, selectedItem) {
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.shade50,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.search,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedItem ?? 'Select Item Code',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: selectedItem == null
                                              ? Colors.grey
                                              : Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['itemName'] ?? 'No Item Selected',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: item['qty'],
                                  decoration: InputDecoration(
                                    labelText: 'Qty',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                  ),
                                  // MODIFIED: Use phone keyboard for iOS action button
                                  keyboardType: TextInputType.phone,
                                  validator: (value) =>
                                      value!.isEmpty ||
                                          double.tryParse(value) == null
                                      ? 'Enter valid qty'
                                      : null,
                                  onChanged: (value) {
                                    if (_debounce?.isActive ?? false)
                                      _debounce!.cancel();
                                    _debounce = Timer(
                                      const Duration(milliseconds: 500),
                                      () {
                                        setState(() {
                                          final qty =
                                              double.tryParse(value) ?? 0.0;
                                          item['amount'] = qty * item['rate'];
                                        });
                                      },
                                    );
                                  },
                                  style: const TextStyle(fontSize: 14),
                                  // MODIFIED: Added Focus, textInputAction, and onEditingComplete
                                  focusNode: item['qtyFocusNode'],
                                  textInputAction: TextInputAction.next,
                                  onEditingComplete: () {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(item['rateFocusNode']);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: item['rateController'],
                                  decoration: InputDecoration(
                                    labelText: 'Rate (INR)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                  ),
                                  // MODIFIED: Use phone keyboard for iOS action button
                                  keyboardType: TextInputType.phone,
                                  validator: (value) =>
                                      value!.isEmpty ||
                                          double.tryParse(value) == null
                                      ? 'Enter valid rate'
                                      : null,
                                  // MODIFIED: Added onChanged to save value as user types
                                  onChanged: (value) {
                                    if (_debounce?.isActive ?? false)
                                      _debounce!.cancel();
                                    _debounce = Timer(
                                      const Duration(milliseconds: 500),
                                      () {
                                        setState(() {
                                          final rate =
                                              double.tryParse(value) ?? 0.0;
                                          item['rate'] = rate;
                                          final qty =
                                              double.tryParse(
                                                item['qty'].text,
                                              ) ??
                                              0.0;
                                          item['amount'] = qty * rate;
                                        });
                                      },
                                    );
                                  },
                                  onEditingComplete: () {
                                    setState(() {
                                      final rate =
                                          double.tryParse(
                                            item['rateController'].text,
                                          ) ??
                                          0.0;
                                      item['rate'] = rate;
                                      if (rate == rate.truncateToDouble()) {
                                        item['rateController'].text = rate
                                            .toStringAsFixed(2);
                                      }
                                      final qty =
                                          double.tryParse(item['qty'].text) ??
                                          0.0;
                                      item['amount'] = qty * item['rate'];
                                    });

                                    // MODIFIED: Move focus logic
                                    if (index == _items.length - 1) {
                                      // Last item, dismiss keyboard
                                      FocusScope.of(context).unfocus();
                                    } else {
                                      // Not last, move to next item's Qty
                                      FocusScope.of(context).requestFocus(
                                        _items[index + 1]['qtyFocusNode'],
                                      );
                                    }
                                  },
                                  onTap: () {
                                    item['rateController']
                                        .selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset:
                                          item['rateController'].text.length,
                                    );
                                  },
                                  style: const TextStyle(fontSize: 14),
                                  // MODIFIED: Added Focus and textInputAction
                                  focusNode: item['rateFocusNode'],
                                  textInputAction: (index == _items.length - 1)
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Amount: INR ${item['amount'].toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: _items.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeItemRow(index),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Opportunity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.9),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Opportunity Data...',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium!.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModuleCard(
                        title: 'Opportunity Details',
                        context: context,
                        child: Column(
                          children: [
                            if (widget.customVisitId != null &&
                                widget.customVisitId!.isNotEmpty)
                              _buildTextField(
                                controller: _customVisitIdController,
                                labelText: 'Daily Visit ID',
                                readOnly: true,
                                prefixIcon: Icons.receipt_long,
                              ),
                            if (widget.customVisitId != null &&
                                widget.customVisitId!.isNotEmpty)
                              const SizedBox(height: 16),
                            _buildDropdownField(
                              labelText: 'Series',
                              value: _series,
                              items: seriesList,
                              onChanged: (value) =>
                                  setState(() => _series = value),
                              validator: (value) => value == null
                                  ? 'Please select a series'
                                  : null,
                              prefixIcon: Icons.format_list_numbered,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: TextEditingController(
                                text: _opportunityFrom,
                              ),
                              labelText: 'Opportunity From',
                              readOnly: true,
                              prefixIcon: Icons.source,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: TextEditingController(
                                text: _partyName,
                              ),
                              labelText: 'Party',
                              readOnly: true,
                              prefixIcon: Icons.person,
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              labelText: 'Opportunity Owner',
                              value: _selectedOpportunityOwner,
                              items: opportunityOwnerEmails,
                              onChanged: (value) => setState(
                                () => _selectedOpportunityOwner = value,
                              ),
                              validator: (value) => value == null
                                  ? 'Please select an opportunity owner'
                                  : null,
                              prefixIcon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              labelText: 'Status',
                              value: _status,
                              items: const [
                                'Open',
                                'Quotation',
                                'Converted',
                                'Lost',
                                'Replied',
                                'Closed',
                              ],
                              onChanged: (value) =>
                                  setState(() => _status = value),
                              validator: (value) => value == null
                                  ? 'Please select a status'
                                  : null,
                              prefixIcon: Icons.info_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: TextEditingController(text: _company),
                              labelText: 'Company',
                              readOnly: true,
                              prefixIcon: Icons.business,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _transactionDateController,
                              labelText: 'Opportunity Date',
                              readOnly: true,
                              onTap: () => _selectDate(
                                context,
                                _transactionDateController,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Please select an opportunity date'
                                  : null,
                              prefixIcon: Icons.calendar_today,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _opportunityDiscussionController,
                              labelText: 'Opportunity Discussion',
                              maxLines: 5,
                              keyboardType: TextInputType.multiline,
                              onChanged: (value) =>
                                  _opportunityDiscussionController.text = value,
                              prefixIcon: Icons.notes,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModuleCard(
                        title: 'Items',
                        context: context,
                        child: _buildItemsTable(context),
                      ),
                      const SizedBox(height: 20),
                      _buildModuleCard(
                        title: 'Remarks',
                        context: context,
                        child: _buildTextField(
                          controller: _customRemarksController,
                          labelText: 'Remarks',
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildModuleCard(
                        title: 'Totals',
                        context: context,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Quantity',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  getTotalQuantity().toStringAsFixed(3),
                                  style: Theme.of(context).textTheme.titleLarge!
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total (INR)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'INR ${getTotalAmount().toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleLarge!
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // MODIFICATION: Replaced Row with a single ElevatedButton
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => _createOpportunity(andContinue: false),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 6,
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Save Opportunity',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      // MODIFICATION: Changed to FloatingActionButton.extended
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItemRow,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add New Item',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 6,
      ),
    );
  }
}
