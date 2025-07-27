// features/screen_time/models/app_info.dart
import 'package:flutter/material.dart';

class AppInfo {
  String id; // 패키지명 (예: com.instagram.android)
  String name; // 표시명 (예: Instagram)
  IconData icon; // 기본 아이콘 사용
  double currentUsage; // 사용시간 (분)
  double emitRate; // 배출계수 (g CO2/hour)
  double limit; // 한계값 (g CO2/day)

  AppInfo(
    this.id,
    this.name,
    this.icon,
    this.currentUsage,
    this.emitRate,
    this.limit,
  );

  // 계산된 속성들 - 시간당 배출계수로 변경
  double get currentEmission => (currentUsage / 60) * emitRate; // 분을 시간으로 변환 후 계산
  bool get isOverLimit => currentEmission > limit;
  double get usagePercentage => (currentEmission / limit).clamp(0.0, 1.0);

  // 앱 한계값 업데이트
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

  // 사용량 업데이트
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