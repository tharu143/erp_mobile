import 'package:flutter/material.dart';
import 'dashboard_screen.dart'; // Reusing DashboardCard
import 'package:erp_mobile/services/api_client.dart';

class AccountingScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String? email;

  const AccountingScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    this.email,
  }) : super(key: key);

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
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
        title: const Text(
          'Accounting',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                'Accounting Modules',
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
                      title: 'Create Payment Entry',
                      icon: Icons.add_card_outlined,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/paymentEntryCreate',
                          arguments: {
                            'serverUrl': widget.serverUrl,
                            'sid': widget.sid,
                            'email': widget.email ?? '',
                            'company': 'VPS Businesssolution',
                          },
                        );
                      },
                    ),
                    // You can add other accounting-related cards here in the future
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
