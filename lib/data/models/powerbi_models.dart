/// Models for PowerBI Admin Store Reports (TeapiocaFPDB)

// Helper functions
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

/// Store model for PowerBI reports
class PowerBIStore {
  final String storeId;
  final String storeName;
  final String? city;
  final String? state;
  final double totalSales;

  PowerBIStore({
    required this.storeId,
    required this.storeName,
    this.city,
    this.state,
    this.totalSales = 0.0,
  });

  factory PowerBIStore.fromJson(Map<String, dynamic> json) {
    return PowerBIStore(
      storeId: json['StoreID']?.toString() ?? json['storeId']?.toString() ?? '',
      storeName: json['StoreName']?.toString() ?? json['storeName']?.toString() ?? 'Unknown',
      city: json['City']?.toString() ?? json['city']?.toString(),
      state: json['State']?.toString() ?? json['state']?.toString(),
      totalSales: _parseDouble(json['TotalSales'] ?? json['totalSales']),
    );
  }
}

/// Category with subcategories/products for hierarchical display
class PowerBICategory {
  final String categoryId;
  final String categoryName;
  final List<PowerBICategoryItem> items;
  final Map<String, double> storeSales; // Store ID -> Sales Amount
  final double totalSales;
  bool isExpanded;

  PowerBICategory({
    required this.categoryId,
    required this.categoryName,
    required this.items,
    required this.storeSales,
    required this.totalSales,
    this.isExpanded = false,
  });

  factory PowerBICategory.fromJson(Map<String, dynamic> json, List<String> storeIds) {
    final items = <PowerBICategoryItem>[];
    if (json['items'] != null) {
      items.addAll(
        (json['items'] as List)
            .map((e) => PowerBICategoryItem.fromJson(e, storeIds))
            .toList(),
      );
    }

    final storeSales = <String, double>{};
    for (final storeId in storeIds) {
      storeSales[storeId] = _parseDouble(json[storeId] ?? json['store_$storeId']);
    }

    return PowerBICategory(
      categoryId: json['CategoryID']?.toString() ?? json['categoryId']?.toString() ?? '',
      categoryName: json['CategoryName']?.toString() ?? json['categoryName']?.toString() ?? 'Unknown',
      items: items,
      storeSales: storeSales,
      totalSales: _parseDouble(json['Total'] ?? json['total'] ?? json['TotalSales']),
    );
  }

  double getStoreTotal(String storeId) => storeSales[storeId] ?? 0.0;
}

/// Individual item (product or subcategory) under a category
class PowerBICategoryItem {
  final String itemId;
  final String itemName;
  final String type; // 'product', 'subcategory', etc.
  final Map<String, double> storeSales;
  final double totalSales;
  bool isExpanded;

  PowerBICategoryItem({
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.storeSales,
    required this.totalSales,
    this.isExpanded = false,
  });

  factory PowerBICategoryItem.fromJson(Map<String, dynamic> json, List<String> storeIds) {
    final storeSales = <String, double>{};
    for (final storeId in storeIds) {
      storeSales[storeId] = _parseDouble(json[storeId] ?? json['store_$storeId']);
    }

    return PowerBICategoryItem(
      itemId: json['ItemID']?.toString() ?? json['itemId']?.toString() ?? json['ProductID']?.toString() ?? '',
      itemName: json['ItemName']?.toString() ?? json['itemName']?.toString() ?? json['ProductName']?.toString() ?? 'Unknown',
      type: json['Type']?.toString() ?? json['type']?.toString() ?? 'product',
      storeSales: storeSales,
      totalSales: _parseDouble(json['Total'] ?? json['total'] ?? json['TotalSales']),
    );
  }

  double getStoreTotal(String storeId) => storeSales[storeId] ?? 0.0;
}

/// Summary data for PowerBI report
class PowerBISummary {
  final int storeCount;
  final int categoryCount;
  final double netSales;
  final DateTime startDate;
  final DateTime endDate;

  PowerBISummary({
    required this.storeCount,
    required this.categoryCount,
    required this.netSales,
    required this.startDate,
    required this.endDate,
  });

  factory PowerBISummary.fromJson(Map<String, dynamic> json) {
    return PowerBISummary(
      storeCount: _parseInt(json['storeCount'] ?? json['StoreCount']),
      categoryCount: _parseInt(json['categoryCount'] ?? json['CategoryCount']),
      netSales: _parseDouble(json['netSales'] ?? json['NetSales']),
      startDate: DateTime.parse(json['startDate'] ?? json['StartDate']),
      endDate: DateTime.parse(json['endDate'] ?? json['EndDate']),
    );
  }
}

/// Dynamic date range configuration like in the reference image
class DynamicDateRange {
  final String type; // 'last', 'this', 'custom'
  final int? value; // For 'last N months/days'
  final String? unit; // 'months', 'days', 'weeks'
  final DateTime? startDate; // For custom range
  final DateTime? endDate; // For custom range

  DynamicDateRange({
    required this.type,
    this.value,
    this.unit,
    this.startDate,
    this.endDate,
  });

  /// Create "Last N Months/Days" range
  factory DynamicDateRange.last(int value, String unit) {
    return DynamicDateRange(
      type: 'last',
      value: value,
      unit: unit,
    );
  }

  /// Create "This Month/Week/Year" range
  factory DynamicDateRange.current(String unit) {
    return DynamicDateRange(
      type: 'this',
      unit: unit,
    );
  }

  /// Create custom date range
  factory DynamicDateRange.custom(DateTime startDate, DateTime endDate) {
    return DynamicDateRange(
      type: 'custom',
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Calculate actual date range
  Map<String, DateTime> getDateRange() {
    final now = DateTime.now();
    
    if (type == 'custom' && startDate != null && endDate != null) {
      return {'start': startDate!, 'end': endDate!};
    }
    
    if (type == 'last' && value != null && unit != null) {
      DateTime start;
      switch (unit) {
        case 'months':
          start = DateTime(now.year, now.month - value!, now.day);
          break;
        case 'days':
          start = now.subtract(Duration(days: value!));
          break;
        case 'weeks':
          start = now.subtract(Duration(days: value! * 7));
          break;
        default:
          start = now.subtract(Duration(days: value!));
      }
      return {'start': start, 'end': now};
    }
    
    if (type == 'this') {
      switch (unit) {
        case 'month':
          return {
            'start': DateTime(now.year, now.month, 1),
            'end': now,
          };
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          return {
            'start': DateTime(weekStart.year, weekStart.month, weekStart.day),
            'end': now,
          };
        case 'year':
          return {
            'start': DateTime(now.year, 1, 1),
            'end': now,
          };
      }
    }
    
    return {'start': now, 'end': now};
  }

  String get displayText {
    if (type == 'last' && value != null && unit != null) {
      return 'Last $value ${unit![0].toUpperCase()}${unit!.substring(1)}';
    }
    if (type == 'this' && unit != null) {
      return 'This ${unit![0].toUpperCase()}${unit!.substring(1)}';
    }
    if (type == 'custom' && startDate != null && endDate != null) {
      return '${_formatDate(startDate!)} - ${_formatDate(endDate!)}';
    }
    return 'Select Date Range';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
