/// Database Configuration for Multiple Database Support
class DatabaseConfig {
  final String id;
  final String name;
  final String host;
  final String database;
  final String username;
  final String password;
  final int port;
  final bool isDefault;
  final String icon;
  final String color;

  DatabaseConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.database,
    required this.username,
    required this.password,
    this.port = 1433,
    this.isDefault = false,
    this.icon = '🗄️',
    this.color = '#2196F3',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'database': database,
        'username': username,
        'password': password,
        'port': port,
      };

  factory DatabaseConfig.fromJson(Map<String, dynamic> json) {
    return DatabaseConfig(
      id: json['id'],
      name: json['name'],
      host: json['host'],
      database: json['database'],
      username: json['username'],
      password: json['password'],
      port: json['port'] ?? 1433,
      isDefault: json['isDefault'] ?? false,
      icon: json['icon'] ?? '🗄️',
      color: json['color'] ?? '#2196F3',
    );
  }
}

/// Predefined database configurations
class DatabaseConfigs {
  // POS Analytics Database (RuposPreProd)
  static final ruposPreprod = DatabaseConfig(
    id: 'rupos_preprod',
    name: 'POS Analytics (Rupos)',
    host: '208.91.198.174',
    database: 'RuposPreProd',
    username: 'RuposPreProd',
    password: 'RuposPreProd',
    port: 1433,
    isDefault: true,
    icon: '📊',
    color: '#4CAF50',
  );

  // PowerBI Admin Store Database (TeapiocaFPDB_local)
  static final teapiocaFPDB = DatabaseConfig(
    id: 'teapioca_fpdb',
    name: 'PowerBI Admin Store',
    host: '72.167.50.36',
    database: 'TeapiocaFPDB_local',
    username: 'sa',
    password: 'ciglobal\$123',
    port: 1433,
    isDefault: false,
    icon: '📈',
    color: '#FF9800',
  );

  // List of all available databases
  static List<DatabaseConfig> get allDatabases => [
        ruposPreprod,
        teapiocaFPDB,
      ];

  // Get database by ID
  static DatabaseConfig? getById(String id) {
    try {
      return allDatabases.firstWhere((db) => db.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get default database
  static DatabaseConfig get defaultDatabase =>
      allDatabases.firstWhere((db) => db.isDefault, orElse: () => ruposPreprod);
}
