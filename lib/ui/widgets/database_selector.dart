import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../core/config/database_config.dart';

class DatabaseSelector extends StatelessWidget {
  final bool showAsBanner;

  const DatabaseSelector({super.key, this.showAsBanner = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseProvider>(
      builder: (context, dbProvider, child) {
        if (showAsBanner) {
          return _buildBanner(context, dbProvider);
        }
        return _buildDropdown(context, dbProvider);
      },
    );
  }

  Widget _buildBanner(BuildContext context, DatabaseProvider dbProvider) {
    final db = dbProvider.currentDatabase;

    if (db == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storage, size: 20, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            const Text(
              'Select Database',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            _buildSwitchButton(context, dbProvider),
          ],
        ),
      );
    }

    final color = _getColorFromHex(db.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(db.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Database',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                db.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _buildSwitchButton(context, dbProvider),
        ],
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, DatabaseProvider dbProvider) {
    final db = dbProvider.currentDatabase;

    if (db == null) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
        ),
        child: PopupMenuButton<DatabaseConfig>(
          offset: const Offset(0, 60),
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (database) =>
              _switchDatabase(context, dbProvider, database),
          itemBuilder: (context) {
            return dbProvider.availableDatabases.map((database) {
              final dbColor = _getColorFromHex(database.color);

              return PopupMenuItem<DatabaseConfig>(
                value: database,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      Text(database.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              database.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dbColor,
                              ),
                            ),
                            Text(
                              '${database.host} • ${database.database}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.storage, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select Database',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      );
    }

    final color = _getColorFromHex(db.color);

    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: PopupMenuButton<DatabaseConfig>(
        offset: const Offset(0, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (database) =>
            _switchDatabase(context, dbProvider, database),
        itemBuilder: (context) {
          return dbProvider.availableDatabases.map((database) {
            final dbColor = _getColorFromHex(database.color);
            final isSelected = database.id == db.id;

            return PopupMenuItem<DatabaseConfig>(
              value: database,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? dbColor.withOpacity(0.1) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: dbColor.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: dbColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        database.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            database.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: dbColor,
                            ),
                          ),
                          Text(
                            '${database.host} • ${database.database}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: dbColor, size: 20),
                  ],
                ),
              ),
            );
          }).toList();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(db.icon, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      db.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dbProvider.currentTables.isNotEmpty)
                      Text(
                        '${dbProvider.currentTables.length} tables',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchButton(BuildContext context, DatabaseProvider dbProvider) {
    return PopupMenuButton<DatabaseConfig>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.sync_alt, size: 20),
      ),
      offset: const Offset(0, 50),
      elevation: 24,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (database) => _switchDatabase(context, dbProvider, database),
      itemBuilder: (context) {
        return dbProvider.availableDatabases
            .where((db) => db.id != dbProvider.currentDatabase?.id)
            .map((database) {
              final dbColor = _getColorFromHex(database.color);

              return PopupMenuItem<DatabaseConfig>(
                value: database,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        dbColor.withOpacity(0.1),
                        dbColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dbColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Text(database.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              database.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dbColor,
                              ),
                            ),
                            Text(
                              'Switch to ${database.database}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: dbColor, size: 18),
                    ],
                  ),
                ),
              );
            })
            .toList();
      },
    );
  }

  void _switchDatabase(
    BuildContext context,
    DatabaseProvider dbProvider,
    DatabaseConfig database,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(
                  _getColorFromHex(database.color),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Switching to ${database.name}...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    final success = await dbProvider.switchDatabase(database);

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(database.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text('Switched to ${database.name}')),
              ],
            ),
            backgroundColor: _getColorFromHex(database.color),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to switch database: ${dbProvider.errorMessage ?? "Unknown error"}',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
