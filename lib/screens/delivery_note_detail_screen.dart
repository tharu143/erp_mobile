import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'utils.dart';
import 'full_screen_image_viewer.dart';
import 'package:erp_mobile/services/api_client.dart';

class DeliveryNoteDetailScreen extends StatefulWidget {
  final String noteId;
  final String serverUrl;
  final String sid;
  const DeliveryNoteDetailScreen({
    Key? key,
    required this.noteId,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _DeliveryNoteDetailScreenState createState() =>
      _DeliveryNoteDetailScreenState();
}

class _DeliveryNoteDetailScreenState extends State<DeliveryNoteDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> noteDetails = {};
  bool isLoading = true;
  late TabController _tabController;
  String? _selectedStatus;
  List<File?> _images = [];
  File? _airwayBillImage;
  String? _existingAirwayBillImageUrl;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool isSaving = false;
  TextEditingController _airwayBillNoController = TextEditingController();
  String? saveStatusMessage;
  Color? saveStatusColor;

  @override
  void initState() {
    super.initState();
    fetchDeliveryNoteDetails();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signatureController.dispose();
    _airwayBillNoController.dispose();
    super.dispose();
  }

  Future<void> fetchDeliveryNoteDetails() async {
    final url =
        "${widget.serverUrl}/api/resource/Delivery Note/${widget.noteId}";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          if (!mounted) return;
          setState(() {
            noteDetails = data['data'] ?? {};
            _selectedStatus = noteDetails['status'];
            isLoading = false;
          });
        }
      } else {
        throw Exception(
          'Failed to load delivery note details: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (error) {
      print('Error fetching delivery note details: $error');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Update logic removed for standard compatibility.

  Future<pw.Document> generatePdf() async {
    final pdf = pw.Document();
    final logoImage = await loadLogoImage();
    final customerSection = await generateCustomerSection(noteDetails);
    final totalQuantity = calculateTotalQuantity();
    final hasHsnSac = (noteDetails['items'] as List<dynamic>? ?? []).any(
      (item) => item['gst_hsn_code'] != null && item['gst_hsn_code'].isNotEmpty,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: pw.EdgeInsets.only(top: 6.0),
          child: pw.Text(
            'VPS Businesssolution, Office No: 1 - Abdullah Al Awar Building - Dubai - United Arab Emirates\n+971 4 323 1008, info@VPStech.ae, www.VPStechllc.com',
            style: pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  logoImage != null
                      ? pw.Image(logoImage, width: 70, height: 70)
                      : pw.Text('VPS', style: pw.TextStyle(fontSize: 16)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Delivery Note',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        noteDetails['name'] ?? '',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              customerSection,
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FixedColumnWidth(30),
                  1: pw.FlexColumnWidth(),
                  2: pw.FixedColumnWidth(60),
                  3: pw.FixedColumnWidth(60),
                  if (hasHsnSac) 4: pw.FixedColumnWidth(60),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _pdfTableHeader('Sr'),
                      _pdfTableHeader('Item Code'),
                      _pdfTableHeader('Quantity'),
                      _pdfTableHeader('Stock UOM'),
                      if (hasHsnSac) _pdfTableHeader('HSN/SAC'),
                    ],
                  ),
                  ...((noteDetails['items'] as List<dynamic>? ?? [])
                      .asMap()
                      .entries
                      .map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        final cells = [
                          _pdfTableCell(index.toString()),
                          _pdfTableCell(item['item_code'] ?? ''),
                          _pdfTableCell(item['qty'].toString()),
                          _pdfTableCell(item['uom'] ?? 'Nos'),
                        ];
                        if (hasHsnSac) {
                          cells.add(_pdfTableCell(item['gst_hsn_code'] ?? ''));
                        }
                        return pw.TableRow(children: cells);
                      })
                      .toList()),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Quantity: $totalQuantity',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _pdfTableHeader(String title) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTableCell(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10)),
    );
  }

  int calculateTotalQuantity() {
    if (noteDetails.isEmpty || noteDetails['items'] == null) return 0;
    return (noteDetails['items'] as List<dynamic>).fold(
      0,
      (sum, item) => sum + (item['qty'] as num).toInt(),
    );
  }

  Future<void> _printDeliveryNote() async {
    if (noteDetails.isEmpty) return;
    final pdf = await generatePdf();
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsPdf() async {
    if (noteDetails.isEmpty) return;
    final pdf = await generatePdf();
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'delivery_note_${noteDetails['name']}.pdf',
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FullScreenImageViewer(imageUrl: "${widget.serverUrl}$imageUrl"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          noteDetails['name'] ?? 'Delivery Note Details',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.print, color: Colors.white),
            onPressed: _printDeliveryNote,
            tooltip: 'Print',
          ),
          IconButton(
            icon: Icon(Icons.save_alt, color: Colors.white),
            onPressed: _saveAsPdf,
            tooltip: 'Save as PDF',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: Theme.of(context).textTheme.bodyMedium,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'General'),
            Tab(icon: Icon(Icons.list_alt), text: 'Items'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.white))
            : noteDetails.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Delivery note not found',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    if (saveStatusMessage != null) ...[
                      SizedBox(height: 16),
                      Text(
                        saveStatusMessage!,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: saveStatusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralInfo(),
                  _buildItemsList(),
                ],
              ),
      ),
    );
  }

  Widget _buildGeneralInfo() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildInfoRow('Note ID', noteDetails['name']),
              _buildInfoRow('Status', noteDetails['status']),
              _buildInfoRow('Customer', noteDetails['customer']),
              _buildInfoRow('Customer Name', noteDetails['customer_name']),
              _buildInfoRow('Company', noteDetails['company']),
              _buildInfoRow(
                'Posting Date',
                formatDate(noteDetails['posting_date']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    final isNotDelivered =
        noteDetails['custom_custom_delivery_status'] == 'Not Delivered';
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Status',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              if (!isNotDelivered)
                Text(
                  _selectedStatus ?? 'N/A',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: ['Not Delivered', 'Delivered']
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: isNotDelivered
                      ? (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        }
                      : null,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
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
                      ),
                    ),
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                ),
              SizedBox(height: 16),
              Text(
                'Airway Bill No',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              if (!isNotDelivered)
                Text(
                  noteDetails['custom_air_way_bill_number'] ?? 'N/A',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                )
              else
                TextField(
                  controller: _airwayBillNoController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
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
                      ),
                    ),
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                ),
              SizedBox(height: 16),
              Text(
                'Upload Images',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: (noteDetails['images'] as List<dynamic>? ?? [])
                    .map(
                      (image) => GestureDetector(
                        onTap: () => _showFullScreenImage(image['file_url']),
                        child: Image.network(
                          "${widget.serverUrl}${image['file_url']}",
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            'Error loading image',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(color: Colors.red),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (_images.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _images.map((image) {
                    if (image != null) {
                      return Image.file(
                        image,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      );
                    }
                    return SizedBox.shrink();
                  }).toList(),
                ),
              if (isNotDelivered)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: Icon(Icons.photo_library),
                        label: Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: Icon(Icons.camera_alt),
                        label: Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 16),
              Text(
                'Airway Bill Image',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              _existingAirwayBillImageUrl != null
                  ? GestureDetector(
                      onTap: () =>
                          _showFullScreenImage(_existingAirwayBillImageUrl!),
                      child: Image.network(
                        "${widget.serverUrl}$_existingAirwayBillImageUrl",
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          'Error loading image',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Colors.red),
                        ),
                      ),
                    )
                  : Text(
                      'No airway bill image',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                    ),
              if (_airwayBillImage != null)
                Image.file(
                  _airwayBillImage!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              if (isNotDelivered)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _pickImage(ImageSource.gallery, isAirwayBill: true),
                        icon: Icon(Icons.photo_library),
                        label: Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _pickImage(ImageSource.camera, isAirwayBill: true),
                        icon: Icon(Icons.camera_alt),
                        label: Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 24),
              Text(
                'Signature',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              if (isNotDelivered)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Signature(
                    controller: _signatureController,
                    height: 150,
                    backgroundColor: Colors.white,
                  ),
                )
              else if (noteDetails['custom_signature'] != null)
                Image.network(
                  "${widget.serverUrl}${noteDetails['custom_signature']}",
                  height: 150,
                  errorBuilder: (context, error, stackTrace) =>
                      Text('Error loading signature'),
                )
              else
                Text('No signature provided'),
              if (isNotDelivered)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _signatureController.clear(),
                      child: Text('Clear Signature'),
                    ),
                  ],
                ),
              SizedBox(height: 24),
              if (isNotDelivered)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : _saveUpdates,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSaving
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Save Updates',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              if (saveStatusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    saveStatusMessage!,
                    style: TextStyle(
                      color: saveStatusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, {bool isAirwayBill = false}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null && mounted) {
      setState(() {
        if (isAirwayBill) {
          _airwayBillImage = File(pickedFile.path);
        } else {
          _images.add(File(pickedFile.path));
        }
      });
    }
  }

  Future<void> _saveUpdates() async {
    setState(() => isSaving = true);
    try {
      // Build the update payload for the standard Resource API
      final Map<String, dynamic> updateData = {
        'custom_custom_delivery_status': _selectedStatus,
        'custom_airway_bill_no': _airwayBillNoController.text,
      };

      final url = Uri.parse(
        '${widget.serverUrl}/api/resource/Delivery Note/${widget.noteId}',
      );
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
      };

      final response = await ApiClient.put(
        url,
        headers: headers,
        body: jsonEncode(updateData),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          saveStatusMessage = 'Saved successfully!';
          saveStatusColor = Colors.green;
        });
        await fetchDeliveryNoteDetails();
      } else {
        setState(() {
          saveStatusMessage = 'Error saving: ${response.statusCode}';
          saveStatusColor = Colors.red;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saveStatusMessage = 'Error: $e';
          saveStatusColor = Colors.red;
        });
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _buildPaymentInfo() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Currency', noteDetails['currency']),
              _buildInfoRow(
                'Exchange Rate',
                '${noteDetails['conversion_rate']}',
              ),
              _buildInfoRow('Price List', noteDetails['selling_price_list']),
              _buildInfoRow(
                'Price List Rate',
                '${noteDetails['plc_conversion_rate']}',
              ),
              _buildInfoRow(
                'Ignore Pricing Rule',
                '${noteDetails['ignore_pricing_rule']}',
              ),
              _buildInfoRow('Terms', noteDetails['payment_terms_template']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTeam() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (noteDetails['sales_team'] != null)
                ...((noteDetails['sales_team'] as List<dynamic>)
                    .map(
                      (item) =>
                          _buildInfoRow('Sales Person', item['sales_person']),
                    )
                    .toList())
              else
                Text('No sales team information available'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: (noteDetails['items'] as List<dynamic>? ?? [])
            .map(
              (item) => Card(
                color: Colors.white,
                margin: EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['item_code'] ?? 'Unknown Item',
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      Divider(),
                      _buildInfoRow('Item Name', item['item_name']),
                      _buildInfoRow('Quantity', '${item['qty']}'),
                      _buildInfoRow('UOM', item['uom']),
                      _buildInfoRow('Rate', '${item['rate']}'),
                      _buildInfoRow('Amount', '${item['amount']}'),
                      _buildInfoRow('Warehouse', item['warehouse']),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildShippingInfo() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                'Shipping Address',
                noteDetails['shipping_address_name'],
              ),
              _buildInfoRow('Company Address', noteDetails['company_address']),
              _buildInfoRow('Contact Person', noteDetails['contact_person']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
