// features/screen_time/data/app_info_data.dart
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usage_stats/usage_stats.dart';
// import 'package:device_apps/device_apps.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/app_info.dart';

class AppInfoData {
  static Map<String, AppMetadata> appMetadata = {};
  static Map<String, Uint8List?> appIcons = {}; // 실제 앱 아이콘 캐시

  static Future<void> loadAppList() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    File file = File('${appDocDir.path}/app_list.json');

    String jsonString = await file.readAsString();
    Map<String, dynamic> jsonData = json.decode(jsonString);
    
    appMetadata.clear();
    List<dynamic> apps = jsonData['apps'];
    
    for (var app in apps) {
      String packageName = app['packageName'];
      appMetadata[packageName] = AppMetadata(
        packageName: packageName,
        displayName: app['displayName'],
        emitRate: app['emitRate'].toDouble(),
        defaultLimit: app['defaultLimit'].toDouble(),
      );
    }
    
    print('Loaded ${appMetadata.length} apps from JSON');
    
    await _loadAppIcons();
  }
  
  static Future<void> _loadAppIcons() async {
    for (String packageName in appMetadata.keys) {
      // try {
      //   Application? app = await DeviceApps.getApp(packageName, true);
      //   if (app != null && app is ApplicationWithIcon) {
      //     appIcons[packageName] = app.icon;
      //     print('Loaded icon for $packageName');
      //   } else {
      //     appIcons[packageName] = null;
      //     print('No icon found for $packageName');
      //   }
      // } catch (e) {
      //   print('Error loading icon for $packageName: $e');
        appIcons[packageName] = null;
      // }
    }
  }

    static Widget getAppIcon(String packageName, {double size = 40}) {
    Uint8List? iconData = appIcons[packageName];
    
    if (iconData != null) {
      return Image.memory(
        iconData,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else {
      IconData defaultIcon;
      defaultIcon = Icons.apps;
      
      return Icon(
        defaultIcon,
        size: size,
        color: Colors.grey[600],
      );
    }
  }

  static AppInfo createAppInfoFromUsage(String packageName, double usageMinutes) {
    final metadata = appMetadata[packageName];
    
    String displayName = metadata?.displayName ?? packageName;
    double emitRate = metadata?.emitRate ?? 150.0;
    double defaultLimit = metadata?.defaultLimit ?? 200.0;

    return AppInfo(
      packageName,
      displayName,
      Icons.apps, // dummy icon
      usageMinutes,
      emitRate,
      defaultLimit,
    );
  }

    static Future<void> addApp({
    required String packageName,
    required String displayName,
    required double emitRate,
    required double defaultLimit,
  }) async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File file = File('${appDocDir.path}/app_list.json');
    
      String jsonString = await file.readAsString();
      Map<String, dynamic> jsonData = json.decode(jsonString);
      
      List<dynamic> apps = jsonData['apps'];
      apps.add({
        'packageName': packageName,
        'displayName': displayName,
        'emitRate': emitRate,
        'defaultLimit': defaultLimit,
      });
      
      appMetadata[packageName] = AppMetadata(
        packageName: packageName,
        displayName: displayName,
        emitRate: emitRate,
        defaultLimit: defaultLimit,
      );
      
      // try {
      //   Application? app = await DeviceApps.getApp(packageName, true);
      //   if (app != null && app is ApplicationWithIcon) {
      //     appIcons[packageName] = app.icon;
      //   }
      // } catch (e) {
        appIcons[packageName] = null;
      // }
      
      print('Added app: $displayName ($packageName)');
      
    } catch (e) {
      print('Error adding app: $e');
    }
  }
  
  // remove app from json
  static void removeApp(String packageName) {
    appMetadata.remove(packageName);
    appIcons.remove(packageName);
    print('Removed app: $packageName');
  }

  // check and request permission(for usage_stats)
  static Future<bool> checkUsagePermission() async {
    return await UsageStats.checkUsagePermission() ?? false;
  }

  static Future<void> requestUsagePermission() async {
    await UsageStats.grantUsagePermission();
  }

  // ------------------------------
  // usage tracking with event and saving to json
  // ------------------------------

  // eventType constants from UsageStats.queryEvents()
  static const int _EVENT_RESUMED = 1;
  static const int _EVENT_PAUSED  = 2;
  static const int _EVENT_STOPPED = 23;

  static const List<String> timeSlotsLabels = [
    '00-04', '04-08', '08-12', '12-16', '16-20', '20-24'
  ];

  static Future<List<String>> loadAppIds() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    File file = File('${appDocDir.path}/daily_usage.json');
    
    String jsonString = await file.readAsString();
    Map<String, dynamic> jsonData = json.decode(jsonString);
    
    List<dynamic> apps = jsonData['apps'] ?? [];

    return apps.map((app) => app['id'].toString()).toList();
  }

  static Future<String> getDailyUsageJson() async {
    final date     = DateTime.now();
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0);
    final dayEnd   = dayStart.add(const Duration(days: 1));
    final appIds   = await loadAppIds();

    Map<String, dynamic> dailyData = await loadDailyUsageData();
    double dailyCarbonLimit = dailyData['dailyCarbonLimit']?.toDouble() ?? 100.0;

    print('📊 Collecting usage events from $dayStart to $dayEnd');

    // queryEvents가 null을 반환할 수 있어, 빈 리스트로 전환
    final allEvents = await UsageStats.queryEvents(dayStart, dayEnd);
    print('📱 Found ${allEvents.length} total events');

    // initialize
    final eventsByApp = <String, List<dynamic>>{
      for (var id in appIds) id: <dynamic>[],
    };
    for (var e in allEvents) {
      if (eventsByApp.containsKey(e.packageName)) {
        eventsByApp[e.packageName]!.add(e);
      }
    }

    final appsResult = <Map<String, dynamic>>[];
    final totalUsageBySlot = List<double>.filled(timeSlotsLabels.length, 0.0);

    for (var appId in appIds) {
      final events = eventsByApp[appId]!;
      print('🔍 Processing ${events.length} events for $appId');
      
      // 시간순 정렬
      events.sort((a, b) {
        int aTime = int.tryParse(a.timeStamp?.toString() ?? '0') ?? 0;
        int bTime = int.tryParse(b.timeStamp?.toString() ?? '0') ?? 0;
        return aTime.compareTo(bTime);
      });

      final usageBySlot = List<double>.filled(timeSlotsLabels.length, 0.0);
      double totalUsage = 0.0;
      DateTime? sessionStart;

      for (var event in events) {
        final ts = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(event.timeStamp?.toString() ?? '0') ?? 0
        );
        final type = int.tryParse(event.eventType?.toString() ?? '0') ?? 0;

        if (type == _EVENT_RESUMED) {
          sessionStart = ts;
          print('▶️ $appId started at $ts');
        } else if ((type == _EVENT_PAUSED || type == _EVENT_STOPPED) && sessionStart != null) {
          final sessionEnd = ts;
          print('⏸️ $appId stopped at $ts');

          final start = sessionStart.isBefore(dayStart) ? dayStart : sessionStart;
          final end = sessionEnd.isAfter(dayEnd) ? dayEnd : sessionEnd;

          if (end.isAfter(start)) {
            final sessionMinutes = end.difference(start).inSeconds / 60.0;
            print('⏱️ Session duration: ${sessionMinutes.toStringAsFixed(2)} minutes');
            
            for (var i = 0; i < timeSlotsLabels.length; i++) {
              final slotStart = dayStart.add(Duration(hours: 4 * i));
              final slotEnd   = slotStart.add(const Duration(hours: 4));
              if (end.isBefore(slotStart) || start.isAfter(slotEnd)) continue;

              final overlapStart = start.isAfter(slotStart) ? start : slotStart;
              final overlapEnd   = end.isBefore(slotEnd)    ? end   : slotEnd;
              final minutes = overlapEnd.difference(overlapStart).inSeconds / 60.0;
              if (minutes > 0) {
                usageBySlot[i] += minutes;
                totalUsageBySlot[i] += minutes;
                print('  📊 Slot ${timeSlotsLabels[i]}: +${minutes.toStringAsFixed(2)} min');
              }
            }
            totalUsage += sessionMinutes;
          }
          sessionStart = null;
        }
      }

      // 진행 중인 세션 처리 (아직 종료되지 않은 앱)
      if (sessionStart != null) {
        final now = DateTime.now();
        final sessionEnd = now.isBefore(dayEnd) ? now : dayEnd;
        
        if (sessionEnd.isAfter(sessionStart)) {
          final sessionMinutes = sessionEnd.difference(sessionStart).inSeconds / 60.0;
          totalUsage += sessionMinutes;
          print('🔄 $appId still running: +${sessionMinutes.toStringAsFixed(2)} min');
        }
      }

      // 소수점 둘째 자리 반올림
      for (var i = 0; i < usageBySlot.length; i++) {
        usageBySlot[i] = double.parse(usageBySlot[i].toStringAsFixed(2));
      }
      totalUsage = double.parse(totalUsage.toStringAsFixed(2));

      appsResult.add({
        'id': appId,
        'usageBySlot': usageBySlot,
        'totalUsage': totalUsage,
      });

      if (totalUsage > 0) {
        print('✅ $appId total usage: ${totalUsage.toStringAsFixed(2)} minutes');
      }
    }

    final result = {
      'date': '${date.year.toString().padLeft(4,'0')}-'
              '${date.month.toString().padLeft(2,'0')}-'
              '${date.day.toString().padLeft(2,'0')}',
      'dailyCarbonLimit': dailyCarbonLimit,
      'timeSlots': timeSlotsLabels,
      'apps': appsResult,
    };

    print('📈 Final result: ${result}');

    // JSON 문자열 생성
    String jsonString = const JsonEncoder.withIndent('  ').convert(result);
    
    // ✅ 로컬 저장소에 저장 (새로 추가된 기능)
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File file = File('${appDocDir.path}/daily_usage.json');
      
      await file.writeAsString(jsonString);
      print('💾 Daily usage data saved to: ${file.path}');
      
      // 저장된 데이터 확인용 로그
      int appsWithUsage = appsResult.where((app) => app['totalUsage'] > 0).length;
      print('📊 Summary: ${appsWithUsage}/${appsResult.length} apps have usage data');
      
    } catch (e) {
      print('❌ Error saving daily usage JSON: $e');
    }

    return jsonString;
  }
  // ------------------------------
  // loading data from json
  // ------------------------------
  static Future<Map<String, dynamic>> loadDailyUsageData() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File file = File('${appDocDir.path}/daily_usage.json');
    
      String jsonString = await file.readAsString();
      Map<String, dynamic> jsonData = json.decode(jsonString);
      return jsonData;
    } catch (e) {
      print('Error loading daily usage data: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> loadWeeklyUsageData() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File file = File('${appDocDir.path}/weekly_usage.json');

      String jsonString = await file.readAsString();
      Map<String, dynamic> jsonData = json.decode(jsonString);
      return jsonData;
    } catch (e) {
      print('Error loading daily usage data: $e');
      return {};
    }
  }

  // AppInfo 리스트 생성 (기존 AppInfoData 함수 활용)
  static Future<List<AppInfo>> createAppInfosFromJson() async {
    // AppInfoData의 앱 메타데이터 로드
    await AppInfoData.loadAppList();
    
    // daily_usage.json 로드
    Map<String, dynamic> dailyData = await loadDailyUsageData();

    print(dailyData);
    
    if (dailyData.isEmpty) {
      // JSON 로드 실패 시 샘플 데이터
      return [
        AppInfoData.createAppInfoFromUsage('com.google.android.youtube', 0.0),
      ];
    }
    
    List<AppInfo> appInfos = [];
    List<dynamic> apps = dailyData['apps'] ?? [];
    
    for (var appData in apps) {
      String packageName = appData['id'];
      double totalUsage = appData['totalUsage']?.toDouble() ?? 0.0;
      
      // AppInfoData의 기존 함수 사용
      AppInfo appInfo = AppInfoData.createAppInfoFromUsage(packageName, totalUsage);
      appInfos.add(appInfo);
    }
    
    print('Created ${appInfos.length} AppInfos from JSON');
    return appInfos;
  }

  // 시간대별 배출량 데이터 생성
  static Future<List<double>> createDailyEmissionsFromJson() async {
    Map<String, dynamic> dailyData = await loadDailyUsageData();
    
    if (dailyData.isEmpty) {
      print("Failed at loading daily data");
      // JSON 로드 실패 시 샘플 데이터
      return [12.5, 8.3, 15.7, 22.1, 18.9, 9.2];
    }
    
    List<String> timeSlots = List<String>.from(dailyData['timeSlots'] ?? []);
    List<double> dailyEmissions = List.filled(timeSlots.length, 0.0);
    
    // 각 앱의 시간대별 사용량을 배출량으로 변환
    List<dynamic> apps = dailyData['apps'] ?? [];
    
    for (var appData in apps) {
      String packageName = appData['id'];
      List<dynamic> usageBySlot = appData['usageBySlot'] ?? [];
      
      // AppInfoData에서 배출계수 가져오기
      double emitRate = AppInfoData.getEmitRate(packageName);
      
      // 각 시간대별로 배출량 계산
      for (int i = 0; i < 6; i++) {
        double usageMinutes = usageBySlot[i]?.toDouble() ?? 0.0;
        double hours = usageMinutes / 60; // 분을 시간으로 변환
        double emission = hours * emitRate; // 시간당 배출계수 적용
        dailyEmissions[i] = emission;
      }
    }
    
    print('Created daily emissions: $dailyEmissions');
    return dailyEmissions;
  }

  static Future<List<double>> createWeeklyEmissionsFromJson() async {
    Map<String, dynamic> weeklyData = await loadWeeklyUsageData();

    if (weeklyData.isEmpty) {
      print("Failed at loading Weekly data");
      // JSON 로드 실패 시 샘플 데이터
      return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    }
    
    List<double> weeklyEmissions = weeklyData['weeklyEmissions'].cast<double>();
    
    print('Created weekly emissions: $weeklyEmissions');
    return weeklyEmissions;
  }

  static double getEmitRate(String packageName) {
    return appMetadata[packageName]?.emitRate ?? 170.0;
  }

  static double getDefaultLimit(String packageName) {
    return appMetadata[packageName]?.defaultLimit ?? 200.0;
  }

  static List<String> getAllPackageNames() {
    return appMetadata.keys.toList();
  }

  static bool isRegisteredApp(String packageName) {
    return appMetadata.containsKey(packageName);
  }

  static List<AppInfo> createSampleApps() {
    return [
      AppInfo('com.google.android.youtube', 'YouTube', Icons.play_circle_fill, 75.3, 170.0, 200.0),
    ];
  }
}

class AppMetadata {
  final String packageName;
  final String displayName;
  final double emitRate; // emit g CO2/hour
  final double defaultLimit; // limit g CO2/day

  const AppMetadata({
    required this.packageName,
    required this.displayName,
    required this.emitRate,
    required this.defaultLimit,
  });
}
