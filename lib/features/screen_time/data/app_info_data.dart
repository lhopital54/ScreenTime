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
      emitRate: 150.0,
      defaultLimit: 200.0,
    ),
    'com.google.android.youtube': _AppMetadata(
      packageName: 'com.google.android.youtube',
      displayName: 'YouTube',
      icon: Icons.play_circle_fill,
      emitRate: 150.0,
      defaultLimit: 200.0,
    ),
    'com.zhiliaoapp.musically': _AppMetadata(
      packageName: 'com.zhiliaoapp.musically',
      displayName: 'TikTok',
      icon: Icons.music_note,
      emitRate: 150.0,
      defaultLimit: 200.0,
    ),
  };

  // AppInfo generation
  static AppInfo createAppInfoFromUsage(String packageName, double usageMinutes) {
    final metadata = _appMetadata[packageName];
    
    // getting info from metadata
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

  // check and request permission(for usage_stats)
  static Future<bool> checkUsagePermission() async {
    return await UsageStats.checkUsagePermission() ?? false;
  }

  static Future<void> requestUsagePermission() async {
    await UsageStats.grantUsagePermission();
  }

  // getting real data
  static Future<List<AppInfo>> getRealUsageData() async {
    try {
      bool hasPermission = await checkUsagePermission();
      if (!hasPermission) {
        print('Usage permission not granted');
        return createSampleApps(); // return sample data if no permission
      }

      DateTime endDate = DateTime.now();
      DateTime startDate = DateTime(endDate.year, endDate.month, endDate.day);
      
      List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startDate, endDate);
      
      List<AppInfo> appInfos = [];
      
      for (String packageName in _appMetadata.keys) {
        UsageInfo? usageInfo;
        try {
          usageInfo = usageStats.firstWhere(
            (usage) => usage.packageName == packageName,
          );
        } catch (e) {
          usageInfo = null;
        }
        
        double usageMinutes = 0.0;
        if (usageInfo != null && usageInfo.totalTimeInForeground != null) {
          int totalTime = usageInfo.totalTimeInForeground as int;
          usageMinutes = totalTime / (1000 * 60); // ms to min
        }
        
        // add automatically
        if (usageMinutes > 0 || _appMetadata.containsKey(packageName)) {
          AppInfo appInfo = createAppInfoFromUsage(packageName, usageMinutes);
          appInfos.add(appInfo);
        }
      }
      
      // sort
      appInfos.sort((a, b) => b.currentUsage.compareTo(a.currentUsage));
      
      return appInfos.isNotEmpty ? appInfos : createSampleApps();
      
    } catch (e) {
      print('Error getting usage data: $e');
      return createSampleApps(); // return sample data if error
    }
  }

  static Future<List<double>> getHourlyUsageData() async {
    try {
      bool hasPermission = await checkUsagePermission();
      if (!hasPermission) {
        return [12.5, 8.3, 15.7, 22.1, 18.9, 9.2]; // return sample data if no permission
      }

      DateTime now = DateTime.now();
      List<double> hourlyEmissions = List.filled(6, 0.0); // 6 intervals
      
      // 오늘 하루를 4시간씩 나누어 사용량 계산
      for (int i = 0; i < 6; i++) {
        DateTime slotStart = DateTime(now.year, now.month, now.day, i * 4);
        DateTime slotEnd = slotStart.add(Duration(hours: 4));
        
        if (slotEnd.isAfter(now)) slotEnd = now;
        
        List<UsageInfo> slotUsage = await UsageStats.queryUsageStats(slotStart, slotEnd);
        
        double totalEmission = 0.0;
        for (UsageInfo usage in slotUsage) {
          if (_appMetadata.containsKey(usage.packageName)) {
            if (usage.totalTimeInForeground != null) {
              int totalTime = usage.totalTimeInForeground as int;
              double hours = totalTime / (1000 * 60 * 60); // ms to hr
              double emitRate = _appMetadata[usage.packageName]!.emitRate;
              totalEmission += hours * emitRate;
            }
          }
        }
        
        hourlyEmissions[i] = totalEmission;
      }
      
      return hourlyEmissions;
      
    } catch (e) {
      print('Error getting hourly usage data: $e');
      return [12.5, 8.3, 15.7, 22.1, 18.9, 9.2]; // return sample data if error
    }
  }

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

  static double getEmitRate(String packageName) {
    return _appMetadata[packageName]?.emitRate ?? 150.0;
  }

  static double getDefaultLimit(String packageName) {
    return _appMetadata[packageName]?.defaultLimit ?? 200.0;
  }

  static List<String> getAllPackageNames() {
    return _appMetadata.keys.toList();
  }

  static bool isRegisteredApp(String packageName) {
    return _appMetadata.containsKey(packageName);
  }

  static List<AppInfo> createSampleApps() {
    return [
      AppInfo('com.instagram.android', 'Instagram', Icons.camera_alt, 42.3, 150.0, 200.0),
      AppInfo('com.google.android.youtube', 'YouTube', Icons.play_circle_fill, 75.3, 150.0, 200.0),
      AppInfo('com.zhiliaoapp.musically', 'TikTok', Icons.music_note, 31.2, 150.0, 200.0),
    ];
  }
}

// for internal use
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