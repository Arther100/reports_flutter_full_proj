import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../widgets/database_selector.dart';
import 'analytics_dashboard_screen.dart';
import 'powerbi_report_screen.dart';

class MainReportsScreen extends StatefulWidget {
  const MainReportsScreen({super.key});

  @override
  State<MainReportsScreen> createState() => _MainReportsScreenState();
}

class _MainReportsScreenState extends State<MainReportsScreen> {
  // TEMPORARY: Start with PowerBI Reports selected for testing
  int _selectedIndex = 1; // 0 = POS Analytics, 1 = PowerBI Reports
  // TODO: Change back to 0 when restoring user selection

  final List<_NavigationItem> _navigationItems = [
    _NavigationItem(
      icon: Icons.analytics,
      label: 'POS Analytics',
      description: 'Sales, orders, and business metrics',
      screen: const AnalyticsDashboardScreen(),
      databaseType: 'pos',
    ),
    _NavigationItem(
      icon: Icons.store,
      label: 'PowerBI Reports',
      description: 'Category and store-wise sales analysis',
      screen: const PowerBIReportScreen(),
      databaseType: 'powerbi',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dbProvider = context.watch<DatabaseProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Direct screen content without sidebar/appbar
          _navigationItems[_selectedIndex].screen,

          // Loading overlay during database switch
          if (dbProvider.isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTopBar(DatabaseProvider dbProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width <= 900)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Icon(
            _navigationItems[_selectedIndex].icon,
            size: 28,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _navigationItems[_selectedIndex].label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _navigationItems[_selectedIndex].description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: const DatabaseSelector(showAsBanner: true),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDesktopNavigation(DatabaseProvider dbProvider) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[900]!, Colors.blue[700]!],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                return _buildNavigationTile(
                  item: _navigationItems[index],
                  isSelected: _selectedIndex == index,
                  onTap: () => _navigateTo(index, dbProvider),
                );
              },
            ),
          ),
          _buildFooter(dbProvider),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMobileDrawer(DatabaseProvider dbProvider) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[900]!, Colors.blue[700]!],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _navigationItems.length,
                itemBuilder: (context, index) {
                  return _buildNavigationTile(
                    item: _navigationItems[index],
                    isSelected: _selectedIndex == index,
                    onTap: () {
                      Navigator.of(context).pop();
                      _navigateTo(index, dbProvider);
                    },
                  );
                },
              ),
            ),
            _buildFooter(dbProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.assessment, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Reports Portal',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Multi-Database Analytics',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required _NavigationItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(item.icon, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.check, size: 16, color: Colors.blue[700]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(DatabaseProvider dbProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Select Database',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: PopupMenuButton<String>(
              offset: const Offset(0, -10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (databaseId) async {
                final db = dbProvider.availableDatabases.firstWhere(
                  (d) => d.id == databaseId,
                );
                await _switchDatabase(context, dbProvider, db);
              },
              itemBuilder: (context) {
                return dbProvider.availableDatabases.map((database) {
                  final dbColor = _getColorFromHex(database.color);
                  final isSelected =
                      dbProvider.currentDatabase?.id == database.id;

                  return PopupMenuItem<String>(
                    value: database.id,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? dbColor.withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            database.icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  database.name,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? dbColor
                                        : Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  '${database.host}:${database.port}',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.storage, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dbProvider.currentDatabase?.name ??
                                'Select Database',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (dbProvider.currentDatabase != null)
                            Text(
                              '${dbProvider.currentDatabase!.host}:${dbProvider.currentDatabase!.port}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 24),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done, size: 16, color: Colors.green[300]),
                const SizedBox(width: 8),
                Text(
                  'Connected',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchDatabase(
    BuildContext context,
    DatabaseProvider dbProvider,
    dynamic database,
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

  Future<void> _navigateTo(int index, DatabaseProvider dbProvider) async {
    // Don't navigate if no database selected
    if (!dbProvider.hasDatabase) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a database first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final item = _navigationItems[index];

    // Check if we need to switch databases
    if (item.databaseType == 'pos' && !dbProvider.isPOSDatabase) {
      // Need to switch to POS database
      final posDb = dbProvider.availableDatabases.firstWhere(
        (db) => db.id == 'rupos_preprod',
      );

      final success = await dbProvider.switchDatabase(posDb);

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to switch to POS database'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Wait a moment for the provider to update
      await Future.delayed(const Duration(milliseconds: 100));
    } else if (item.databaseType == 'powerbi' &&
        !dbProvider.isPowerBIDatabase) {
      // Need to switch to PowerBI database
      final powerBiDb = dbProvider.availableDatabases.firstWhere(
        (db) => db.id == 'teapioca_fpdb',
      );

      final success = await dbProvider.switchDatabase(powerBiDb);

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to switch to PowerBI database'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Wait a moment for the provider to update
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Change screen after database is ready
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // ignore: unused_element
  Widget _buildNoDatabaseSelected(DatabaseProvider dbProvider) {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 120, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No Database Selected',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please select a database from the dropdown above',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String label;
  final String description;
  final Widget screen;
  final String databaseType; // 'pos' or 'powerbi'

  _NavigationItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.screen,
    required this.databaseType,
  });
}
