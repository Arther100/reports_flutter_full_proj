import 'package:json_annotation/json_annotation.dart';

part 'power_data_model.g.dart';

/// Power Data Model - Main data model for power operations
@JsonSerializable()
class PowerDataModel {
  final int id;
  final String stationName;
  final double powerGenerated;
  final double powerConsumed;
  final double voltage;
  final double current;
  final double frequency;
  final double powerFactor;
  final double efficiency;
  final DateTime timestamp;
  final String status;

  PowerDataModel({
    required this.id,
    required this.stationName,
    required this.powerGenerated,
    required this.powerConsumed,
    required this.voltage,
    required this.current,
    required this.frequency,
    required this.powerFactor,
    required this.efficiency,
    required this.timestamp,
    required this.status,
  });

  factory PowerDataModel.fromJson(Map<String, dynamic> json) =>
      _$PowerDataModelFromJson(json);

  Map<String, dynamic> toJson() => _$PowerDataModelToJson(this);

  /// Calculate net power
  double get netPower => powerGenerated - powerConsumed;

  /// Get status color indicator
  String get statusIndicator {
    if (netPower > 0) return 'surplus';
    if (netPower < 0) return 'deficit';
    return 'balanced';
  }
}

/// Power Statistics Model
@JsonSerializable()
class PowerStatistics {
  final double totalGenerated;
  final double totalConsumed;
  final double averageEfficiency;
  final double peakPower;
  final double minPower;
  final double averagePowerFactor;
  final int totalReadings;
  final DateTime lastUpdated;

  PowerStatistics({
    required this.totalGenerated,
    required this.totalConsumed,
    required this.averageEfficiency,
    required this.peakPower,
    required this.minPower,
    required this.averagePowerFactor,
    required this.totalReadings,
    required this.lastUpdated,
  });

  factory PowerStatistics.fromJson(Map<String, dynamic> json) =>
      _$PowerStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$PowerStatisticsToJson(this);

  double get netPower => totalGenerated - totalConsumed;
}

/// Chart Data Point Model
@JsonSerializable()
class ChartDataPoint {
  final DateTime timestamp;
  final double value;
  final String? label;
  final String? category;

  ChartDataPoint({
    required this.timestamp,
    required this.value,
    this.label,
    this.category,
  });

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) =>
      _$ChartDataPointFromJson(json);

  Map<String, dynamic> toJson() => _$ChartDataPointToJson(this);
}

/// Station Model
@JsonSerializable()
class StationModel {
  final int id;
  final String name;
  final String location;
  final double capacity;
  final String type;
  final bool isActive;
  final DateTime lastMaintenance;

  StationModel({
    required this.id,
    required this.name,
    required this.location,
    required this.capacity,
    required this.type,
    required this.isActive,
    required this.lastMaintenance,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) =>
      _$StationModelFromJson(json);

  Map<String, dynamic> toJson() => _$StationModelToJson(this);
}
