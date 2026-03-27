import 'dart:convert';
// import 'package:http/http.dart' as http;
import 'package:erp_mobile/services/api_client.dart';

class ApiService {
  static Future<Map<String, dynamic>> fetchPaymentEntries(
    String serverUrl,
    String sid, {
    int page = 1,
    int limit = 10,
  }) async {
    // Standard Resource API: /api/resource/Payment Entry
    final fields = json.encode([
      "name",
      "posting_date",
      "party",
      "paid_amount",
      "received_amount",
      "payment_type",
      "status"
    ]);
    final url =
        '$serverUrl/api/resource/Payment Entry?fields=$fields&limit_start=${(page - 1) * limit}&limit_page_length=$limit&order_by=creation desc';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'message': {
            'status': 'success',
            'payment_entries': data['data'],
          }
        };
      } else {
        throw Exception(
          'Failed to load payment entries: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching payment entries: $e');
    }
  }

  static Future<List<String>> fetchNamingSeries(
    String serverUrl,
    String sid,
  ) async {
    // Standard ERPNext naming series can be fetched via frappe.model.mapper.get_series or similar
    // But a simpler way for Resource API is to look at the DocType.
    // However, since we want to avoid custom methods, let's use a standard list if possible
    // or use frappe.client.get_value for the DocType.
    // For now, we'll try a common standard method.
    // final url = '$serverUrl/api/method/frappe.core.doctype.doctype.doctype.get_property?doctype=Payment Entry&property=naming_series';
    // Actually, usually it's better to just let the user type or use default if we can't get it.
    // Let's use a simpler resource-based approach if possible, but naming series is tricky.
    // We'll fallback to a common standard method if available.
    
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      // Trying to get the numbering series options
      // Standard ERPNext has a method to get naming series for a doctype
      final nsUrl = '$serverUrl/api/method/frappe.ui.form.params.get_series?doctype=Payment Entry';
      final response = await ApiClient.get(Uri.parse(nsUrl), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null) {
          return List<String>.from(data['message'].split('\n'));
        }
      }
      return ['PE-']; // Fallback default
    } catch (e) {
      return ['PE-'];
    }
  }

  static Future<List<String>> fetchCustomers(
    String serverUrl,
    String sid,
  ) async {
    final url =
        '$serverUrl/api/resource/Customer?fields=["name","customer_name"]&limit_page_length=0';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> customers = data['data'] ?? [];
        return customers
            .map((customer) => customer['name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      } else {
        throw Exception(
          'Failed to fetch customers: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching customers: $e');
    }
  }

  static Future<List<String>> fetchSuppliers(
    String serverUrl,
    String sid,
  ) async {
    final url =
        '$serverUrl/api/resource/Supplier?fields=["name","supplier_name"]&limit_page_length=0';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> suppliers = data['data'] ?? [];
        return suppliers
            .map((supplier) => supplier['name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      } else {
        throw Exception(
          'Failed to fetch suppliers: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching suppliers: $e');
    }
  }

  static Future<List<String>> fetchEmployees(
    String serverUrl,
    String sid,
  ) async {
    final url =
        '$serverUrl/api/resource/Employee?fields=["name","employee_name"]&limit_page_length=0';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> employees = data['data'] ?? [];
        return employees
            .map((employee) => employee['name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      } else {
        throw Exception(
          'Failed to fetch employees: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching employees: $e');
    }
  }

  static Future<List<String>> fetchShareholders(
    String serverUrl,
    String sid,
  ) async {
    // If Shareholder doctype exists in their standard ERPNext
    final url = '$serverUrl/api/resource/Shareholder?fields=["name"]&limit_page_length=0';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> shareholders = data['data'] ?? [];
        return shareholders
            .map((sh) => sh['name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      } else {
        return []; // Might not exist in vanilla ERPNext
      }
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> fetchCostCenters(
    String serverUrl,
    String sid,
  ) async {
    final url = '$serverUrl/api/resource/Cost Center?fields=["name"]&limit_page_length=0';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'message': {
            'cost_centers': data['data'],
          }
        };
      } else {
        throw Exception(
          'Failed to fetch cost centers: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching cost centers: $e');
    }
  }

  static Future<String?> getUserCostCenter(String serverUrl, String sid) async {
    // Standard ERPNext doesn't have a direct "get user cost center" method.
    // It's usually on the Employee record.
    return null; // Return null to use default logic
  }

  static Future<void> createPaymentEntry(
    String serverUrl,
    String sid,
    Map<String, dynamic> paymentEntryData,
  ) async {
    final url = '$serverUrl/api/resource/Payment Entry';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await ApiClient.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(paymentEntryData),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to create payment entry: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating payment entry: $e');
    }
  }

  static Future<String?> getEmployeeIdByUser(
    String serverUrl,
    String sid,
    String email,
  ) async {
    // URL Encode the filters
    final filters = json.encode([
      ["user_id", "=", email],
    ]);
    final fields = json.encode(["name", "employee_name"]);
    final url =
        '$serverUrl/api/resource/Employee?filters=$filters&fields=$fields';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      // Attempt 1: Resource API
      final response = await ApiClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          return data['data'][0]['name'];
        } else {
          print(
            'getEmployeeIdByUser (Resource): No employee found. Response: ${response.body}',
          );
        }
      } else {
        print(
          'getEmployeeIdByUser (Resource): Failed ${response.statusCode}. Body: ${response.body}',
        );
      }

      // Attempt 2: frappe.client.get_list (Fallback)
      print(
        'getEmployeeIdByUser: Attempting fallback with frappe.client.get_list...',
      );
      final fallbackUrl = '$serverUrl/api/method/frappe.client.get_list';

      // Remove Content-Type: application/json so http client can set form-urlencoded
      final fallbackHeaders = Map<String, String>.from(headers);
      fallbackHeaders.remove('Content-Type');

      // Properly encode query parameters
      final queryParams = {
        'doctype': 'Employee',
        'filters': json.encode({'user_id': email}),
        'fields': json.encode(['name']),
        'limit_page_length': '1',
      };

      final fallbackResponse = await ApiClient.post(
        Uri.parse(fallbackUrl),
        headers: fallbackHeaders,
        body: queryParams,
      );

      print(
        'getEmployeeIdByUser (Fallback) Response: ${fallbackResponse.statusCode} - ${fallbackResponse.body}',
      );

      if (fallbackResponse.statusCode == 200) {
        final data = json.decode(fallbackResponse.body);
        if (data['message'] != null && (data['message'] as List).isNotEmpty) {
          final empId = data['message'][0]['name'];
          print('getEmployeeIdByUser (Fallback): Found ID $empId');
          return empId;
        } else {
          print(
            'getEmployeeIdByUser (Fallback): No employee found in list with filter. Attempting empty filter scan...',
          );

          // Attempt 3: Empty filters (Rely on User Permissions to restrict list)
          queryParams['filters'] = '{}';
          queryParams['fields'] = json.encode(['name', 'user_id']);
          queryParams['limit_page_length'] =
              '0'; // Fetch all (or reasonable limit like 50 if server enforces)

          final scanResponse = await ApiClient.post(
            Uri.parse(fallbackUrl),
            headers: fallbackHeaders,
            body: queryParams,
          );

          print(
            'getEmployeeIdByUser (Scan) Response: ${scanResponse.statusCode} - ${scanResponse.body}',
          );

          if (scanResponse.statusCode == 200) {
            final scanData = json.decode(scanResponse.body);
            if (scanData['message'] != null &&
                (scanData['message'] as List).isNotEmpty) {
              final list = scanData['message'] as List;
              print(
                'getEmployeeIdByUser (Scan): Got ${list.length} employees. Scanning for user_id=$email...',
              );
              for (var item in list) {
                final uid = item['user_id']?.toString().toLowerCase();
                final targetEmail = email.toLowerCase();
                if (uid == targetEmail) {
                  final empId = item['name'];
                  print('getEmployeeIdByUser (Scan): Match found! ID: $empId');
                  return empId;
                }
              }
              // If list has exactly 1 item and we couldn't match (maybe user_id is hidden?), assume it's the user's record
              if (list.length == 1) {
                final empId = list[0]['name'];
                print(
                  'getEmployeeIdByUser (Scan): Only 1 record found, assuming match. ID: $empId',
                );
                return empId;
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('Error fetching employee ID: $e');
      return null;
    }
  }

  static Future<void> postLocationLog(
    String serverUrl,
    String sid,
    Map<String, dynamic> logData,
  ) async {
    final url = '$serverUrl/api/resource/Employee Location Log';
    final headers = {
      'Cookie': 'sid=$sid',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      print('Posting location log to: $url');
      print('Data: $logData');
      final response = await ApiClient.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(logData),
      );
      print('Location log response: ${response.statusCode} - ${response.body}');
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to post location log: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error posting location log: $e');
    }
  }
}
