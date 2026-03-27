// models/payment_entry_reference_model.dart
class PaymentEntryReference {
  String referenceDoctype;
  String referenceName;
  double outstandingAmount;
  double allocatedAmount;

  PaymentEntryReference({
    required this.referenceDoctype,
    required this.referenceName,
    required this.outstandingAmount,
    this.allocatedAmount = 0,
  });

  Map<String, dynamic> toJson() => {
    'reference_doctype': referenceDoctype,
    'reference_name': referenceName,
    'outstanding_amount': outstandingAmount,
    'allocated_amount': allocatedAmount,
  };
}