import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../lib/config/db_config.dart';
import '../lib/services/database_service.dart';
import '../lib/routes/api_handler.dart';

/// Main entry point for the backend server
Future<void> main() async {
  // Initialize configuration
  DbConfig.initialize();
  DbConfig.validate();

  // Initialize database connection
  final db = DatabaseService();
  try {
    await db.connect();
  } catch (e) {
    print('⚠️  Running in mock data mode (database not connected)');
  }

  // Create API handler
  final apiHandler = ApiHandler();

  // Build the handler pipeline with middleware
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders()) // Enable CORS for Flutter web
      .addMiddleware(_handleErrors())
      .addHandler(apiHandler.router.call);

  // Start the server
  final server = await shelf_io.serve(
    handler,
    DbConfig.serverHost,
    DbConfig.serverPort,
  );

  print('');
  print('═══════════════════════════════════════════════════════════');
  print('  🚀 Power Operations API Server');
  print('═══════════════════════════════════════════════════════════');
  print('  Server running at: http://${server.address.host}:${server.port}');
  print(
      '  Health check: http://${server.address.host}:${server.port}/api/health');
  print('═══════════════════════════════════════════════════════════');
  print('');
  print('Available endpoints:');
  print('  GET /api/power-data          - Get paginated power data');
  print('  GET /api/power-data/latest   - Get latest power readings');
  print('  GET /api/power-data/:id      - Get power data by ID');
  print('  GET /api/power-data/statistics - Get power statistics');
  print('  GET /api/chart-data          - Get chart visualization data');
  print('  GET /api/power-operations/stations - Get all stations');
  print('  GET /api/dashboard           - Get dashboard summary');
  print('');

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down server...');
    await db.close();
    await server.close();
    exit(0);
  });
}

/// Error handling middleware
Middleware _handleErrors() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } catch (e, stackTrace) {
        print('Error handling request: $e');
        print(stackTrace);
        return Response.internalServerError(
          body: '{"success": false, "message": "Internal server error"}',
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}
