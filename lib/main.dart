import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:erp_mobile/utils/global_keys.dart'; // Import for local use
export 'package:erp_mobile/utils/global_keys.dart'; // Export for others
import 'package:erp_mobile/screens/login_screen.dart';
import 'package:erp_mobile/screens/dashboard_screen.dart';
import 'package:erp_mobile/screens/customer_list_screen.dart';
import 'package:erp_mobile/screens/customer_detail_screen.dart';
import 'package:erp_mobile/screens/add_new_customer_screen.dart';
import 'package:erp_mobile/screens/sales_invoice_screen.dart';
import 'package:erp_mobile/screens/sales_order_screen.dart';
import 'package:erp_mobile/screens/sales_screen.dart';
import 'package:erp_mobile/screens/delivery_note_screen.dart';
import 'package:erp_mobile/screens/delivery_note_detail_screen.dart';
import 'package:erp_mobile/screens/delivery_note_list_screen.dart';
import 'package:erp_mobile/screens/create_sales_order_screen.dart';
import 'package:erp_mobile/screens/hr_screen.dart';
import 'package:erp_mobile/screens/leave_application_list_screen.dart';
import 'package:erp_mobile/screens/employee_list_screen.dart';
import 'package:erp_mobile/screens/attendance_list_screen.dart';
import 'package:erp_mobile/screens/attendance_details_screen.dart';
import 'package:erp_mobile/screens/accounting_screen.dart';
// import 'package:erp_mobile/screens/payment_entry_list_screen.dart';
import 'package:erp_mobile/screens/payment_entry_create_screen.dart';
// import 'package:erp_mobile/screens/payment_entry_detail_screen.dart';
import 'package:erp_mobile/screens/sales_invoice_detail_screen.dart';
import 'package:erp_mobile/screens/create_opportunity_screen.dart';
import 'package:erp_mobile/screens/crm_screen.dart';
import 'package:erp_mobile/screens/lead_list_screen.dart';
import 'package:erp_mobile/screens/lead_detail_screen.dart';
import 'package:erp_mobile/screens/quotation_list_screen.dart';
import 'package:erp_mobile/screens/opportunity_list_screen.dart';
import 'package:erp_mobile/screens/opportunity_detail_screen.dart';
import 'package:erp_mobile/screens/create_lead_screen.dart';
import 'package:erp_mobile/screens/create_opportunity_from_lead_screen.dart';
import 'package:erp_mobile/screens/create_quotation_screen.dart';
import 'package:erp_mobile/screens/create_quotation_from_lead_screen.dart';
import 'package:erp_mobile/screens/quotation_detail_screen.dart';
import 'package:erp_mobile/screens/create_sales_order_from_quotation_screen.dart';
import 'package:erp_mobile/screens/new_opptunity_create_screen.dart';
import 'package:erp_mobile/screens/new_quotation_create_screen.dart';
// import 'package:erp_mobile/screens/leave_dashboard_screen.dart';
import 'package:erp_mobile/screens/pdf_viewer_screen.dart';
import 'package:erp_mobile/screens/unpaid_sales_invoice_list_screen.dart';
import 'package:erp_mobile/screens/create_payment_from_invoice_screen.dart';
import 'package:erp_mobile/screens/splash_screen.dart'; // Import the new splash screen

Future<void> main() async {
  // Ensure that plugin services are initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    debugPrint(
      "dotenv loaded successfully. Maps_API_KEY: ${dotenv.env['Maps_API_KEY']}",
    );
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }

  // await LocationBackgroundService.initializeService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPS Businesssolution',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4CAF50),
          secondary: Color(0xFF388E3C),
          tertiary: Color(0xFF81C784),
          background: Color(0xFFFFFFFF),
          surface: Color(0xFFFFFFFF),
          surfaceVariant: Color(0xFFF1F8E9),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B5E20),
          ),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B5E20),
          ),
          titleMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B5E20),
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF424242),
          ),
          bodySmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF616161),
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF616161),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF9F9F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          // Changed to CardThemeData
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
      ),
      initialRoute: '/splash', // Change initial route to splash
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;

        bool hasRequiredArgs(Map<String, dynamic>? args) {
          return args != null &&
              args.containsKey('serverUrl') &&
              args.containsKey('sid') &&
              args.containsKey('email');
        }

        bool hasServerArgs(Map<String, dynamic>? args) {
          return args != null &&
              args.containsKey('serverUrl') &&
              args.containsKey('sid');
        }

        List<String>? convertToStringList(dynamic list) {
          if (list == null) return null;
          if (list is List) {
            return list.map((item) => item.toString()).toList();
          }
          return null;
        }

        switch (settings.name) {
          case '/splash': // Add route for splash screen
            return MaterialPageRoute(builder: (_) => const SplashScreen());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/dashboard':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  fullName: args['fullName'] ?? 'User',
                  email: args['email'],
                ),
              );
            }
            break;

/*
          case '/leaveDashboard':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => LeaveDashboardScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;
*/

          case '/crm':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CrmScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/leadList':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => LeadListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/leadDetail':
            if (args != null && hasServerArgs(args) && args.containsKey('lead')) {
              return MaterialPageRoute(
                builder: (_) => LeadDetailScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  lead: args['lead'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/quotationList':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => QuotationListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/quotationDetail':
            if (args != null && hasRequiredArgs(args) && args.containsKey('quotation')) {
              return MaterialPageRoute(
                builder: (_) => QuotationDetailScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  quotation: args['quotation'],
                ),
              );
            }
            break;

          case '/createSalesOrderFromQuotation':
            if (args != null && hasRequiredArgs(args) && args.containsKey('quotation')) {
              return MaterialPageRoute(
                builder: (_) => CreateSalesOrderFromQuotationScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  quotation: args['quotation'],
                ),
              );
            }
            break;

          case '/opportunityList':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => OpportunityListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/opportunityDetail':
            if (args != null && hasRequiredArgs(args) && args.containsKey('opportunity')) {
              return MaterialPageRoute(
                builder: (_) => OpportunityDetailScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  opportunity: args['opportunity'],
                ),
              );
            }
            break;

          case '/createQuotation':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CreateQuotationScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  lead: args['lead'],
                ),
              );
            }
            break;

          case '/createQuotationFromLead':
            if (args != null && hasRequiredArgs(args) && args.containsKey('lead')) {
              return MaterialPageRoute(
                builder: (_) => CreateQuotationFromLeadScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  lead: args['lead'],
                ),
              );
            }
            break;

          case '/sales':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => SalesScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/customerList':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CustomerListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/customerDetail':
            if (args != null && hasServerArgs(args) && args.containsKey('customer')) {
              return MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(
                  customer: args['customer'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/addNewCustomer':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => AddNewCustomerScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/sales_invoice':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => SalesInvoiceScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  filterIds: convertToStringList(args['filterIds']),
                ),
              );
            }
            break;

          case '/salesInvoiceDetail':
            if (args != null && hasServerArgs(args) && args.containsKey('invoiceId')) {
              return MaterialPageRoute(
                builder: (_) => SalesInvoiceDetailScreen(
                  invoiceId: args['invoiceId'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/sales_order':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => SalesOrderScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/createSalesOrder':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CreateSalesOrderScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/delivery_note':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => DeliveryNoteScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  filterIds: convertToStringList(args['filterIds']),
                ),
              );
            }
            break;

          case '/delivery_note_list':
            if (args != null && hasServerArgs(args) && args.containsKey('statusFilter')) {
              return MaterialPageRoute(
                builder: (_) => DeliveryNoteListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  statusFilter: args['statusFilter'],
                ),
              );
            }
            break;

          case '/deliveryNoteDetail':
            if (args != null && hasServerArgs(args) && args.containsKey('noteId')) {
              return MaterialPageRoute(
                builder: (_) => DeliveryNoteDetailScreen(
                  noteId: args['noteId'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;


          case '/hr':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => HRScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/leaveApplicationList':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => LeaveApplicationListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/employeeList':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => EmployeeListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/attendanceList':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => AttendanceListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/attendanceDetails':
            if (args != null && hasServerArgs(args) && args.containsKey('attendance')) {
              return MaterialPageRoute(
                builder: (_) => AttendanceDetailsScreen(
                  attendance: args['attendance'],
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                ),
              );
            }
            break;

          case '/accounting':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => AccountingScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          // case '/paymentEntryList':
          //   if (hasServerArgs(args)) {
          //     return MaterialPageRoute(
          //       builder: (_) => PaymentEntryListScreen(
          //         serverUrl: args['serverUrl'],
          //         sid: args['sid'],
          //       ),
          //     );
          //   }
          //   break;

          case '/paymentEntryCreate':
            if (args != null && hasServerArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => PaymentEntryCreateScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  company: args['company'] ?? 'VPS Businesssolution',
                ),
              );
            }
            break;

          // case '/paymentEntryDetail':
          //   if (hasServerArgs(args) && args!.containsKey('paymentEntry')) {
          //     return MaterialPageRoute(
          //       builder: (_) => PaymentEntryDetailScreen(
          //         paymentEntry: args!['paymentEntry'],
          //         serverUrl: args['serverUrl'],
          //         sid: args['sid'],
          //       ),
          //     );
          //   }
          //   break;

          // Removed deprecated daily_visit route

          case '/newQuotationCreateScreen':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => NewQuotationCreateScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/create_opportunity':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CreateOpportunityScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  partyName: args['partyName'],
                  initialOpportunityDiscussion:
                      args['initialOpportunityDiscussion'],
                ),
              );
            }
            break;

          case '/createLead':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => CreateLeadScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/newOpptunityCreate':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => NewOpptunityCreateScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/createOpportunityFromLead':
            if (args != null && hasRequiredArgs(args) &&
                args.containsKey('leadId') &&
                args.containsKey('partyName')) {
              return MaterialPageRoute(
                builder: (_) => CreateOpportunityFromLeadScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                  leadId: args['leadId'],
                  partyName: args['partyName'],
                  opportunityOwner: args['opportunityOwner'],
                ),
              );
            }
            break;

          // Removed deprecated reports routes

          case '/pdfViewer':
            if (args != null &&
                args.containsKey('pdfUrl') &&
                args.containsKey('fileName')) {
              return MaterialPageRoute(
                builder: (_) => PdfViewerScreen(
                  pdfUrl: args['pdfUrl'],
                  sid: args['sid'],
                  fileName: args['fileName'],
                ),
              );
            }
            break;

          case '/unpaidInvoiceList':
            if (args != null && hasRequiredArgs(args)) {
              return MaterialPageRoute(
                builder: (_) => UnpaidSalesInvoiceListScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  email: args['email'],
                ),
              );
            }
            break;

          case '/createPaymentFromInvoice':
            if (args != null && hasRequiredArgs(args) && args.containsKey('invoice')) {
              return MaterialPageRoute(
                builder: (_) => CreatePaymentFromInvoiceScreen(
                  serverUrl: args['serverUrl'],
                  sid: args['sid'],
                  invoice: args['invoice'] as SalesInvoice,
                ),
              );
            }
            break;

          default:
            debugPrint(
              'Route: ${settings.name}, Arguments: ${settings.arguments}',
            );
            return MaterialPageRoute(
              builder: (_) =>
                  const Scaffold(body: Center(child: Text('Page not found'))),
            );
        }
        debugPrint('Invalid arguments for route: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Invalid arguments'))),
        );
      },
    );
  }
}
