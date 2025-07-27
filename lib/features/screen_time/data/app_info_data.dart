// features/screen_time/data/app_info_data.dart
import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';
import '../models/app_info.dart';

class AppInfoData {
  static final Map<String, _AppMetadata> _appMetadata = {
    'com.instagram.android': _AppMetadata(
      packageName: 'com.instagram.android',
      displayName: 'Instagram',
      icon: Icons.camera_alt,
      emitRate: 150.0, // 시간당 150g CO2
      defaultLimit: 200.0, // 일일 한도 200g
    ),
    'com.google.android.youtube': _AppMetadata(
      packageName: 'com.google.android.youtube',
      displayName: 'YouTube',
      icon: Icons.play_circle_fill,
      emitRate: 150.0, // 시간당 150g CO2
      defaultLimit: 200.0, // 일일 한도 200g
    ),
    'com.zhiliaoapp.musically': _AppMetadata(
      packageName: 'com.zhiliaoapp.musically',
      displayName: 'TikTok',
      icon: Icons.music_note,
      emitRate: 150.0, // 시간당 150g CO2
      defaultLimit: 200.0, // 일일 한도 200g
    ),
  };

  // 실제 사용량 데이터로 AppInfo 생성 (실제 앱 아이콘 제거)
  static AppInfo createAppInfoFromUsage(String packageName, double usageMinutes) {
    final metadata = _appMetadata[packageName];
    
    // 메타데이터에서 정보 가져오기
    String displayName = metadata?.displayName ?? packageName;
    IconData icon = metadata?.icon ?? Icons.apps;
    double emitRate = metadata?.emitRate ?? 150.0;
    double defaultLimit = metadata?.defaultLimit ?? 200.0;

    return AppInfo(
      packageName,
      displayName,
      icon,
      usageMinutes,
      emitRate,
      defaultLimit,
    );
  }

  // 권한 확인
  static Future<bool> checkUsagePermission() async {
    return await UsageStats.checkUsagePermission() ?? false;
  }

  // 권한 요청
  static Future<void> requestUsagePermission() async {
    await UsageStats.grantUsagePermission();
  }

  // 실제 사용량 데이터 가져오기
  static Future<List<AppInfo>> getRealUsageData() async {
    try {
      // 권한 확인
      bool hasPermission = await checkUsagePermission();
      if (!hasPermission) {
        print('Usage permission not granted');
        return createSampleApps(); // 권한 없으면 샘플 데이터 반환
      }

      // 오늘 하루 사용량 가져오기
      DateTime endDate = DateTime.now();
      DateTime startDate = DateTime(endDate.year, endDate.month, endDate.day);
      
      List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startDate, endDate);
      
      // 관심 있는 앱들만 필터링
      List<AppInfo> appInfos = [];
      
      for (String packageName in _appMetadata.keys) {
        // 해당 패키지의 사용량 찾기
        UsageInfo? usageInfo;
        try {
          usageInfo = usageStats.firstWhere(
            (usage) => usage.packageName == packageName,
          );
        } catch (e) {
          // 해당 패키지를 찾지 못한 경우 null로 처리
          usageInfo = null;
        }
        
        // 사용 시간을 분 단위로 변환
        double usageMinutes = 0.0;
        if (usageInfo != null && usageInfo.totalTimeInForeground != null) {
          // totalTimeInForeground를 int로 캐스팅하여 계산
          int totalTime = usageInfo.totalTimeInForeground as int;
          usageMinutes = totalTime / (1000 * 60); // 밀리초를 분으로 변환
        }
        
        // 사용량이 있거나 등록된 앱인 경우 추가
        if (usageMinutes > 0 || _appMetadata.containsKey(packageName)) {
          AppInfo appInfo = createAppInfoFromUsage(packageName, usageMinutes);
          appInfos.add(appInfo);
        }
      }
      
      // 사용량 순으로 정렬
      appInfos.sort((a, b) => b.currentUsage.compareTo(a.currentUsage));
      
      return appInfos.isNotEmpty ? appInfos : createSampleApps();
      
    } catch (e) {
      print('Error getting usage data: $e');
      return createSampleApps(); // 에러 시 샘플 데이터 반환
    }
  }

  // 시간대별 사용량 가져오기
  static Future<List<double>> getHourlyUsageData() async {
    try {
      bool hasPermission = await checkUsagePermission();
      if (!hasPermission) {
        return [12.5, 8.3, 15.7, 22.1, 18.9, 9.2]; // 샘플 데이터
      }

      DateTime now = DateTime.now();
      List<double> hourlyEmissions = List.filled(6, 0.0); // 4시간씩 6구간
      
      // 오늘 하루를 4시간씩 나누어 사용량 계산
      for (int i = 0; i < 6; i++) {
        DateTime slotStart = DateTime(now.year, now.month, now.day, i * 4);
        DateTime slotEnd = slotStart.add(Duration(hours: 4));
        
        if (slotEnd.isAfter(now)) slotEnd = now;
        
        List<UsageInfo> slotUsage = await UsageStats.queryUsageStats(slotStart, slotEnd);
        
        double totalEmission = 0.0;
        for (UsageInfo usage in slotUsage) {
          if (_appMetadata.containsKey(usage.packageName)) {
            // totalTimeInForeground를 int로 캐스팅하여 계산
            if (usage.totalTimeInForeground != null) {
              int totalTime = usage.totalTimeInForeground as int;
              double hours = totalTime / (1000 * 60 * 60); // 밀리초를 시간으로 변환
              double emitRate = _appMetadata[usage.packageName]!.emitRate;
              totalEmission += hours * emitRate; // 시간당 배출량 계산
            }
          }
        }
        
        hourlyEmissions[i] = totalEmission;
      }
      
      return hourlyEmissions;
      
    } catch (e) {
      print('Error getting hourly usage data: $e');
      return [12.5, 8.3, 15.7, 22.1, 18.9, 9.2]; // 에러 시 샘플 데이터
    }
  }

  // 앱 ID로 AppInfo 생성 (레거시 호환용)
  static AppInfo createAppInfo(String appId, double currentUsage) {
    final metadata = _appMetadata[appId];
    if (metadata == null) {
      return AppInfo(
        appId,
        appId,
        Icons.apps,
        currentUsage,
        150.0,
        200.0,
      );
    }

    return AppInfo(
      metadata.packageName,
      metadata.displayName,
      metadata.icon,
      currentUsage,
      metadata.emitRate,
      metadata.defaultLimit,
    );
  }

  // 배출계수 가져오기
  static double getEmitRate(String packageName) {
    return _appMetadata[packageName]?.emitRate ?? 150.0;
  }

  // 기본 한계값 가져오기
  static double getDefaultLimit(String packageName) {
    return _appMetadata[packageName]?.defaultLimit ?? 200.0;
  }

  // 등록된 모든 앱 패키지명 목록
  static List<String> getAllPackageNames() {
    return _appMetadata.keys.toList();
  }

  // 등록된 앱인지 확인
  static bool isRegisteredApp(String packageName) {
    return _appMetadata.containsKey(packageName);
  }

  // 샘플 앱 데이터 생성 (권한 없을 때 사용)
  static List<AppInfo> createSampleApps() {
    return [
      AppInfo('com.instagram.android', 'Instagram', Icons.camera_alt, 42.3, 150.0, 200.0),
      AppInfo('com.google.android.youtube', 'YouTube', Icons.play_circle_fill, 75.3, 150.0, 200.0),
      AppInfo('com.zhiliaoapp.musically', 'TikTok', Icons.music_note, 31.2, 150.0, 200.0),
    ];
  }
}

// 앱 메타데이터 클래스 (내부용)
class _AppMetadata {
  final String packageName;
  final String displayName;
  final IconData icon;
  final double emitRate; // 시간당 배출계수 (g CO2/hour)
  final double defaultLimit; // 일일 한계값 (g CO2/day)

  const _AppMetadata({
    required this.packageName,
    required this.displayName,
    required this.icon,
    required this.emitRate,
    required this.defaultLimit,
  });
}