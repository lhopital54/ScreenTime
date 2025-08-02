// features/screen_time/data/usage_data.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/app_info.dart';
import '../data/app_info_data.dart';

class UsageData {
  final List<double> dailyEmissions;
  final List<String> timeLabels;
  final List<double> weeklyEmissions;
  final List<String> weekDays;
  final double dailyCarbonLimit;
  final List<AppInfo> appInfos;

  const UsageData({
    required this.dailyEmissions,
    required this.timeLabels,
    required this.weeklyEmissions,
    required this.weekDays,
    required this.dailyCarbonLimit,
    required this.appInfos,
  });

  double get totalDailyEmissions => 
      dailyEmissions.fold(0.0, (sum, emission) => sum + emission);

  double get totalWeeklyEmissions => 
      weeklyEmissions.fold(0.0, (sum, emission) => sum + emission);

  double get averageDailyEmissions => 
      totalWeeklyEmissions / weekDays.length;

  double get weeklyLimit => dailyCarbonLimit * 7;

  bool get isOverDailyLimit => totalDailyEmissions > dailyCarbonLimit;

  bool get isOverWeeklyLimit => totalWeeklyEmissions > weeklyLimit;

  double get dailyProgress => totalDailyEmissions / dailyCarbonLimit;

  double get weeklyProgress => totalWeeklyEmissions / weeklyLimit;

  DailyPeak get dailyPeak {
    if (dailyEmissions.isEmpty) {
      return DailyPeak(
        peakTimeIndex: 0,
        peakValue: 0.0,
        lowTimeIndex: 0,
        lowValue: 0.0,
      );
    }

    double maxValue = dailyEmissions[0];
    double minValue = dailyEmissions[0];
    int maxIndex = 0;
    int minIndex = 0;

    for (int i = 1; i < dailyEmissions.length; i++) {
      if (dailyEmissions[i] > maxValue) {
        maxValue = dailyEmissions[i];
        maxIndex = i;
      }
      if (dailyEmissions[i] < minValue) {
        minValue = dailyEmissions[i];
        minIndex = i;
      }
    }

    return DailyPeak(
      peakTimeIndex: maxIndex,
      peakValue: maxValue,
      lowTimeIndex: minIndex,
      lowValue: minValue,
    );
  }

  WeeklyPeak get weeklyPeak {
    if (weeklyEmissions.isEmpty) {
      return WeeklyPeak(
        peakDayIndex: 0,
        peakValue: 0.0,
        lowDayIndex: 0,
        lowValue: 0.0,
      );
    }

    double maxValue = weeklyEmissions[0];
    double minValue = weeklyEmissions[0];
    int maxIndex = 0;
    int minIndex = 0;

    for (int i = 1; i < weeklyEmissions.length; i++) {
      if (weeklyEmissions[i] > maxValue) {
        maxValue = weeklyEmissions[i];
        maxIndex = i;
      }
      if (weeklyEmissions[i] < minValue) {
        minValue = weeklyEmissions[i];
        minIndex = i;
      }
    }

    return WeeklyPeak(
      peakDayIndex: maxIndex,
      peakValue: maxValue,
      lowDayIndex: minIndex,
      lowValue: minValue,
    );
  }

  List<AppInfo> get overLimitApps =>
      appInfos.where((app) => app.isOverLimit).toList();

  double get totalAppEmissions =>
      appInfos.fold(0.0, (sum, app) => sum + app.currentEmission);

  Future<UsageData> updateDailyLimit(double newLimit) async {
    try {
      // 1. getting daily_usage.json path
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String filePath = '${appDocDir.path}/daily_usage.json';
      File file = File(filePath);
      
      // 2. read JSON data
      Map<String, dynamic> jsonData;
      String jsonString = await file.readAsString();
      jsonData = json.decode(jsonString);
      
      // 3. update dailyCarbonLimit
      jsonData['dailyCarbonLimit'] = newLimit;
      
      // 4. saving updatd JSON file
      String updatedJson = json.encode(jsonData);
      await file.writeAsString(updatedJson);
      
      print('Daily limit updated to $newLimit and saved to JSON');
      
      // 5. return new data
      return UsageData(
        dailyEmissions: dailyEmissions,
        timeLabels: timeLabels,
        weeklyEmissions: weeklyEmissions,
        weekDays: weekDays,
        dailyCarbonLimit: newLimit,
        appInfos: appInfos,
      );
      } catch (e) {
      print('Error updating daily limit: $e');

      return UsageData(
        dailyEmissions: dailyEmissions,
        timeLabels: timeLabels,
        weeklyEmissions: weeklyEmissions,
        weekDays: weekDays,
        dailyCarbonLimit: newLimit,
        appInfos: appInfos,
      );
    }
  }

  Future<UsageData> updateAppLimit(String appId, double newLimit) async {
    try {
      // 1. getting app_list.json path
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String filePath = '${appDocDir.path}/app_list.json';
      File file = File(filePath);
      
      // 2. read JSON data
      Map<String, dynamic> jsonData;
      String jsonString = await file.readAsString();
      jsonData = json.decode(jsonString);
      
      // 3. update defaultLimit
      List<dynamic> apps = jsonData['apps'];
      bool appFound = false;
      
      for (var app in apps) {
        if (app['packageName'] == appId) {
          app['defaultLimit'] = newLimit;
          appFound = true;
          break;
        }
      }
      
      if (!appFound) {
        print('App $appId not found in JSON');
      }
      
      // 4. saving updated JSON file
      String updatedJson = json.encode(jsonData);
      await file.writeAsString(updatedJson);
      
      // 5. update AppInfoData
      if (AppInfoData.appMetadata.containsKey(appId)) {
        AppInfoData.appMetadata[appId] = AppMetadata(
          packageName: AppInfoData.appMetadata[appId]!.packageName,
          displayName: AppInfoData.appMetadata[appId]!.displayName,
          emitRate: AppInfoData.appMetadata[appId]!.emitRate,
          defaultLimit: newLimit,
        );
      }
      
      print('App limit for $appId updated to $newLimit and saved to JSON');
      
      // 6. generate updated list
      final updatedApps = appInfos.map((app) {
        if (app.id == appId) {
          return app.updateLimit(newLimit);
        }
        return app;
      }).toList();
      
      // 7. return new data
      return UsageData(
        dailyEmissions: dailyEmissions,
        timeLabels: timeLabels,
        weeklyEmissions: weeklyEmissions,
        weekDays: weekDays,
        dailyCarbonLimit: dailyCarbonLimit,
        appInfos: updatedApps,
      );
      
    } catch (e) {
      print('Error updating app limit: $e');
      // update just memory when error
      final updatedApps = appInfos.map((app) {
        if (app.id == appId) {
          return app.updateLimit(newLimit);
        }
        return app;
      }).toList();
      
      return UsageData(
        dailyEmissions: dailyEmissions,
        timeLabels: timeLabels,
        weeklyEmissions: weeklyEmissions,
        weekDays: weekDays,
        dailyCarbonLimit: dailyCarbonLimit,
        appInfos: updatedApps,
      );
    }
  }

  static Future<UsageData> loadFromStorage() async {
    AppInfoData.getDailyUsageJson();
    print('Loading data from JSON files...');
    
    List<AppInfo> appInfos = await AppInfoData.createAppInfosFromJson();
    List<double> dailyEmissions = await AppInfoData.createDailyEmissionsFromJson();
    List<double> weeklyEmissions = await AppInfoData.createWeeklyEmissionsFromJson();
    Map<String, dynamic> dailyData = await AppInfoData.loadDailyUsageData();
    
    // get dailyCarbonLimit adnd timeLabels
    double dailyCarbonLimit = dailyData['dailyCarbonLimit']?.toDouble();
    
    print('Data loaded: ${appInfos.length} apps, ${dailyEmissions.length} time slots');
    
    return UsageData(
      dailyEmissions: dailyEmissions,
      timeLabels: ['00-04', '04-08', '08-12', '12-16', '16-20', '20-24'],
      weeklyEmissions: weeklyEmissions,
      weekDays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      dailyCarbonLimit: dailyCarbonLimit,
      appInfos: appInfos,
    );
  }

  @override
  String toString() {
    return 'UsageData(dailyTotal: ${totalDailyEmissions.toStringAsFixed(1)}g, '
           'weeklyTotal: ${totalWeeklyEmissions.toStringAsFixed(1)}g, '
           'limit: ${dailyCarbonLimit.toStringAsFixed(1)}g)';
  }
}

class DailyPeak {
  final int peakTimeIndex;
  final double peakValue;
  final int lowTimeIndex;
  final double lowValue;

  const DailyPeak({
    required this.peakTimeIndex,
    required this.peakValue,
    required this.lowTimeIndex,
    required this.lowValue,
  });

  String getPeakTimeLabel(List<String> timeLabels) {
    if (peakTimeIndex >= 0 && peakTimeIndex < timeLabels.length) {
      return timeLabels[peakTimeIndex];
    }
    return '';
  }

  String getLowTimeLabel(List<String> timeLabels) {
    if (lowTimeIndex >= 0 && lowTimeIndex < timeLabels.length) {
      return timeLabels[lowTimeIndex];
    }
    return '';
  }
}

class WeeklyPeak {
  final int peakDayIndex;
  final double peakValue;
  final int lowDayIndex;
  final double lowValue;

  const WeeklyPeak({
    required this.peakDayIndex,
    required this.peakValue,
    required this.lowDayIndex,
    required this.lowValue,
  });

  String getPeakDayLabel(List<String> weekDays) {
    if (peakDayIndex >= 0 && peakDayIndex < weekDays.length) {
      return weekDays[peakDayIndex];
    }
    return '';
  }

  String getLowDayLabel(List<String> weekDays) {
    if (lowDayIndex >= 0 && lowDayIndex < weekDays.length) {
      return weekDays[lowDayIndex];
    }
    return '';
  }
}