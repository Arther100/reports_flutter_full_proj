import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../data/models/analytics_model.dart';
import '../core/config/api_config.dart';

// Helper function to safely convert dynamic to int
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

// Helper function to safely convert dynamic to double
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class AnalyticsService {
  // Use ApiConfig for deployment flexibility
  static String get baseUrl => ApiConfig.apiBaseUrl;

  // Execute SQL query with better error handling
  Future<List<Map<String, dynamic>>> _executeQuery(String query) async {
    try {
      print(
        'Executing query: ${query.substring(0, query.length.clamp(0, 100))}...',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      print('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(
          'Response success: ${data['success']}, rowCount: ${data['rowCount']}',
        );
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Query error: $e');
      return [];
    }
  }

  // Helper to build store filter clause
  String _buildStoreFilter(List<String> storeIds, String alias) {
    if (storeIds.isEmpty) return '';
    final ids = storeIds.map((id) => "'$id'").join(', ');
    return "AND $alias.StoreID IN ($ids)";
  }

  // Get all stores
  Future<List<Store>> getAllStores() async {
    final query = '''
      SELECT id as StoreID, name as StoreName, '' as StoreType, '' as City 
      FROM allstoresdetails 
      ORDER BY name
    ''';
    final result = await _executeQuery(query);
    return result.map((e) => Store.fromJson(e)).toList();
  }

  // Get Sales Overview - Using ORDERDETAILS table
  Future<SalesOverview> getSalesOverview(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final storeFilter = _buildStoreFilter(storeIds, 'od');

    final query =
        '''
      SELECT 
        ISNULL(SUM(od.ProductAmount), 0) as totalSales,
        COUNT(DISTINCT od.OrderID) as totalOrders,
        ISNULL(SUM(od.ProductAmount) / NULLIF(COUNT(DISTINCT od.OrderID), 0), 0) as avgOrderValue,
        COUNT(DISTINCT od.ProductID) as totalProducts,
        COUNT(DISTINCT od.CustomerID) as uniqueCustomers,
        ISNULL(SUM(od.TaxAmount), 0) as taxCollected,
        0 as discountGiven,
        ISNULL(SUM(od.ProductAmount), 0) as netRevenue
      FROM ORDERDETAILS od
      WHERE od.OrderDate >= '$startDate' AND od.OrderDate <= '$endDate 23:59:59'
      $storeFilter
    ''';

    final result = await _executeQuery(query);
    if (result.isNotEmpty) {
      return SalesOverview.fromJson(result.first);
    }
    return SalesOverview.empty();
  }

  // Get Sales Trend (Daily/Weekly/Monthly)
  Future<List<SalesTrend>> getSalesTrend(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final days = filter.daysDifference;
    final storeFilter = _buildStoreFilter(storeIds, 'ORDERDETAILS');

    String dateFormat;
    String groupBy;

    if (days <= 7) {
      dateFormat = "CONVERT(varchar, OrderDate, 23)";
      groupBy = "CONVERT(varchar, OrderDate, 23)";
    } else if (days <= 31) {
      dateFormat = "CONVERT(varchar, OrderDate, 23)";
      groupBy = "CONVERT(varchar, OrderDate, 23)";
    } else {
      dateFormat =
          "CONVERT(varchar, DATEADD(WEEK, DATEDIFF(WEEK, 0, OrderDate), 0), 23)";
      groupBy = "DATEADD(WEEK, DATEDIFF(WEEK, 0, OrderDate), 0)";
    }

    final query =
        '''
      SELECT 
        $dateFormat as date,
        ISNULL(SUM(ProductAmount), 0) as sales,
        COUNT(DISTINCT OrderID) as orders,
        ISNULL(SUM(ProductAmount) / NULLIF(COUNT(DISTINCT OrderID), 0), 0) as avgValue
      FROM ORDERDETAILS
      WHERE OrderDate >= '$startDate' AND OrderDate <= '$endDate 23:59:59'
      $storeFilter
      GROUP BY $groupBy
      ORDER BY $groupBy
    ''';

    final result = await _executeQuery(query);
    return result.map((e) => SalesTrend.fromJson(e)).toList();
  }

  // Get Top Products - Using ORDERDETAILS
  Future<List<ProductSales>> getTopProducts(
    DateRangeFilter filter, {
    int limit = 10,
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final storeFilter = _buildStoreFilter(storeIds, 'od');

    final query =
        '''
      SELECT TOP $limit
        od.ProductID as productId,
        ISNULL(p.ProductName, 'Unknown Product') as productName,
        SUM(od.ProductQty) as quantitySold,
        SUM(od.ProductAmount) as totalRevenue,
        AVG(od.ProductPrice) as avgPrice,
        COUNT(DISTINCT od.OrderID) as orderCount
      FROM ORDERDETAILS od
      LEFT JOIN PRODUCTS p ON od.ProductID = p.ProductID
      WHERE od.OrderDate >= '$startDate' AND od.OrderDate <= '$endDate 23:59:59'
      $storeFilter
      GROUP BY od.ProductID, p.ProductName
      ORDER BY totalRevenue DESC
    ''';

    final result = await _executeQuery(query);
    final products = result.map((e) => ProductSales.fromJson(e)).toList();

    // Calculate contribution percentage
    final totalRevenue = products.fold<double>(
      0,
      (sum, p) => sum + p.totalRevenue,
    );
    return products
        .map(
          (p) => ProductSales(
            productId: p.productId,
            productName: p.productName,
            quantitySold: p.quantitySold,
            totalRevenue: p.totalRevenue,
            avgPrice: p.avgPrice,
            orderCount: p.orderCount,
            contributionPercentage: totalRevenue > 0
                ? (p.totalRevenue / totalRevenue * 100)
                : 0,
          ),
        )
        .toList();
  }

  // Get Category Sales
  Future<List<CategorySales>> getCategorySales(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final storeFilter = _buildStoreFilter(storeIds, 'od');

    final query =
        '''
      SELECT 
        c.CategoryID as categoryId,
        ISNULL(c.CategoryName, 'Uncategorized') as categoryName,
        COUNT(DISTINCT p.ProductID) as productCount,
        ISNULL(SUM(od.ProductAmount), 0) as totalRevenue,
        ISNULL(SUM(od.ProductQty), 0) as quantitySold
      FROM ORDERDETAILS od
      LEFT JOIN PRODUCTS p ON od.ProductID = p.ProductID
      LEFT JOIN CATEGORY c ON p.CategoryID = c.CategoryID
      WHERE od.OrderDate >= '$startDate' AND od.OrderDate <= '$endDate 23:59:59'
      $storeFilter
      GROUP BY c.CategoryID, c.CategoryName
      ORDER BY totalRevenue DESC
    ''';

    final result = await _executeQuery(query);
    final categories = result.map((e) => CategorySales.fromJson(e)).toList();

    // Calculate percentage
    final totalRevenue = categories.fold<double>(
      0,
      (sum, c) => sum + c.totalRevenue,
    );
    return categories
        .map(
          (c) => CategorySales(
            categoryId: c.categoryId,
            categoryName: c.categoryName,
            productCount: c.productCount,
            totalRevenue: c.totalRevenue,
            quantitySold: c.quantitySold,
            percentage: totalRevenue > 0
                ? (c.totalRevenue / totalRevenue * 100)
                : 0,
          ),
        )
        .toList();
  }

  // Get Payment Analytics
  Future<List<PaymentAnalytics>> getPaymentAnalytics(
    DateRangeFilter filter,
  ) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];

    final query =
        '''
      SELECT 
        ISNULL(p.PaymentMethod, '0') as paymentMethod,
        COUNT(*) as transactionCount,
        SUM(p.Totalamount) as totalAmount,
        AVG(p.Totalamount) as avgTransactionValue
      FROM PAYMENTS p
      WHERE p.PaymentDate >= '$startDate' AND p.PaymentDate <= '$endDate 23:59:59'
      GROUP BY p.PaymentMethod
      ORDER BY totalAmount DESC
    ''';

    final result = await _executeQuery(query);
    final payments = result.map((e) => PaymentAnalytics.fromJson(e)).toList();

    // Calculate percentage
    final totalAmount = payments.fold<double>(
      0,
      (sum, p) => sum + p.totalAmount,
    );
    return payments
        .map(
          (p) => PaymentAnalytics(
            paymentMethod: p.paymentMethod,
            paymentMethodName: p.paymentMethodName,
            transactionCount: p.transactionCount,
            totalAmount: p.totalAmount,
            avgTransactionValue: p.avgTransactionValue,
            percentage: totalAmount > 0
                ? (p.totalAmount / totalAmount * 100)
                : 0,
          ),
        )
        .toList();
  }

  // Get Top Customers
  Future<List<CustomerAnalytics>> getTopCustomers(
    DateRangeFilter filter, {
    int limit = 10,
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final storeFilter = _buildStoreFilter(storeIds, 'od');

    final query =
        '''
      SELECT TOP $limit
        od.CustomerID as customerId,
        ISNULL(c.CustomerName, 'Guest Customer') as customerName,
        ISNULL(c.MobileNumber, '') as mobileNumber,
        COUNT(DISTINCT od.OrderID) as orderCount,
        ISNULL(SUM(od.ProductAmount), 0) as totalSpent,
        ISNULL(SUM(od.ProductAmount) / NULLIF(COUNT(DISTINCT od.OrderID), 0), 0) as avgOrderValue,
        MAX(od.OrderDate) as lastOrderDate
      FROM ORDERDETAILS od
      LEFT JOIN CUSTOMERS c ON od.CustomerID = c.CustomerID
      WHERE od.OrderDate >= '$startDate' AND od.OrderDate <= '$endDate 23:59:59'
        AND od.CustomerID IS NOT NULL
        AND od.CustomerID != '00000000-0000-0000-0000-000000000000'
        $storeFilter
      GROUP BY od.CustomerID, c.CustomerName, c.MobileNumber
      ORDER BY totalSpent DESC
    ''';

    final result = await _executeQuery(query);
    return result.map((e) => CustomerAnalytics.fromJson(e)).toList();
  }

  // Get Store Sales with Store Type
  Future<List<StoreSales>> getStoreSales(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final storeFilter = _buildStoreFilter(storeIds, 'od');

    final query =
        '''
      WITH TotalSales AS (
        SELECT ISNULL(SUM(ProductAmount), 0) as grandTotal
        FROM ORDERDETAILS
        WHERE OrderDate >= '$startDate' AND OrderDate <= '$endDate 23:59:59'
        $storeFilter
      )
      SELECT 
        od.StoreID as storeId,
        ISNULL(s.StoreName, 'Unknown Store') as storeName,
        ISNULL(s.City, '') as city,
        ISNULL(s.StoreType, 1) as storeType,
        ISNULL(SUM(od.ProductAmount), 0) as totalSales,
        COUNT(DISTINCT od.OrderID) as orderCount,
        ISNULL(SUM(od.ProductAmount) / NULLIF(COUNT(DISTINCT od.OrderID), 0), 0) as avgOrderValue,
        CASE 
          WHEN (SELECT grandTotal FROM TotalSales) > 0 
          THEN (ISNULL(SUM(od.ProductAmount), 0) * 100.0 / (SELECT grandTotal FROM TotalSales))
          ELSE 0 
        END as salesContribution
      FROM ORDERDETAILS od
      LEFT JOIN STORES s ON od.StoreID = s.StoreID
      WHERE od.OrderDate >= '$startDate' AND od.OrderDate <= '$endDate 23:59:59'
      GROUP BY od.StoreID, s.StoreName, s.City, s.StoreType
      ORDER BY totalSales DESC
    ''';

    final result = await _executeQuery(query);
    return result.map((e) => StoreSales.fromJson(e)).toList();
  }

  // Get Store Type Summary for drill-down
  Future<List<StoreTypeSummary>> getStoreTypeSummary(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final stores = await getStoreSales(filter, storeIds: storeIds);

    // Group stores by type
    final Map<StoreType, List<StoreSales>> groupedStores = {};
    double grandTotal = 0;

    for (final store in stores) {
      grandTotal += store.totalSales;
      groupedStores.putIfAbsent(store.storeType, () => []).add(store);
    }

    // Create summaries
    final summaries = <StoreTypeSummary>[];
    for (final type in StoreType.values) {
      final typeStores = groupedStores[type] ?? [];
      if (typeStores.isEmpty) continue;

      final totalSales = typeStores.fold(0.0, (sum, s) => sum + s.totalSales);
      final orderCount = typeStores.fold(0, (sum, s) => sum + s.orderCount);

      summaries.add(
        StoreTypeSummary(
          storeType: type,
          totalSales: totalSales,
          orderCount: orderCount,
          storeCount: typeStores.length,
          avgOrderValue: orderCount > 0 ? totalSales / orderCount : 0,
          salesPercentage: grandTotal > 0 ? (totalSales / grandTotal) * 100 : 0,
          stores: typeStores,
        ),
      );
    }

    // Sort by total sales descending
    summaries.sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return summaries;
  }

  // Get Customer Type Summary (Walk-in vs Regular)
  Future<List<CustomerTypeSummary>> getCustomerTypeSummary(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final storeFilter = _buildStoreFilter(storeIds, 'ORDERDETAILS');

    final query =
        '''
      WITH SalesByType AS (
        SELECT 
          CASE 
            WHEN CustomerID IS NULL OR CustomerID = '00000000-0000-0000-0000-000000000000' 
            THEN 'walk_in' 
            ELSE 'regular' 
          END as customerType,
          ISNULL(SUM(ProductAmount), 0) as totalSales,
          COUNT(DISTINCT OrderID) as orderCount,
          COUNT(DISTINCT CustomerID) as customerCount,
          ISNULL(SUM(ProductAmount) / NULLIF(COUNT(DISTINCT OrderID), 0), 0) as avgOrderValue
        FROM ORDERDETAILS
        WHERE OrderDate >= '$startDate' AND OrderDate <= '$endDate 23:59:59'
        $storeFilter
        GROUP BY CASE 
          WHEN CustomerID IS NULL OR CustomerID = '00000000-0000-0000-0000-000000000000' 
          THEN 'walk_in' 
          ELSE 'regular' 
        END
      ),
      GrandTotal AS (
        SELECT ISNULL(SUM(ProductAmount), 0) as total
        FROM ORDERDETAILS
        WHERE OrderDate >= '$startDate' AND OrderDate <= '$endDate 23:59:59'
        $storeFilter
      )
      SELECT 
        s.customerType,
        s.totalSales,
        s.orderCount,
        s.customerCount,
        s.avgOrderValue,
        CASE WHEN g.total > 0 THEN (s.totalSales * 100.0 / g.total) ELSE 0 END as salesPercentage
      FROM SalesByType s
      CROSS JOIN GrandTotal g
      ORDER BY s.totalSales DESC
    ''';

    final result = await _executeQuery(query);
    return result
        .map(
          (e) => CustomerTypeSummary(
            customerType: e['customerType'] == 'walk_in'
                ? CustomerType.walkIn
                : CustomerType.regular,
            totalSales: _toDouble(e['totalSales']),
            orderCount: _toInt(e['orderCount']),
            customerCount: _toInt(e['customerCount']),
            avgOrderValue: _toDouble(e['avgOrderValue']),
            salesPercentage: _toDouble(e['salesPercentage']),
          ),
        )
        .toList();
  }

  // Get drill-down data for a specific store type
  Future<DrillDownData> getStoreTypeDrillDown(
    StoreType type,
    DateRangeFilter filter,
  ) async {
    final stores = await getStoreSales(filter);
    final typeStores = stores.where((s) => s.storeType == type).toList();

    final totalValue = typeStores.fold(0.0, (sum, s) => sum + s.totalSales);

    return DrillDownData(
      title: type.displayName,
      subtitle: type.description,
      items: typeStores
          .map(
            (s) => DrillDownItem(
              id: s.storeId,
              name: s.storeName,
              subtitle: s.city.isNotEmpty ? s.city : null,
              value: s.totalSales,
              percentage: totalValue > 0
                  ? (s.totalSales / totalValue) * 100
                  : 0,
              count: s.orderCount,
              metadata: {
                'avgOrderValue': s.avgOrderValue,
                'storeType': s.storeType.displayName,
              },
            ),
          )
          .toList(),
      totalValue: totalValue,
    );
  }

  // Get Hourly Sales Pattern
  Future<List<HourlySales>> getHourlySales(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final storeFilter = _buildStoreFilter(storeIds, 'ORDERDETAILS');

    final query =
        '''
      SELECT 
        DATEPART(HOUR, OrderDate) as hour,
        ISNULL(SUM(ProductAmount), 0) as sales,
        COUNT(DISTINCT OrderID) as orders
      FROM ORDERDETAILS
      WHERE OrderDate >= '$startDate' AND OrderDate <= '$endDate 23:59:59'
      $storeFilter
      GROUP BY DATEPART(HOUR, OrderDate)
      ORDER BY hour
    ''';

    final result = await _executeQuery(query);

    // Fill missing hours with zero
    final hourlyMap = <int, HourlySales>{};
    for (final r in result) {
      hourlyMap[r['hour'] ?? 0] = HourlySales.fromJson(r);
    }

    return List.generate(
      24,
      (hour) => hourlyMap[hour] ?? HourlySales(hour: hour, sales: 0, orders: 0),
    );
  }

  // Generate Sales Predictions using advanced algorithms
  // Combines: Moving Average, Exponential Smoothing, and Trend Analysis
  List<SalesPrediction> generateSalesPredictions(
    List<SalesTrend> historicalData,
  ) {
    if (historicalData.length < 3) return [];

    final predictions = <SalesPrediction>[];

    // Use more data if available (up to 30 days)
    final recentData = historicalData.length > 30
        ? historicalData.sublist(historicalData.length - 30)
        : historicalData;

    // 1. Calculate weighted moving average (recent data weighted more)
    double weightedSum = 0;
    double weightTotal = 0;
    for (int i = 0; i < recentData.length; i++) {
      final weight = (i + 1) / recentData.length; // Linear weighting
      weightedSum += recentData[i].sales * weight;
      weightTotal += weight;
    }
    final weightedAvg = weightedSum / weightTotal;

    // 2. Exponential smoothing (alpha = 0.3 for recent emphasis)
    const alpha = 0.3;
    double smoothedValue = recentData.first.sales;
    for (final trend in recentData) {
      smoothedValue = alpha * trend.sales + (1 - alpha) * smoothedValue;
    }

    // 3. Calculate trend using linear regression
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < recentData.length; i++) {
      sumX += i;
      sumY += recentData[i].sales;
      sumXY += i * recentData[i].sales;
      sumX2 += i * i;
    }
    final n = recentData.length.toDouble();
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // 4. Calculate seasonality (day of week pattern if enough data)
    final dayOfWeekAvg = <int, List<double>>{};
    for (final trend in recentData) {
      final dow = trend.date.weekday;
      dayOfWeekAvg.putIfAbsent(dow, () => []);
      dayOfWeekAvg[dow]!.add(trend.sales);
    }
    final seasonalFactors = <int, double>{};
    final overallAvg =
        recentData.fold<double>(0, (s, t) => s + t.sales) / recentData.length;
    for (final entry in dayOfWeekAvg.entries) {
      final avg =
          entry.value.fold<double>(0, (s, v) => s + v) / entry.value.length;
      seasonalFactors[entry.key] = overallAvg > 0 ? avg / overallAvg : 1.0;
    }

    // 5. Calculate confidence based on variance
    final variance =
        recentData.fold<double>(
          0,
          (sum, t) => sum + math.pow(t.sales - overallAvg, 2),
        ) /
        recentData.length;
    final stdDev = math.sqrt(variance);
    final coefficientOfVariation = overallAvg > 0 ? stdDev / overallAvg : 0.5;

    // 6. Determine trend direction
    final trendDirection = slope > (overallAvg * 0.01)
        ? 'up'
        : (slope < -(overallAvg * 0.01) ? 'down' : 'stable');

    // 7. Generate predictions for next 7 days
    final lastDate = historicalData.last.date;
    for (int i = 1; i <= 7; i++) {
      final predictedDate = lastDate.add(Duration(days: i));
      final dayOfWeek = predictedDate.weekday;

      // Combine methods: weighted average of regression, smoothing, and weighted avg
      final regressionValue = intercept + slope * (recentData.length + i - 1);
      final baseValue =
          (regressionValue * 0.4) +
          (smoothedValue * 0.35) +
          (weightedAvg * 0.25);

      // Apply seasonal adjustment
      final seasonalFactor = seasonalFactors[dayOfWeek] ?? 1.0;
      final predictedSales = (math.max(0.0, baseValue * seasonalFactor) as num)
          .toDouble();

      // Confidence decreases with prediction distance and data variability
      final distancePenalty = i * 0.04;
      final variabilityPenalty =
          (math.min(0.3, coefficientOfVariation * 0.5) as num).toDouble();
      final confidence =
          (math.max(0.5, 0.95 - distancePenalty - variabilityPenalty) as num)
              .toDouble();

      predictions.add(
        SalesPrediction(
          predictedDate: predictedDate,
          predictedSales: predictedSales,
          confidenceLevel: confidence,
          lowerBound:
              (math.max(0.0, predictedSales - (stdDev * 1.96 * (1 + i * 0.1)))
                      as num)
                  .toDouble(),
          upperBound: (predictedSales + (stdDev * 1.96 * (1 + i * 0.1)))
              .toDouble(),
          trend: trendDirection,
        ),
      );
    }

    return predictions;
  }

  // Generate Product Predictions
  Future<List<ProductPrediction>> generateProductPredictions(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final currentProducts = await getTopProducts(
      filter,
      limit: 20,
      storeIds: storeIds,
    );

    // Get previous period data for comparison
    final prevFilter = DateRangeFilter.custom(
      filter.startDate.subtract(Duration(days: filter.daysDifference)),
      filter.startDate.subtract(const Duration(days: 1)),
    );
    final previousProducts = await getTopProducts(
      prevFilter,
      limit: 50,
      storeIds: storeIds,
    );

    final previousMap = {for (var p in previousProducts) p.productId: p};

    return currentProducts.map((current) {
      final previous = previousMap[current.productId];
      final currentDemand = current.quantitySold.toDouble();
      final previousDemand = previous?.quantitySold.toDouble() ?? currentDemand;

      double demandGrowth = previousDemand > 0
          ? ((currentDemand - previousDemand) / previousDemand * 100)
          : 0;

      final predictedDemand = currentDemand * (1 + demandGrowth / 100);

      String recommendation;
      if (demandGrowth > 20) {
        recommendation = 'increase_stock';
      } else if (demandGrowth < -20) {
        recommendation = 'reduce_stock';
      } else {
        recommendation = 'maintain';
      }

      return ProductPrediction(
        productId: current.productId,
        productName: current.productName,
        currentDemand: currentDemand,
        predictedDemand: predictedDemand,
        demandGrowth: demandGrowth,
        recommendation: recommendation,
        confidenceScore: 0.75,
      );
    }).toList();
  }

  // Calculate Fill Rates
  Future<OverallFillRate> calculateFillRates(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    final startDate = filter.startDate.toIso8601String().split('T')[0];
    final endDate = filter.endDate.toIso8601String().split('T')[0];
    final storeFilter = _buildStoreFilter(storeIds, 'od');

    // Since we don't have inventory data, we'll estimate based on order fulfillment
    final query =
        '''
      SELECT 
        od.ProductID as productId,
        ISNULL(p.ProductName, 'Unknown') as productName,
        SUM(od.ProductQty) as orderedQuantity,
        SUM(od.ProductQty) as fulfilledQuantity,
        0 as stockouts
      FROM ORDERDETAILS od
      LEFT JOIN PRODUCTS p ON od.ProductID = p.ProductID
      WHERE od.OrderDate >= '$startDate' AND od.OrderDate <= '$endDate 23:59:59'
      $storeFilter
      GROUP BY od.ProductID, p.ProductName
      ORDER BY orderedQuantity DESC
    ''';

    final result = await _executeQuery(query);

    final productFillRates = result
        .map(
          (r) => FillRate.calculate(
            productId: r['productId']?.toString() ?? '',
            productName: r['productName'] ?? 'Unknown',
            orderedQuantity: _toInt(r['orderedQuantity']),
            fulfilledQuantity: _toInt(r['fulfilledQuantity']),
            stockouts: _toInt(r['stockouts']),
          ),
        )
        .toList();

    final totalOrdered = productFillRates.fold<int>(
      0,
      (sum, f) => sum + f.orderedQuantity,
    );
    final totalFulfilled = productFillRates.fold<int>(
      0,
      (sum, f) => sum + f.fulfilledQuantity,
    );
    final totalStockouts = productFillRates.fold<int>(
      0,
      (sum, f) => sum + f.stockouts,
    );

    return OverallFillRate(
      overallPercentage: totalOrdered > 0
          ? (totalFulfilled / totalOrdered * 100)
          : 100,
      totalOrdered: totalOrdered,
      totalFulfilled: totalFulfilled,
      totalStockouts: totalStockouts,
      productFillRates: productFillRates.take(10).toList(),
      categoryFillRates: {},
    );
  }

  // Get complete dashboard data
  Future<AnalyticsDashboard> getDashboardData(
    DateRangeFilter filter, {
    List<String> storeIds = const [],
  }) async {
    try {
      // Fetch all data in parallel for faster loading
      final results = await Future.wait([
        getSalesOverview(filter, storeIds: storeIds),
        getSalesTrend(filter, storeIds: storeIds),
        getTopProducts(filter, storeIds: storeIds),
        getCategorySales(filter, storeIds: storeIds),
        getPaymentAnalytics(filter),
        getTopCustomers(filter, storeIds: storeIds),
        getStoreSales(filter, storeIds: storeIds),
        getHourlySales(filter, storeIds: storeIds),
        generateProductPredictions(filter, storeIds: storeIds),
        calculateFillRates(filter, storeIds: storeIds),
      ]);

      final salesOverview = results[0] as SalesOverview;
      final salesTrend = results[1] as List<SalesTrend>;
      final topProducts = results[2] as List<ProductSales>;
      final categorySales = results[3] as List<CategorySales>;
      final paymentAnalytics = results[4] as List<PaymentAnalytics>;
      final topCustomers = results[5] as List<CustomerAnalytics>;
      final storeSales = results[6] as List<StoreSales>;
      final hourlySales = results[7] as List<HourlySales>;
      final productPredictions = results[8] as List<ProductPrediction>;
      final fillRate = results[9] as OverallFillRate;

      // Generate sales predictions from trend data
      final salesPredictions = generateSalesPredictions(salesTrend);

      return AnalyticsDashboard(
        salesOverview: salesOverview,
        salesTrend: salesTrend,
        topProducts: topProducts,
        categorySales: categorySales,
        paymentAnalytics: paymentAnalytics,
        topCustomers: topCustomers,
        storeSales: storeSales,
        hourlySales: hourlySales,
        salesPredictions: salesPredictions,
        productPredictions: productPredictions,
        fillRate: fillRate,
        dateFilter: filter,
      );
    } catch (e) {
      print('Dashboard error: $e');
      return AnalyticsDashboard.empty();
    }
  }
}
