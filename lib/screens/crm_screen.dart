import 'package:flutter/material.dart';
import 'dashboard_screen.dart'; // Reusing DashboardCard
import 'package:erp_mobile/services/api_client.dart';

class CrmScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const CrmScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  }) : super(key: key);

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
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
          'CRM Dashboard',
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
                'CRM Modules',
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
                      title: 'Lead',
                      icon: Icons.person_search,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/leadList',
                          arguments: {
                            'serverUrl': widget.serverUrl,
                            'sid': widget.sid,
                            'email': widget.email,
                          },
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Opportunity',
                      icon: Icons.lightbulb,
                      color: Colors.amber,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/opportunityList',
                          arguments: {
                            'serverUrl': widget.serverUrl,
                            'sid': widget.sid,
                            'email': widget.email,
                          },
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Quotation',
                      icon: Icons.request_quote,
                      color: Colors.green,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/quotationList',
                          arguments: {
                            'serverUrl': widget.serverUrl,
                            'sid': widget.sid,
                            'email': widget.email,
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
