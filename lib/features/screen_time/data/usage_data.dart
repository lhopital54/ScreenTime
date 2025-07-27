// features/screen_time/data/usage_data.dart
import '../models/app_info.dart';
import 'app_info_data.dart';

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

  UsageData updateDailyLimit(double newLimit) {
    return UsageData(
      dailyEmissions: dailyEmissions,
      timeLabels: timeLabels,
      weeklyEmissions: weeklyEmissions,
      weekDays: weekDays,
      dailyCarbonLimit: newLimit,
      appInfos: appInfos,
    );
  }

  UsageData updateAppLimit(String appId, double newLimit) {
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

  static Future<UsageData> loadFromStorage() async {

    List<AppInfo> realAppInfos = await AppInfoData.getRealUsageData();
    List<double> realDailyEmissions = await AppInfoData.getHourlyUsageData();
    
    return UsageData(
      dailyEmissions: realDailyEmissions,
      timeLabels: ['00-04', '04-08', '08-12', '12-16', '16-20', '20-24'],
      weeklyEmissions: [85.2, 92.1, 78.5, 105.3, 68.9, 95.7, 86.7],
      weekDays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      dailyCarbonLimit: 500,
      appInfos: realAppInfos,
    );
  }

  // saving data(but do nothing)
  Future<void> saveToStorage() async {
    // will do soon.................
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