import 'package:flutter/material.dart';
import 'dashboard_screen.dart'; // Reusing DashboardCard
// import 'sales_dashboard_screen.dart';
import 'package:erp_mobile/services/api_client.dart';

class SalesScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const SalesScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final url = '${widget.serverUrl}/api/method/frappe.auth.get_logged_user';
    try {
      await ApiClient.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
    } catch (e) {
      print('Session check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Sales Dashboard',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sales Modules',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    DashboardCard(
                      title: 'Customers',
                      icon: Icons.people,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/customerList',
                          arguments: {
                            'serverUrl': widget.serverUrl,
                            'sid': widget.sid,
                            'email': widget.email,
                          },
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Sales Order',
                      icon: Icons.shopping_cart,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/sales_order',
                          arguments: {
                            'serverUrl': widget.serverUrl,
                            'sid': widget.sid,
                          },
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Sales Invoice',
                      icon: Icons.receipt,
                      color: Colors.green,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/sales_invoice',
                          arguments: {
                            'serverUrl': widget.serverUrl,
                            'sid': widget.sid,
                          },
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Delivery Note',
                      icon: Icons.local_shipping,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/delivery_note',
                          arguments: {
                            'serverUrl': widget.serverUrl,
                            'sid': widget.sid,
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
