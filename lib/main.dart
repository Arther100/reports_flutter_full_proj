import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/power_data_provider.dart';
import 'providers/chart_data_provider.dart';
import 'providers/order_provider.dart';
import 'providers/analytics_provider.dart';
import 'services/service_locator.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/power_data_list_screen.dart';
import 'ui/screens/charts_screen.dart';
import 'ui/screens/orders_screen.dart';
import 'ui/screens/analytics_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize service locator for dependency injection
  setupServiceLocator();

  runApp(const PowerOperationsApp());
}

class PowerOperationsApp extends StatelessWidget {
  const PowerOperationsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PowerDataProvider()),
        ChangeNotifierProvider(create: (_) => ChartDataProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ],
      child: MaterialApp(
        title: 'Power Operations',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const MainNavigationScreen(),
        routes: {
          '/dashboard': (context) => const DashboardScreen(),
          '/power-data': (context) => const PowerDataListScreen(),
          '/charts': (context) => const ChartsScreen(),
          '/orders': (context) => const OrdersScreen(),
          '/analytics': (context) => const AnalyticsDashboardScreen(),
        },
      ),
    );
  }
}

/// Main Navigation Screen - Analytics Only
class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnalyticsDashboardScreen();
  }
}
