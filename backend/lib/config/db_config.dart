import 'package:dotenv/dotenv.dart';

/// Database configuration from environment variables
class DbConfig {
  static late DotEnv _env;

  static void initialize() {
    _env = DotEnv(includePlatformEnvironment: true)..load();
  }

  static String get server => _env['DB_SERVER'] ?? 'localhost';
  static int get port => int.tryParse(_env['DB_PORT'] ?? '1433') ?? 1433;
  static String get database => _env['DB_NAME'] ?? '';
  static String get username => _env['DB_USER'] ?? '';
  static String get password => _env['DB_PASSWORD'] ?? '';

  static int get serverPort => int.tryParse(_env['PORT'] ?? '3000') ?? 3000;
  static String get serverHost => _env['HOST'] ?? 'localhost';
  static bool get debug => _env['DEBUG']?.toLowerCase() == 'true';

  /// Build connection string for MS SQL
  static String get connectionString {
    return 'Server=$server,$port;Database=$database;User Id=$username;Password=$password;TrustServerCertificate=true;';
  }

  static void validate() {
    final errors = <String>[];

    if (server.isEmpty || server == 'YOUR_SERVER_NAME') {
      errors.add('DB_SERVER is not configured');
    }
    if (database.isEmpty || database == 'YOUR_DATABASE_NAME') {
      errors.add('DB_NAME is not configured');
    }
    if (username.isEmpty || username == 'YOUR_USERNAME') {
      errors.add('DB_USER is not configured');
    }
    if (password.isEmpty || password == 'YOUR_PASSWORD') {
      errors.add('DB_PASSWORD is not configured');
    }

    if (errors.isNotEmpty) {
      print('⚠️  Configuration errors:');
      for (final error in errors) {
        print('   - $error');
      }
      print('\nPlease update your .env file with valid database credentials.');
      print('Copy .env.example to .env and fill in the values.\n');
    }
  }
}
