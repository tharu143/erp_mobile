// lib/models/customer_model.dart
class Customer {
  final String name;
  final String? customerName;
  final String? defaultAccount; // Party account

  Customer({
    required this.name,
    this.customerName,
    this.defaultAccount,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['name'] as String? ?? '',
      customerName: json['customer_name'] as String?,
      defaultAccount: json['default_account'] as String?, // Adjust field name if different
    );
  }
}