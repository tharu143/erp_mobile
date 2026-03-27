class PaymentEntry {
  final String doctype = 'Payment Entry';
  final String namingSeries;
  final String paymentType;
  final String partyType;
  final String party;
  final double paidAmount;
  final double receivedAmount;
  final String paidFrom;
  final String paidTo;
  final String postingDate;
  final String costCenter;
  final String modeOfPayment;
  final String? referenceNo; // Nullable
  final String? referenceDate; // Nullable
  final List<Map<String, dynamic>> references;
  final String remarks;

  PaymentEntry({
    required this.namingSeries,
    required this.paymentType,
    required this.partyType,
    required this.party,
    required this.paidAmount,
    required this.receivedAmount,
    required this.paidFrom,
    required this.paidTo,
    required this.postingDate,
    required this.costCenter,
    required this.modeOfPayment,
    this.referenceNo,
    this.referenceDate,
    required this.references,
    required this.remarks,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'doctype': doctype,
      'naming_series': namingSeries,
      'payment_type': paymentType,
      'party_type': partyType,
      'party': party,
      'paid_amount': paidAmount,
      'received_amount': receivedAmount,
      'paid_from': paidFrom,
      'paid_to': paidTo,
      'posting_date': postingDate,
      'cost_center': costCenter,
      'mode_of_payment': modeOfPayment,
      'references': references,
      'remarks': remarks,
    };
    if (referenceNo != null) {
      json['reference_no'] = referenceNo!;
    }
    if (referenceDate != null) {
      json['reference_date'] = referenceDate!;
    }
    return json;
  }
}