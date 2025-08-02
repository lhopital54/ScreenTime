// features/screen_time/widgets/weekly_insights_widget.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import '../data/app_info_data.dart';

class WeeklyInsightsWidget extends StatefulWidget {
  const WeeklyInsightsWidget({super.key});

  @override
  State<WeeklyInsightsWidget> createState() => _WeeklyInsightsWidgetState();
  
  // refresh(for external use)
  static void refreshInsights() {
    _WeeklyInsightsWidgetState._refreshController?.add(null);
  }
}

class _WeeklyInsightsWidgetState extends State<WeeklyInsightsWidget> {
  WeeklyInsight? _insight;
  bool _isLoadingInsight = true;
  
  // static controller
  static StreamController<void>? _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = StreamController<void>.broadcast();
    _refreshController!.stream.listen((_) => _loadInsights());
    _loadInsights();
  }

  @override
  void dispose() {
    _refreshController?.close();
    _refreshController = null;
    super.dispose();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoadingInsight = true);
    
    try {
      WeeklyInsight insight = await WeeklyInsightsService.calculateWeeklyInsights();
      if (mounted) {
        setState(() {
          _insight = insight;
          _isLoadingInsight = false;
        });
      }
    } catch (e) {
      print('Error loading insights: $e');
      if (mounted) {
        setState(() => _isLoadingInsight = false);
      }
    }
  }

  Future<void> refreshInsights() async {
    await _loadInsights();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildInsightContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.insights, color: Colors.blue[600], size: 24),
        const SizedBox(width: 8),
        Text(
          'Weekly Insights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightContent() {
    if (_isLoadingInsight) {
      return Container(
        height: 100,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_insight == null || !_insight!.hasData) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Not enough data for insights yet.\nKeep tracking your usage to see patterns!',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[100]!, width: 1),
      ),
      child: _buildInsightItems(),
    );
  }

  Widget _buildInsightItems() {
    List<Widget> insights = [];

    if (_insight!.hasPreviousWeekData) {
      bool isImproving = _insight!.isImproving;
      
      insights.add(
        _buildInsightItem(
          icon: isImproving ? Icons.trending_down : Icons.trending_up,
          iconColor: isImproving ? Colors.green[600]! : Colors.red[600]!,
          text: _insight!.changeText,
          description: _insight!.changeDescription,
        ),
      );
    } else {
      insights.add(
        _buildInsightItem(
          icon: Icons.history,
          iconColor: Colors.grey[600]!,
          text: 'First week tracking',
          description: 'Keep going to see progress next week!',
        ),
      );
    }

    if (_insight!.mostUsedApp != null) {
      insights.add(
        _buildInsightItem(
          icon: Icons.smartphone,
          iconColor: Colors.orange[600]!,
          text: 'Most used: ${_insight!.mostUsedAppDisplay}',
          description: 'Consider setting limits for this app',
        ),
      );
    }

    // 피크 요일
    if (_insight!.peakDay != null) {
      insights.add(
        _buildInsightItem(
          icon: Icons.calendar_today,
          iconColor: Colors.purple[600]!,
          text: 'Peak day: ${_insight!.peakDay}',
          description: _insight!.peakDayDisplay,
        ),
      );
    }

    if (insights.isEmpty) {
      return Text(
        'Keep using the app to see more insights!',
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      );
    }

    return Column(
      children: insights.asMap().entries.map((entry) {
        int index = entry.key;
        Widget widget = entry.value;
        
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < insights.length - 1 ? 12 : 0,
          ),
          child: widget,
        );
      }).toList(),
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required Color iconColor,
    required String text,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WeeklyInsightsService {
  static Future<void> backupCurrentWeekData() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File currentFile = File('${appDocDir.path}/weekly_usage.json');
      File previousFile = File('${appDocDir.path}/previous_week_usage.json');
      
      if (await currentFile.exists()) {
        String currentData = await currentFile.readAsString();
        await previousFile.writeAsString(currentData);
        print('Weekly data backed up to previous week');
      }
    } catch (e) {
      print('Error backing up weekly data: $e');
    }
  }
  
  static Future<Map<String, dynamic>?> _loadPreviousWeekData() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File previousFile = File('${appDocDir.path}/previous_week_usage.json');
      
      if (await previousFile.exists()) {
        String jsonString = await previousFile.readAsString();
        return jsonDecode(jsonString);
      }
      return null;
    } catch (e) {
      print('Error loading previous week data: $e');
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> _loadCurrentWeekData() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File currentFile = File('${appDocDir.path}/weekly_usage.json');
      
      if (await currentFile.exists()) {
        String jsonString = await currentFile.readAsString();
        return jsonDecode(jsonString);
      }
      return null;
    } catch (e) {
      print('Error loading current week data: $e');
      return null;
    }
  }
  
  static Future<WeeklyInsight> calculateWeeklyInsights() async {
    Map<String, dynamic>? currentWeek = await _loadCurrentWeekData();
    Map<String, dynamic>? previousWeek = await _loadPreviousWeekData();
    
    if (currentWeek == null) {
      return WeeklyInsight.empty();
    }
    
    // weekly emission
    List<double> currentEmissions = List<double>.from(currentWeek['weeklyEmissions'] ?? []);
    double currentTotal = currentEmissions.fold(0.0, (sum, value) => sum + value);
    
    // comparing
    double? changePercentage;
    if (previousWeek != null) {
      List<double> previousEmissions = List<double>.from(previousWeek['weeklyEmissions'] ?? []);
      double previousTotal = previousEmissions.fold(0.0, (sum, value) => sum + value);
      
      if (previousTotal > 0) {
        changePercentage = ((currentTotal - previousTotal) / previousTotal) * 100;
      }
    }
    
    // finding mostusedapp
    String? mostUsedApp;
    double maxUsage = 0.0;
    List<dynamic> apps = currentWeek['apps'] ?? [];
    
    for (var app in apps) {
      List<double> usage = List<double>.from(app['weeklyUsage'] ?? []);
      double totalUsage = usage.fold(0.0, (sum, value) => sum + value);
      
      if (totalUsage > maxUsage) {
        maxUsage = totalUsage;
        mostUsedApp = app['id'];
      }
    }
    
    // finding peak day
    String? peakDay;
    double maxDayEmission = 0.0;
    List<String> weekDays = List<String>.from(currentWeek['weekDays'] ?? []);
    
    for (int i = 0; i < currentEmissions.length && i < weekDays.length; i++) {
      if (currentEmissions[i] > maxDayEmission) {
        maxDayEmission = currentEmissions[i];
        peakDay = weekDays[i];
      }
    }
    
    return WeeklyInsight(
      changePercentage: changePercentage,
      mostUsedApp: mostUsedApp,
      peakDay: peakDay,
      currentWeekTotal: currentTotal,
      peakDayEmission: maxDayEmission,
      maxUsage: maxUsage,
    );
  }
  
  // app name mapping
  static String _getAppDisplayName(String packageName) {
    try {
      final appMetadata = AppInfoData.appMetadata[packageName];
      if (appMetadata != null && appMetadata.displayName.isNotEmpty) {
        return appMetadata.displayName;
      }
    } catch (e) {
      print('Error getting app name from AppInfoData: $e');
    }
    
    return packageName.split('.').last.replaceFirstMapped(
      RegExp(r'^[a-z]'),
      (match) => match.group(0)!.toUpperCase(),
    );
  }
}

// 인사이트 데이터 모델
class WeeklyInsight {
  final double? changePercentage; // 지난 주 대비 변화율
  final String? mostUsedApp; // 가장 많이 사용한 앱
  final String? peakDay; // 가장 많이 사용한 요일
  final double currentWeekTotal; // 현재 주 총 배출량
  final double peakDayEmission; // 피크 요일 배출량
  final double maxUsage; // 가장 많이 사용한 앱의 사용량
  
  WeeklyInsight({
    this.changePercentage,
    this.mostUsedApp,
    this.peakDay,
    required this.currentWeekTotal,
    required this.peakDayEmission,
    required this.maxUsage,
  });
  
  factory WeeklyInsight.empty() {
    return WeeklyInsight(
      currentWeekTotal: 0.0,
      peakDayEmission: 0.0,
      maxUsage: 0.0,
    );
  }
  
  // 헬퍼 메서드들
  bool get hasData => currentWeekTotal > 0;
  bool get hasPreviousWeekData => changePercentage != null;
  bool get isImproving => changePercentage != null && changePercentage! < 0;
  
  String get changeText {
    if (!hasPreviousWeekData) return 'No previous data';
    
    double absChange = changePercentage!.abs();
    String direction = isImproving ? '↓' : '↑';
    return '$direction ${absChange.toStringAsFixed(1)}% vs last week';
  }
  
  String get changeDescription {
    if (!hasPreviousWeekData) return 'Keep tracking to see progress';
    
    return isImproving 
      ? 'Great! You reduced emissions' 
      : 'Try to reduce usage this week';
  }
  
  String get mostUsedAppDisplay {
    if (mostUsedApp == null) return 'No app data';
    return WeeklyInsightsService._getAppDisplayName(mostUsedApp!);
  }
  
  String get peakDayDisplay {
    if (peakDay == null) return 'No data';
    return '${peakDayEmission.toStringAsFixed(1)}g CO₂';
  }
}