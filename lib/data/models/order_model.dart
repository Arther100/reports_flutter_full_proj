/// Order Model - Data model for Orders from MS SQL
class OrderModel {
  final String orderId;
  final String orderNumber;
  final DateTime transDate;
  final double transAmount;
  final double netAmount;
  final double taxAmount;
  final double discountAmount;
  final int orderStatus;
  final int paymentMode;
  final bool isPOS;
  final String storeId;
  final String customerId;
  final String soldBy;
  final bool isDeleted;
  final DateTime createdDate;

  OrderModel({
    required this.orderId,
    required this.orderNumber,
    required this.transDate,
    required this.transAmount,
    required this.netAmount,
    required this.taxAmount,
    required this.discountAmount,
    required this.orderStatus,
    required this.paymentMode,
    required this.isPOS,
    required this.storeId,
    required this.customerId,
    required this.soldBy,
    required this.isDeleted,
    required this.createdDate,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: json['OrderID']?.toString() ?? '',
      orderNumber: json['OrderNumber']?.toString() ?? '',
      transDate:
          DateTime.tryParse(json['TransDate']?.toString() ?? '') ??
          DateTime.now(),
      transAmount: (json['TransAmount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['NetAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['TaxAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['DiscountAmount'] as num?)?.toDouble() ?? 0.0,
      orderStatus: json['OrderStatus'] as int? ?? 0,
      paymentMode: json['PaymentMode'] as int? ?? 0,
      isPOS: json['IsPOS'] as bool? ?? false,
      storeId: json['StoreID']?.toString() ?? '',
      customerId: json['CustomerID']?.toString() ?? '',
      soldBy: json['SoldBy']?.toString() ?? '',
      isDeleted: json['IsDeleted'] as bool? ?? false,
      createdDate:
          DateTime.tryParse(json['CreatedDate']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'OrderID': orderId,
      'OrderNumber': orderNumber,
      'TransDate': transDate.toIso8601String(),
      'TransAmount': transAmount,
      'NetAmount': netAmount,
      'TaxAmount': taxAmount,
      'DiscountAmount': discountAmount,
      'OrderStatus': orderStatus,
      'PaymentMode': paymentMode,
      'IsPOS': isPOS,
      'StoreID': storeId,
      'CustomerID': customerId,
      'SoldBy': soldBy,
      'IsDeleted': isDeleted,
      'CreatedDate': createdDate.toIso8601String(),
    };
  }

  /// Get status text
  String get statusText {
    switch (orderStatus) {
      case 0:
        return 'Pending';
      case 1:
        return 'Confirmed';
      case 2:
        return 'Processing';
      case 3:
        return 'Shipped';
      case 4:
        return 'Delivered';
      case 5:
        return 'Cancelled';
      case 6:
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  /// Get payment mode text
  String get paymentModeText {
    switch (paymentMode) {
      case 0:
        return 'Cash';
      case 1:
        return 'Card';
      case 2:
        return 'Online';
      case 3:
        return 'Wallet';
      default:
        return 'Other';
    }
  }

  /// Get total amount (including tax)
  double get totalAmount => netAmount + taxAmount;
}

/// Order Statistics Model
class OrderStatistics {
  final int totalOrders;
  final double totalRevenue;
  final double totalTax;
  final double averageOrderValue;
  final int completedOrders;
  final int pendingOrders;

  OrderStatistics({
    required this.totalOrders,
    required this.totalRevenue,
    required this.totalTax,
    required this.averageOrderValue,
    required this.completedOrders,
    required this.pendingOrders,
  });

  factory OrderStatistics.fromJson(Map<String, dynamic> json) {
    return OrderStatistics(
      totalOrders: json['totalOrders'] as int? ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0.0,
      completedOrders: json['completedOrders'] as int? ?? 0,
      pendingOrders: json['pendingOrders'] as int? ?? 0,
    );
  }
}
