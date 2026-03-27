import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // Added for date formatting
import 'create_payment_from_invoice_screen.dart';
import 'package:erp_mobile/services/api_client.dart';

class SalesInvoice {
  final String name;
  final String customerName;
  final String status;
  final double grandTotal;
  final double outstandingAmount;
  final String postingDate;
  final String company;
  final String debitTo;
  final String currency;

  SalesInvoice({
    required this.name,
    required this.customerName,
    required this.status,
    required this.grandTotal,
    required this.outstandingAmount,
    required this.postingDate,
    required this.company,
    required this.debitTo,
    required this.currency,
  });

  factory SalesInvoice.fromJson(Map<String, dynamic> json) {
    return SalesInvoice(
      name: json['name'] ?? '',
      customerName: json['customer_name'] ?? '',
      status: json['status'] ?? 'Unknown',
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      outstandingAmount:
          (json['outstanding_amount'] as num?)?.toDouble() ?? 0.0,
      postingDate: json['posting_date'] ?? '',
      company: json['company'] ?? '',
      debitTo: json['debit_to'] ?? '',
      currency: json['currency'] ?? 'INR',
    );
  }
}

class UnpaidSalesInvoiceListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const UnpaidSalesInvoiceListScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  State<UnpaidSalesInvoiceListScreen> createState() =>
      _UnpaidSalesInvoiceListScreenState();
}

class _UnpaidSalesInvoiceListScreenState
    extends State<UnpaidSalesInvoiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<SalesInvoice> _allInvoices = [];
  List<SalesInvoice> _filteredInvoices = [];
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchInvoices(); // Initial fetch
    _searchController.addListener(_filterInvoicesByText);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        if (_hasMore && !_isLoadingMore) {
          _fetchInvoices(isLoadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterInvoicesByText);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoices({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
      _currentPage++;
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
        _allInvoices.clear();
        _filteredInvoices.clear();
      });
    }

    try {
      // Standard ERPNext Resource API with filters for unpaid/partly paid invoices
      final List<dynamic> filters = [
        ['docstatus', '=', 1],
        ['outstanding_amount', '>', 0]
      ];
      
      if (_selectedDate != null) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        filters.add(['posting_date', '=', formattedDate]);
      }

      final fields = json.encode([
        'name', 'customer_name', 'status', 'grand_total', 
        'outstanding_amount', 'posting_date', 'company', 
        'debit_to', 'currency'
      ]);

      final url = '${widget.serverUrl}/api/resource/Sales Invoice'
          '?fields=$fields'
          '&filters=${json.encode(filters)}'
          '&limit_start=${_currentPage * 20}'
          '&limit_page_length=20'
          '&order_by=creation desc';

      final uri = Uri.parse(url);
      final response = await ApiClient.get(uri, headers: {'Cookie': 'sid=${widget.sid}'});

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List invoicesJson = jsonData['data'] ?? [];
        final bool hasMoreFromServer = invoicesJson.length == 20;

        if (mounted) {
          setState(() {
            final newInvoices = invoicesJson.map((json) => SalesInvoice.fromJson(json)).toList();
            _allInvoices.addAll(newInvoices);
            _hasMore = hasMoreFromServer;
            _filterInvoicesByText(); // Apply text filter on the new/updated list
          });
        }
      } else {
        throw Exception('Failed to load sales invoices: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
       if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  // This function now only filters by the text search on the client side
  void _filterInvoicesByText() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredInvoices = _allInvoices;
      } else {
        _filteredInvoices = _allInvoices.where((invoice) {
          return invoice.customerName.toLowerCase().contains(query) ||
                 invoice.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // Selecting a date will trigger a fresh API call
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchInvoices(); // Refetch from API with the new date
    }
  }

  // Clearing the date filter will also trigger a fresh API call
  void _clearDateFilter() {
    setState(() => _selectedDate = null);
    _fetchInvoices(); // Refetch from API without the date
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unpaid Invoices'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchInvoices(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search by Customer or ID',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_selectedDate != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear Date Filter',
                      onPressed: _clearDateFilter,
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined),
                    tooltip: 'Filter by Date',
                    onPressed: () => _selectDate(context),
                  ),
                ],
              ),
            ),
            if (_selectedDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Chip(
                  label: Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}'),
                  onDeleted: _clearDateFilter,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  deleteIconColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            Expanded(
              child: _buildInvoiceList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList() {
    if (_isLoading && _allInvoices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_filteredInvoices.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty && _selectedDate == null
              ? 'No unpaid invoices found.'
              : 'No invoices match your search criteria.',
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredInvoices.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _filteredInvoices.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final invoice = _filteredInvoices[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('ID: ${invoice.name}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Date: ${invoice.postingDate}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        'Outstanding: ${invoice.outstandingAmount.toStringAsFixed(2)} ${invoice.currency}',
                        style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text('Status: ${invoice.status}',
                          style: TextStyle(
                              color: _getStatusColor(invoice.status),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatePaymentFromInvoiceScreen(
                          serverUrl: widget.serverUrl,
                          sid: widget.sid,
                          invoice: invoice,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchInvoices();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Pay'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('Unpaid')) return Colors.red.shade700;
    if (status.contains('Partly Paid')) return Colors.orange.shade800;
    if (status.contains('Overdue')) return Colors.purple.shade700;
    return Colors.grey;
  }
}

