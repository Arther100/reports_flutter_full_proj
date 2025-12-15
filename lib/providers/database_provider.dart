import 'package:flutter/material.dart';
import '../core/config/database_config.dart';
import '../services/api/database_service.dart';

class DatabaseProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  
  DatabaseConfig _currentDatabase = DatabaseConfigs.defaultDatabase;
  List<DatabaseConfig> _availableDatabases = DatabaseConfigs.allDatabases;
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _currentTables = [];

  DatabaseConfig get currentDatabase => _currentDatabase;
  List<DatabaseConfig> get availableDatabases => _availableDatabases;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get currentTables => _currentTables;

  /// Initialize - load current database info
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final info = await _dbService.getCurrentDatabase();
      if (info != null) {
        final currentId = info['current'] as String?;
        if (currentId != null) {
          final db = DatabaseConfigs.getById(currentId);
          if (db != null) {
            _currentDatabase = db;
          }
        }
      }
      await loadTables();
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switch to a different database
  Future<bool> switchDatabase(DatabaseConfig database) async {
    if (_currentDatabase.id == database.id) {
      return true; // Already on this database
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _dbService.switchDatabase(database.id);
      if (success) {
        _currentDatabase = database;
        await loadTables();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to switch database';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error switching database: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load tables for current database
  Future<void> loadTables() async {
    try {
      _currentTables = await _dbService.getTables();
      notifyListeners();
    } catch (e) {
      print('Error loading tables: $e');
    }
  }

  /// Check if current database is a specific one
  bool isDatabase(String databaseId) {
    return _currentDatabase.id == databaseId;
  }

  /// Check if POS Analytics database is active
  bool get isPOSDatabase => isDatabase('rupos_preprod');

  /// Check if PowerBI database is active
  bool get isPowerBIDatabase => isDatabase('teapioca_fpdb');
}
