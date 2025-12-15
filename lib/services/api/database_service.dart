import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/config/database_config.dart';

class DatabaseService {
  static String get baseUrl => ApiConfig.apiBaseUrl;

  /// Get list of available databases
  Future<List<DatabaseConfig>> getAvailableDatabases() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/databases'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return DatabaseConfigs.allDatabases;
        }
      }
      return [];
    } catch (e) {
      print('Error fetching databases: $e');
      return [];
    }
  }

  /// Switch to a different database
  Future<bool> switchDatabase(String databaseId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/switch-database'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'databaseId': databaseId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error switching database: $e');
      return false;
    }
  }

  /// Get current database info
  Future<Map<String, dynamic>?> getCurrentDatabase() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/databases'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'current': data['current'],
            'databases': data['data'],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error getting current database: $e');
      return null;
    }
  }

  /// Get tables in current database
  Future<List<String>> getTables() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tables'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<String>.from(
            (data['data'] as List).map((e) => e['TABLE_NAME'].toString()),
          );
        }
      }
      return [];
    } catch (e) {
      print('Error fetching tables: $e');
      return [];
    }
  }
}
