// features/screen_time/models/app_info.dart
import 'package:flutter/material.dart';

class AppInfo {
  String id; // packageName
  String name; // displayName
  IconData icon; // 일단 기본아이콘 가져오기
  double currentUsage; // minute
  double emitRate; // g CO2/hour
  double limit; // limit g CO2/day)

  AppInfo(
    this.id,
    this.name,
    this.icon,
    this.currentUsage,
    this.emitRate,
    this.limit,
  );

  double get currentEmission => (currentUsage / 60) * emitRate;
  bool get isOverLimit => currentEmission > limit;
  double get usagePercentage => (currentEmission / limit).clamp(0.0, 1.0);

  AppInfo updateLimit(double newLimit) {
    return AppInfo(
      id,
      name,
      icon,
      currentUsage,
      emitRate,
      newLimit,
    );
  }

  AppInfo updateUsage(double newUsage) {
    return AppInfo(
      id,
      name,
      icon,
      newUsage,
      emitRate,
      limit,
    );
  }

  @override
  String toString() {
    return 'AppInfo(id: $id, name: $name, emission: ${currentEmission.toStringAsFixed(1)}g, limit: ${limit.toStringAsFixed(1)}g)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppInfo &&
        other.id == id &&
        other.currentUsage == currentUsage &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(id, currentUsage, limit);
}
