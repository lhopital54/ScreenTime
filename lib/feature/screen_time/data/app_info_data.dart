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
  
  static Future<void> _loadAppIcons() async {  // not working...............
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

    print('Collecting usage events from $dayStart to $dayEnd');

    final allEvents = await UsageStats.queryEvents(dayStart, dayEnd);
    print('Found ${allEvents.length} total events');

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
      print('Processing ${events.length} events for $appId');
      
      // sorting(key = time)
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
          print('$appId started at $ts');
        } else if ((type == _EVENT_PAUSED || type == _EVENT_STOPPED) && sessionStart != null) {
          final sessionEnd = ts;
          print('$appId stopped at $ts');

          final start = sessionStart.isBefore(dayStart) ? dayStart : sessionStart;
          final end = sessionEnd.isAfter(dayEnd) ? dayEnd : sessionEnd;

          if (end.isAfter(start)) {
            final sessionMinutes = end.difference(start).inSeconds / 60.0;
            print('Session duration: ${sessionMinutes.toStringAsFixed(2)} minutes');
            
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
                print('  Slot ${timeSlotsLabels[i]}: +${minutes.toStringAsFixed(2)} min');
              }
            }
            totalUsage += sessionMinutes;
          }
          sessionStart = null;
        }
      }

      // handling session not finished
      if (sessionStart != null) {
        final now = DateTime.now();
        final sessionEnd = now.isBefore(dayEnd) ? now : dayEnd;
        
        if (sessionEnd.isAfter(sessionStart)) {
          final sessionMinutes = sessionEnd.difference(sessionStart).inSeconds / 60.0;
          totalUsage += sessionMinutes;
          print('$appId still running: +${sessionMinutes.toStringAsFixed(2)} min');
        }
      }

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
        print('$appId total usage: ${totalUsage.toStringAsFixed(2)} minutes');
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

    print('Final result: ${result}');

    // generating JSON string
    String jsonString = const JsonEncoder.withIndent('  ').convert(result);
    
    // saving file
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File file = File('${appDocDir.path}/daily_usage.json');
      
      await file.writeAsString(jsonString);
      print('Daily usage data saved to: ${file.path}');
      
      // debug
      int appsWithUsage = appsResult.where((app) => app['totalUsage'] > 0).length;
      print('${appsWithUsage}/${appsResult.length} apps have usage data');
      
    } catch (e) {
      print('Error saving daily usage JSON: $e');
    }

    await updateWeeklyUsageData();

    return jsonString;
  }

    static Future<String> getWeeklyUsageJson() async {
    try {
      print('Generating weekly usage data...');
      
      final now = DateTime.now();
      final startOfWeek = _getStartOfWeek(now);
      
      List<String> appIds = await loadAppIds();
      
      List<double> weeklyEmissions = await _calculateWeeklyEmissions(startOfWeek, appIds);
      
      List<Map<String, dynamic>> appsWeeklyData = await _calculateAppsWeeklyUsage(startOfWeek, appIds);
      
      final result = {
        'week': _getWeekString(startOfWeek),
        'weekDays': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        'weeklyEmissions': weeklyEmissions,
        'apps': appsWeeklyData,
      };
      
      print('Weekly result: $result');
      
      // generating JSON string
      String jsonString = const JsonEncoder.withIndent('  ').convert(result);
      
      // saving file
      try {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        File file = File('${appDocDir.path}/weekly_usage.json');
        
        await file.writeAsString(jsonString);
        print('Weekly usage data saved to: ${file.path}');
        
      } catch (e) {
        print('Error saving weekly usage JSON: $e');
      }
      
      return jsonString;
      
    } catch (e) {
      print('Error generating weekly usage JSON: $e');
      return '{}';
    }
  }

  static Future<List<double>> _calculateWeeklyEmissions(DateTime startOfWeek, List<String> appIds) async {
    List<double> weeklyEmissions = List.filled(7, 0.0);
    
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      DateTime targetDate = startOfWeek.add(Duration(days: dayIndex));
      double dayEmission = 0.0;
      
      Map<String, dynamic> dayUsageData = await _getDayUsageData(targetDate, appIds);
      List<dynamic> apps = dayUsageData['apps'] ?? [];
      
      for (var appData in apps) {
        String packageName = appData['id'] ?? '';
        double totalUsage = (appData['totalUsage'] ?? 0.0).toDouble();
        
        double emitRate = getEmitRate(packageName);
        double hours = totalUsage / 60;
        dayEmission += hours * emitRate;
      }
      
      weeklyEmissions[dayIndex] = double.parse(dayEmission.toStringAsFixed(2));
      print('${_getDayString(targetDate)}: ${dayEmission.toStringAsFixed(2)}g CO2');
    }
    
    return weeklyEmissions;
  }

  static Future<List<Map<String, dynamic>>> _calculateAppsWeeklyUsage(DateTime startOfWeek, List<String> appIds) async {
    List<Map<String, dynamic>> appsWeeklyData = [];
    
    for (String appId in appIds) {
      List<double> weeklyUsage = List.filled(7, 0.0);
      
      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        DateTime targetDate = startOfWeek.add(Duration(days: dayIndex));
        
        double dayUsage = await _getAppDayUsage(targetDate, appId);
        weeklyUsage[dayIndex] = double.parse(dayUsage.toStringAsFixed(2));
      }
      
      appsWeeklyData.add({
        'id': appId,
        'weeklyUsage': weeklyUsage,
      });
      
      double totalWeekUsage = weeklyUsage.reduce((a, b) => a + b);
      if (totalWeekUsage > 0) {
        print('$appId weekly total: ${totalWeekUsage.toStringAsFixed(2)} minutes');
      }
    }
    
    return appsWeeklyData;
  }

  // Get usage data of specific date
  static Future<Map<String, dynamic>> _getDayUsageData(DateTime date, List<String> appIds) async {
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    print('Getting usage data for ${date.toIso8601String().substring(0, 10)}');
    
    final allEvents = await UsageStats.queryEvents(dayStart, dayEnd);
    
    final eventsByApp = <String, List<dynamic>>{
      for (var id in appIds) id: <dynamic>[],
    };
    
    for (var e in allEvents) {
      if (eventsByApp.containsKey(e.packageName)) {
        eventsByApp[e.packageName]!.add(e);
      }
    }
    
    final appsResult = <Map<String, dynamic>>[];
    
    for (var appId in appIds) {
      final events = eventsByApp[appId]!;
      
      // sorting(key = tiem)
      events.sort((a, b) {
        int aTime = int.tryParse(a.timeStamp?.toString() ?? '0') ?? 0;
        int bTime = int.tryParse(b.timeStamp?.toString() ?? '0') ?? 0;
        return aTime.compareTo(bTime);
      });
      
      double totalUsage = 0.0;
      DateTime? sessionStart;
      
      for (var event in events) {
        final ts = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(event.timeStamp?.toString() ?? '0') ?? 0
        );
        final type = int.tryParse(event.eventType?.toString() ?? '0') ?? 0;
        
        if (type == _EVENT_RESUMED) {
          sessionStart = ts;
        } else if ((type == _EVENT_PAUSED || type == _EVENT_STOPPED) && sessionStart != null) {
          final sessionEnd = ts;
          
          final start = sessionStart.isBefore(dayStart) ? dayStart : sessionStart;
          final end = sessionEnd.isAfter(dayEnd) ? dayEnd : sessionEnd;
          
          if (end.isAfter(start)) {
            totalUsage += end.difference(start).inSeconds / 60.0;
          }
          sessionStart = null;
        }
      }
      
      appsResult.add({
        'id': appId,
        'totalUsage': double.parse(totalUsage.toStringAsFixed(2)),
      });
    }
    
    return {'apps': appsResult};
  }

  // get specific usage data of specific day
  static Future<double> _getAppDayUsage(DateTime date, String appId) async {
    Map<String, dynamic> dayData = await _getDayUsageData(date, [appId]);
    List<dynamic> apps = dayData['apps'] ?? [];
    
    for (var app in apps) {
      if (app['id'] == appId) {
        return (app['totalUsage'] ?? 0.0).toDouble();
      }
    }
    
    return 0.0;
  }

  static DateTime _getStartOfWeek(DateTime date) {
    int weekday = date.weekday; // 1=Monday, 7=Sunday
    DateTime startOfWeek = date.subtract(Duration(days: weekday - 1));
    return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  }

  static String _getWeekString(DateTime startOfWeek) {
    DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
    return '${startOfWeek.toIso8601String().substring(0, 10)} to ${endOfWeek.toIso8601String().substring(0, 10)}';
  }

  static String _getDayString(DateTime date) {
    List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    String weekday = weekdays[date.weekday - 1];
    return '${date.toIso8601String().substring(0, 10)} ($weekday)';
  }

  static Future<void> updateWeeklyUsageData() async {
    try {
      print('Updating weekly usage data...');
      await getWeeklyUsageJson();
      print('Weekly usage data updated successfully');
    } catch (e) {
      print('Error updating weekly usage data: $e');
    }
  }

  static Future<void> refreshWeeklyUsageData() async {
    await getWeeklyUsageJson();
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

  static Future<List<AppInfo>> createAppInfosFromJson() async {
    
    await AppInfoData.loadAppList();
    
    
    Map<String, dynamic> dailyData = await loadDailyUsageData();

    print(dailyData);
    
    if (dailyData.isEmpty) {
      return [
        AppInfoData.createAppInfoFromUsage('com.google.android.youtube', 0.0),
      ];
    }
    
    List<AppInfo> appInfos = [];
    List<dynamic> apps = dailyData['apps'] ?? [];
    
    for (var appData in apps) {
      String packageName = appData['id'];
      double totalUsage = appData['totalUsage']?.toDouble() ?? 0.0;
      
      AppInfo appInfo = AppInfoData.createAppInfoFromUsage(packageName, totalUsage);
      appInfos.add(appInfo);
    }
    
    print('Created ${appInfos.length} AppInfos from JSON');
    return appInfos;
  }

  static Future<List<double>> createDailyEmissionsFromJson() async {
    Map<String, dynamic> dailyData = await loadDailyUsageData();
    
    if (dailyData.isEmpty) {
      print("Failed at loading daily data");
      return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    }
    
    List<String> timeSlots = List<String>.from(dailyData['timeSlots'] ?? []);
    List<double> dailyEmissions = List.filled(timeSlots.length, 0.0);
    
    List<dynamic> apps = dailyData['apps'] ?? [];
    
    for (var appData in apps) {
      String packageName = appData['id'];
      List<dynamic> usageBySlot = appData['usageBySlot'] ?? [];
      
      double emitRate = AppInfoData.getEmitRate(packageName);
      
      for (int i = 0; i < 6; i++) {
        double usageMinutes = usageBySlot[i]?.toDouble() ?? 0.0;
        double hours = usageMinutes / 60;
        double emission = hours * emitRate;
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
      AppInfo('com.google.android.youtube', 'YouTube', Icons.play_circle_fill, 0.0, 170.0, 200.0),
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
