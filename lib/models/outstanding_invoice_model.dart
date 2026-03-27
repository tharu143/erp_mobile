// models/outstanding_invoice_model.dart
class OutstandingInvoice {
  final String? voucherType;
  final String? voucherNo;
  final double? outstandingAmount;
  final String? dueDate;

  OutstandingInvoice({
    this.voucherType,
    this.voucherNo,
    this.outstandingAmount,
    this.dueDate,
  });

  factory OutstandingInvoice.fromJson(Map<String, dynamic> json) {
    return OutstandingInvoice(
      voucherType: json['voucher_type'] as String?,
      voucherNo: json['voucher_no'] as String?,
      outstandingAmount: (json['outstanding_amount'] as num?)?.toDouble(),
      dueDate: json['due_date'] as String?,
    );
  }
}