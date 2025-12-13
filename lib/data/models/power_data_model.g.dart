// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'power_data_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PowerDataModel _$PowerDataModelFromJson(Map<String, dynamic> json) =>
    PowerDataModel(
      id: (json['id'] as num).toInt(),
      stationName:
          json['stationName'] as String? ??
          json['station_name'] as String? ??
          '',
      powerGenerated:
          (json['powerGenerated'] as num?)?.toDouble() ??
          (json['power_generated'] as num?)?.toDouble() ??
          0.0,
      powerConsumed:
          (json['powerConsumed'] as num?)?.toDouble() ??
          (json['power_consumed'] as num?)?.toDouble() ??
          0.0,
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      frequency: (json['frequency'] as num?)?.toDouble() ?? 50.0,
      powerFactor:
          (json['powerFactor'] as num?)?.toDouble() ??
          (json['power_factor'] as num?)?.toDouble() ??
          0.0,
      efficiency: (json['efficiency'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'unknown',
    );

Map<String, dynamic> _$PowerDataModelToJson(PowerDataModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'stationName': instance.stationName,
      'powerGenerated': instance.powerGenerated,
      'powerConsumed': instance.powerConsumed,
      'voltage': instance.voltage,
      'current': instance.current,
      'frequency': instance.frequency,
      'powerFactor': instance.powerFactor,
      'efficiency': instance.efficiency,
      'timestamp': instance.timestamp.toIso8601String(),
      'status': instance.status,
    };

PowerStatistics _$PowerStatisticsFromJson(Map<String, dynamic> json) =>
    PowerStatistics(
      totalGenerated:
          (json['totalGenerated'] as num?)?.toDouble() ??
          (json['total_generated'] as num?)?.toDouble() ??
          0.0,
      totalConsumed:
          (json['totalConsumed'] as num?)?.toDouble() ??
          (json['total_consumed'] as num?)?.toDouble() ??
          0.0,
      averageEfficiency:
          (json['averageEfficiency'] as num?)?.toDouble() ??
          (json['average_efficiency'] as num?)?.toDouble() ??
          0.0,
      peakPower:
          (json['peakPower'] as num?)?.toDouble() ??
          (json['peak_power'] as num?)?.toDouble() ??
          0.0,
      minPower:
          (json['minPower'] as num?)?.toDouble() ??
          (json['min_power'] as num?)?.toDouble() ??
          0.0,
      averagePowerFactor:
          (json['averagePowerFactor'] as num?)?.toDouble() ??
          (json['average_power_factor'] as num?)?.toDouble() ??
          0.0,
      totalReadings:
          (json['totalReadings'] as num?)?.toInt() ??
          (json['total_readings'] as num?)?.toInt() ??
          0,
      lastUpdated: json['lastUpdated'] != null || json['last_updated'] != null
          ? DateTime.parse(
              (json['lastUpdated'] ?? json['last_updated']) as String,
            )
          : DateTime.now(),
    );

Map<String, dynamic> _$PowerStatisticsToJson(PowerStatistics instance) =>
    <String, dynamic>{
      'totalGenerated': instance.totalGenerated,
      'totalConsumed': instance.totalConsumed,
      'averageEfficiency': instance.averageEfficiency,
      'peakPower': instance.peakPower,
      'minPower': instance.minPower,
      'averagePowerFactor': instance.averagePowerFactor,
      'totalReadings': instance.totalReadings,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
    };

ChartDataPoint _$ChartDataPointFromJson(Map<String, dynamic> json) =>
    ChartDataPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      value: (json['value'] as num).toDouble(),
      label: json['label'] as String?,
      category: json['category'] as String?,
    );

Map<String, dynamic> _$ChartDataPointToJson(ChartDataPoint instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp.toIso8601String(),
      'value': instance.value,
      'label': instance.label,
      'category': instance.category,
    };

StationModel _$StationModelFromJson(Map<String, dynamic> json) => StationModel(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String? ?? '',
  location: json['location'] as String? ?? '',
  capacity: (json['capacity'] as num?)?.toDouble() ?? 0.0,
  type: json['type'] as String? ?? 'unknown',
  isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
  lastMaintenance:
      json['lastMaintenance'] != null || json['last_maintenance'] != null
      ? DateTime.parse(
          (json['lastMaintenance'] ?? json['last_maintenance']) as String,
        )
      : DateTime.now(),
);

Map<String, dynamic> _$StationModelToJson(StationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'location': instance.location,
      'capacity': instance.capacity,
      'type': instance.type,
      'isActive': instance.isActive,
      'lastMaintenance': instance.lastMaintenance.toIso8601String(),
    };
