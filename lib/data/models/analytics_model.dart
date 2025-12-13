// Analytics Models for POS Sales & Backoffice Orders Data

// Helper functions to safely parse numbers from JSON
int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

// Store model for filtering
class Store {
  final String storeId;
  final String storeName;
  final String city;
  final int storeType;

  Store({
    required this.storeId,
    required this.storeName,
    required this.city,
    required this.storeType,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeId: json['StoreID']?.toString() ?? '',
      storeName: json['StoreName']?.toString() ?? 'Unknown Store',
      city: json['City']?.toString() ?? '',
      storeType: _parseInt(json['StoreType']),
    );
  }

  String get storeTypeName {
    switch (storeType) {
      case 1:
        return 'Walk-in';
      case 2:
        return 'Advance';
      case 3:
        return 'Centralized Kitchen';
      default:
        return 'Other';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store &&
          runtimeType == other.runtimeType &&
          storeId == other.storeId;

  @override
  int get hashCode => storeId.hashCode;
}

class SalesOverview {
  final double totalSales;
  final int totalOrders;
  final double avgOrderValue;
  final int totalProducts;
  final int uniqueCustomers;
  final double taxCollected;
  final double discountGiven;
  final double netRevenue;
  final double growthPercentage;
  final double previousPeriodSales;

  SalesOverview({
    required this.totalSales,
    required this.totalOrders,
    required this.avgOrderValue,
    required this.totalProducts,
    required this.uniqueCustomers,
    required this.taxCollected,
    required this.discountGiven,
    required this.netRevenue,
    this.growthPercentage = 0,
    this.previousPeriodSales = 0,
  });

  factory SalesOverview.fromJson(Map<String, dynamic> json) {
    return SalesOverview(
      totalSales: _parseDouble(json['totalSales']),
      totalOrders: _parseInt(json['totalOrders']),
      avgOrderValue: _parseDouble(json['avgOrderValue']),
      totalProducts: _parseInt(json['totalProducts']),
      uniqueCustomers: _parseInt(json['uniqueCustomers']),
      taxCollected: _parseDouble(json['taxCollected']),
      discountGiven: _parseDouble(json['discountGiven']),
      netRevenue: _parseDouble(json['netRevenue']),
      growthPercentage: _parseDouble(json['growthPercentage']),
      previousPeriodSales: _parseDouble(json['previousPeriodSales']),
    );
  }

  factory SalesOverview.empty() {
    return SalesOverview(
      totalSales: 0,
      totalOrders: 0,
      avgOrderValue: 0,
      totalProducts: 0,
      uniqueCustomers: 0,
      taxCollected: 0,
      discountGiven: 0,
      netRevenue: 0,
    );
  }
}

class SalesTrend {
  final DateTime date;
  final double sales;
  final int orders;
  final double avgValue;

  SalesTrend({
    required this.date,
    required this.sales,
    required this.orders,
    required this.avgValue,
  });

  factory SalesTrend.fromJson(Map<String, dynamic> json) {
    return SalesTrend(
      date: DateTime.parse(json['date'].toString()),
      sales: _parseDouble(json['sales']),
      orders: _parseInt(json['orders']),
      avgValue: _parseDouble(json['avgValue']),
    );
  }
}

class ProductSales {
  final String productId;
  final String productName;
  final int quantitySold;
  final double totalRevenue;
  final double avgPrice;
  final int orderCount;
  final double contributionPercentage;
  final double growthRate;

  ProductSales({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.avgPrice,
    required this.orderCount,
    this.contributionPercentage = 0,
    this.growthRate = 0,
  });

  factory ProductSales.fromJson(Map<String, dynamic> json) {
    return ProductSales(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName'] ?? 'Unknown Product',
      quantitySold: _parseInt(json['quantitySold']),
      totalRevenue: _parseDouble(json['totalRevenue']),
      avgPrice: _parseDouble(json['avgPrice']),
      orderCount: _parseInt(json['orderCount']),
      contributionPercentage: _parseDouble(json['contributionPercentage']),
      growthRate: _parseDouble(json['growthRate']),
    );
  }
}

class CategorySales {
  final String categoryId;
  final String categoryName;
  final int productCount;
  final double totalRevenue;
  final int quantitySold;
  final double percentage;

  CategorySales({
    required this.categoryId,
    required this.categoryName,
    required this.productCount,
    required this.totalRevenue,
    required this.quantitySold,
    this.percentage = 0,
  });

  factory CategorySales.fromJson(Map<String, dynamic> json) {
    return CategorySales(
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName'] ?? 'Unknown Category',
      productCount: _parseInt(json['productCount']),
      totalRevenue: _parseDouble(json['totalRevenue']),
      quantitySold: _parseInt(json['quantitySold']),
      percentage: _parseDouble(json['percentage']),
    );
  }
}

class PaymentAnalytics {
  final String paymentMethod;
  final String paymentMethodName;
  final int transactionCount;
  final double totalAmount;
  final double percentage;
  final double avgTransactionValue;

  PaymentAnalytics({
    required this.paymentMethod,
    required this.paymentMethodName,
    required this.transactionCount,
    required this.totalAmount,
    this.percentage = 0,
    required this.avgTransactionValue,
  });

  factory PaymentAnalytics.fromJson(Map<String, dynamic> json) {
    String methodName = _getPaymentMethodName(
      json['paymentMethod']?.toString() ?? '0',
    );
    return PaymentAnalytics(
      paymentMethod: json['paymentMethod']?.toString() ?? '0',
      paymentMethodName: methodName,
      transactionCount: _parseInt(json['transactionCount']),
      totalAmount: _parseDouble(json['totalAmount']),
      percentage: _parseDouble(json['percentage']),
      avgTransactionValue: _parseDouble(json['avgTransactionValue']),
    );
  }

  static String _getPaymentMethodName(String code) {
    switch (code) {
      case '0':
        return 'Cash';
      case '1':
        return 'Card';
      case '2':
        return 'UPI';
      case '3':
        return 'Wallet';
      case '4':
        return 'Net Banking';
      case '5':
        return 'Credit';
      default:
        return 'Other';
    }
  }
}

class CustomerAnalytics {
  final String customerId;
  final String customerName;
  final String mobileNumber;
  final int orderCount;
  final double totalSpent;
  final double avgOrderValue;
  final DateTime? lastOrderDate;
  final String loyaltyTier;
  final double lifetimeValue;

  CustomerAnalytics({
    required this.customerId,
    required this.customerName,
    this.mobileNumber = '',
    required this.orderCount,
    required this.totalSpent,
    required this.avgOrderValue,
    this.lastOrderDate,
    this.loyaltyTier = 'Bronze',
    this.lifetimeValue = 0,
  });

  factory CustomerAnalytics.fromJson(Map<String, dynamic> json) {
    return CustomerAnalytics(
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName'] ?? 'Guest',
      mobileNumber: json['mobileNumber'] ?? '',
      orderCount: _parseInt(json['orderCount']),
      totalSpent: _parseDouble(json['totalSpent']),
      avgOrderValue: _parseDouble(json['avgOrderValue']),
      lastOrderDate: json['lastOrderDate'] != null
          ? DateTime.tryParse(json['lastOrderDate'].toString())
          : null,
      loyaltyTier: _calculateLoyaltyTier(_parseDouble(json['totalSpent'])),
      lifetimeValue: _parseDouble(json['lifetimeValue'] ?? json['totalSpent']),
    );
  }

  static String _calculateLoyaltyTier(double totalSpent) {
    if (totalSpent >= 50000) return 'Platinum';
    if (totalSpent >= 25000) return 'Gold';
    if (totalSpent >= 10000) return 'Silver';
    return 'Bronze';
  }
}

// Store Type enum for categorization
enum StoreType {
  regular(1, 'Walk-in', 'Walk-in retail stores'),
  advanceBooking(2, 'Advance', 'Pre-order and advance booking customers'),
  centralizedKitchen(
    3,
    'Centralized Kitchen',
    'Central kitchen for bulk preparation',
  );

  final int code;
  final String displayName;
  final String description;

  const StoreType(this.code, this.displayName, this.description);

  static StoreType fromCode(int code) {
    switch (code) {
      case 2:
        return StoreType.advanceBooking;
      case 3:
        return StoreType.centralizedKitchen;
      default:
        return StoreType.regular;
    }
  }

  String get shortName {
    switch (this) {
      case StoreType.regular:
        return 'Walk-in';
      case StoreType.advanceBooking:
        return 'Advance';
      case StoreType.centralizedKitchen:
        return 'CK';
    }
  }
}

class StoreSales {
  final String storeId;
  final String storeName;
  final String city;
  final double totalSales;
  final int orderCount;
  final double avgOrderValue;
  final double targetAchievement;
  final StoreType storeType;
  final double salesContribution; // percentage of total sales

  StoreSales({
    required this.storeId,
    required this.storeName,
    this.city = '',
    required this.totalSales,
    required this.orderCount,
    required this.avgOrderValue,
    this.targetAchievement = 0,
    this.storeType = StoreType.regular,
    this.salesContribution = 0,
  });

  factory StoreSales.fromJson(Map<String, dynamic> json) {
    final storeTypeCode = _parseInt(json['storeType']);
    return StoreSales(
      storeId: json['storeId']?.toString() ?? '',
      storeName: json['storeName'] ?? 'Unknown Store',
      city: json['city'] ?? '',
      totalSales: _parseDouble(json['totalSales']),
      orderCount: _parseInt(json['orderCount']),
      avgOrderValue: _parseDouble(json['avgOrderValue']),
      targetAchievement: _parseDouble(json['targetAchievement']),
      storeType: StoreType.fromCode(storeTypeCode),
      salesContribution: _parseDouble(json['salesContribution']),
    );
  }
}

// Store Type Summary for drill-down
class StoreTypeSummary {
  final StoreType storeType;
  final double totalSales;
  final int orderCount;
  final int storeCount;
  final double avgOrderValue;
  final double salesPercentage;
  final List<StoreSales> stores;

  StoreTypeSummary({
    required this.storeType,
    required this.totalSales,
    required this.orderCount,
    required this.storeCount,
    required this.avgOrderValue,
    required this.salesPercentage,
    required this.stores,
  });
}

// Customer Type for Walk-in vs Regular
enum CustomerType {
  walkIn('Walk-in Customer'),
  regular('Regular Customer');

  final String displayName;
  const CustomerType(this.displayName);
}

class CustomerTypeSummary {
  final CustomerType customerType;
  final double totalSales;
  final int orderCount;
  final int customerCount;
  final double avgOrderValue;
  final double salesPercentage;

  CustomerTypeSummary({
    required this.customerType,
    required this.totalSales,
    required this.orderCount,
    required this.customerCount,
    required this.avgOrderValue,
    required this.salesPercentage,
  });
}

// Drill-down data container
class DrillDownData {
  final String title;
  final String subtitle;
  final List<DrillDownItem> items;
  final double totalValue;
  final String valueLabel;

  DrillDownData({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.totalValue,
    this.valueLabel = 'Sales',
  });
}

class DrillDownItem {
  final String id;
  final String name;
  final String? subtitle;
  final double value;
  final double percentage;
  final int count;
  final Map<String, dynamic>? metadata;

  DrillDownItem({
    required this.id,
    required this.name,
    this.subtitle,
    required this.value,
    required this.percentage,
    required this.count,
    this.metadata,
  });
}

class HourlySales {
  final int hour;
  final double sales;
  final int orders;

  HourlySales({required this.hour, required this.sales, required this.orders});

  factory HourlySales.fromJson(Map<String, dynamic> json) {
    return HourlySales(
      hour: _parseInt(json['hour']),
      sales: _parseDouble(json['sales']),
      orders: _parseInt(json['orders']),
    );
  }

  String get hourLabel {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }
}

// Prediction Models
class SalesPrediction {
  final DateTime predictedDate;
  final double predictedSales;
  final double confidenceLevel;
  final double lowerBound;
  final double upperBound;
  final String trend; // 'up', 'down', 'stable'

  SalesPrediction({
    required this.predictedDate,
    required this.predictedSales,
    required this.confidenceLevel,
    required this.lowerBound,
    required this.upperBound,
    required this.trend,
  });
}

class ProductPrediction {
  final String productId;
  final String productName;
  final double currentDemand;
  final double predictedDemand;
  final double demandGrowth;
  final String recommendation; // 'increase_stock', 'maintain', 'reduce_stock'
  final double confidenceScore;

  ProductPrediction({
    required this.productId,
    required this.productName,
    required this.currentDemand,
    required this.predictedDemand,
    required this.demandGrowth,
    required this.recommendation,
    required this.confidenceScore,
  });
}

class CustomerPrediction {
  final String customerId;
  final String customerName;
  final double churnProbability;
  final double nextPurchaseValue;
  final int daysTillNextPurchase;
  final String riskLevel; // 'low', 'medium', 'high'
  final List<String> recommendedActions;

  CustomerPrediction({
    required this.customerId,
    required this.customerName,
    required this.churnProbability,
    required this.nextPurchaseValue,
    required this.daysTillNextPurchase,
    required this.riskLevel,
    required this.recommendedActions,
  });
}

// Fill Rate Models
class FillRate {
  final String productId;
  final String productName;
  final int orderedQuantity;
  final int fulfilledQuantity;
  final double fillRatePercentage;
  final int stockouts;
  final String status; // 'healthy', 'warning', 'critical'

  FillRate({
    required this.productId,
    required this.productName,
    required this.orderedQuantity,
    required this.fulfilledQuantity,
    required this.fillRatePercentage,
    required this.stockouts,
    required this.status,
  });

  factory FillRate.calculate({
    required String productId,
    required String productName,
    required int orderedQuantity,
    required int fulfilledQuantity,
    required int stockouts,
  }) {
    double rate = orderedQuantity > 0
        ? (fulfilledQuantity / orderedQuantity) * 100
        : 100;

    String status;
    if (rate >= 95) {
      status = 'healthy';
    } else if (rate >= 80) {
      status = 'warning';
    } else {
      status = 'critical';
    }

    return FillRate(
      productId: productId,
      productName: productName,
      orderedQuantity: orderedQuantity,
      fulfilledQuantity: fulfilledQuantity,
      fillRatePercentage: rate,
      stockouts: stockouts,
      status: status,
    );
  }
}

class OverallFillRate {
  final double overallPercentage;
  final int totalOrdered;
  final int totalFulfilled;
  final int totalStockouts;
  final List<FillRate> productFillRates;
  final Map<String, double> categoryFillRates;

  OverallFillRate({
    required this.overallPercentage,
    required this.totalOrdered,
    required this.totalFulfilled,
    required this.totalStockouts,
    required this.productFillRates,
    required this.categoryFillRates,
  });
}

// Dashboard Filter
class DateRangeFilter {
  final DateTime startDate;
  final DateTime endDate;
  final String
  filterType; // 'today', 'yesterday', 'this_week', 'last_week', 'this_month', 'last_month', 'this_quarter', 'this_year', 'custom'

  DateRangeFilter({
    required this.startDate,
    required this.endDate,
    required this.filterType,
  });

  factory DateRangeFilter.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRangeFilter(startDate: start, endDate: end, filterType: 'today');
  }

  factory DateRangeFilter.yesterday() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final end = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      23,
      59,
      59,
    );
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'yesterday',
    );
  }

  factory DateRangeFilter.thisWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'this_week',
    );
  }

  factory DateRangeFilter.lastWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday + 6));
    final weekEnd = now.subtract(Duration(days: now.weekday));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'last_week',
    );
  }

  factory DateRangeFilter.thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'this_month',
    );
  }

  factory DateRangeFilter.lastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final start = lastMonth;
    final end = DateTime(now.year, now.month, 0, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'last_month',
    );
  }

  factory DateRangeFilter.thisQuarter() {
    final now = DateTime.now();
    final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final start = DateTime(now.year, quarterStartMonth, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'this_quarter',
    );
  }

  factory DateRangeFilter.thisYear() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'this_year',
    );
  }

  factory DateRangeFilter.last7Days() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'last_7_days',
    );
  }

  factory DateRangeFilter.last30Days() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'last_30_days',
    );
  }

  factory DateRangeFilter.last365Days() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 364));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      filterType: 'last_365_days',
    );
  }

  factory DateRangeFilter.allTime() {
    // Start from 2020 to cover all historical data
    final start = DateTime(2020, 1, 1);
    final end = DateTime.now();
    return DateRangeFilter(
      startDate: start,
      endDate: DateTime(end.year, end.month, end.day, 23, 59, 59),
      filterType: 'all_time',
    );
  }

  factory DateRangeFilter.custom(DateTime start, DateTime end) {
    return DateRangeFilter(
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day, 23, 59, 59),
      filterType: 'custom',
    );
  }

  String get formattedRange {
    return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int get daysDifference {
    return endDate.difference(startDate).inDays + 1;
  }
}

// Comprehensive Analytics Data
class AnalyticsDashboard {
  final SalesOverview salesOverview;
  final List<SalesTrend> salesTrend;
  final List<ProductSales> topProducts;
  final List<CategorySales> categorySales;
  final List<PaymentAnalytics> paymentAnalytics;
  final List<CustomerAnalytics> topCustomers;
  final List<StoreSales> storeSales;
  final List<HourlySales> hourlySales;
  final List<SalesPrediction> salesPredictions;
  final List<ProductPrediction> productPredictions;
  final OverallFillRate? fillRate;
  final DateRangeFilter dateFilter;

  AnalyticsDashboard({
    required this.salesOverview,
    required this.salesTrend,
    required this.topProducts,
    required this.categorySales,
    required this.paymentAnalytics,
    required this.topCustomers,
    required this.storeSales,
    required this.hourlySales,
    required this.salesPredictions,
    required this.productPredictions,
    this.fillRate,
    required this.dateFilter,
  });

  factory AnalyticsDashboard.empty() {
    return AnalyticsDashboard(
      salesOverview: SalesOverview.empty(),
      salesTrend: [],
      topProducts: [],
      categorySales: [],
      paymentAnalytics: [],
      topCustomers: [],
      storeSales: [],
      hourlySales: [],
      salesPredictions: [],
      productPredictions: [],
      dateFilter: DateRangeFilter.thisMonth(),
    );
  }
}
