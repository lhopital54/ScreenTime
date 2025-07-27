// features/screen_time/screen_time_screen.dart
import 'package:flutter/material.dart';
import 'data/usage_data.dart';
import 'data/app_info_data.dart';
import 'models/app_info.dart';
import 'widgets/app_lock.dart';
import 'widgets/daily_chart.dart';
import 'widgets/app_limit.dart';
import 'widgets/weekly_chart.dart';

class ScreenTimeScreen extends StatefulWidget {
  @override
  _ScreenTimeScreenState createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  bool isAppLocked = false;
  UsageData? usageData;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
    _checkPermissionAndLoadData();
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  void _checkPermissionAndLoadData() async {
    bool hasPermission = await AppInfoData.checkUsagePermission();
    if (!hasPermission) {
      _showPermissionDialog();
    } else {
      _loadData();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.security, color: Colors.orange[600], size: 24),
              const SizedBox(width: 8),
              const Text('Require permission'),
            ],
          ),
          content: const Text(
            'To see your actual app usage, we need permission to access usage data.\n'
            'Please enable it in your Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadData(); // sample data(no permission)
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AppInfoData.requestUsagePermission();
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[400],
                foregroundColor: Colors.white,
              ),
              child: const Text('Set permission'),
            ),
          ],
        );
      },
    );
  }

  void _loadData() async {
    final data = await UsageData.loadFromStorage();
    setState(() {
      usageData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (usageData == null) {
      return SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        'Climate Screen Time',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                // Sub tab(daily/weekly)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TabBar(
                    controller: _subTabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.green[400],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        height: 36,
                        text: 'Daily',
                      ),
                      Tab(
                        height: 36,
                        text: 'Weekly',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _subTabController,
              children: [
                _buildDailyTab(),
                _buildWeeklyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLock(
            isAppLocked: isAppLocked,
            onToggle: () {
              setState(() {
                isAppLocked = !isAppLocked;
              });
            },
          ),
          const SizedBox(height: 30),
          DailyChart(
            usageData: usageData!,
            onLimitTap: _showDailyLimitDialog,
          ),
          const SizedBox(height: 30),
          AppLimit(
            appInfos: usageData!.appInfos,
            onAppTap: _showAppLimitDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeeklySummary(),
          const SizedBox(height: 30),
          WeeklyChart(usageData: usageData!),
        ],
      ),
    );
  }

  Widget _buildWeeklySummary() {
    final double averageDaily = usageData!.averageDailyEmissions;
    final double weeklyLimit = usageData!.weeklyLimit;
    final double averageLimit = weeklyLimit / 7;
    final bool isOverWeeklyLimit = usageData!.isOverWeeklyLimit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isOverWeeklyLimit ? Colors.red[300]! : Colors.transparent,
          width: 2,
        ),
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
          Text(
            'Carbon emission of this week',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total emission',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${usageData!.totalWeeklyEmissions.toStringAsFixed(1)}g CO₂',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isOverWeeklyLimit
                          ? Colors.red[600]
                          : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Daily average',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${averageDaily.toStringAsFixed(1)}g CO₂',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: (usageData!.totalWeeklyEmissions / weeklyLimit).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isOverWeeklyLimit ? Colors.red[400]! : Colors.green[400]!,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Daily average goal: ${averageLimit.toStringAsFixed(1)}g CO₂ / day',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showDailyLimitDialog() {
    double newLimit = usageData!.dailyCarbonLimit;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.eco, color: Colors.green[600], size: 24),
                  const SizedBox(width: 8),
                  const Text('Set daily limit'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current emission: ${usageData!.totalDailyEmissions.toStringAsFixed(1)} g CO₂',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recommended: Under 500 g CO₂',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Daily limit: ${newLimit.toStringAsFixed(1)} g CO₂',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: newLimit,
                    min: 100,
                    max: 1000,
                    divisions: 900,
                    activeColor: Colors.green[400],
                    inactiveColor: Colors.grey[300],
                    onChanged: (value) {
                      setDialogState(() {
                        newLimit = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.grey[200],
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor:
                          (usageData!.totalDailyEmissions / newLimit).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: usageData!.totalDailyEmissions > newLimit
                              ? Colors.red[400]
                              : Colors.green[400],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    usageData!.totalDailyEmissions > newLimit
                        ? 'Current emission is over limit'
                        : 'Current emission is under limit',
                    style: TextStyle(
                      fontSize: 12,
                      color: usageData!.totalDailyEmissions > newLimit
                          ? Colors.red[600]
                          : Colors.green[600],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      usageData = usageData!.updateDailyLimit(newLimit);
                    });
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[400],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAppLimitDialog(AppInfo app) {
    double newLimit = app.limit;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Set limit of ${app.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Current emission: ${app.currentEmission.toStringAsFixed(1)}g CO₂'),
                  Text(
                      '${app.emitRate}g CO₂ / hr'),
                  const SizedBox(height: 15),
                  Text('Daily limit: ${newLimit.toStringAsFixed(1)}g CO₂'),
                  const SizedBox(height: 15),
                  Slider(
                    value: newLimit,
                    min: 50,
                    max: 500,
                    divisions: 450,
                    activeColor: Colors.green[400],
                    onChanged: (value) {
                      setDialogState(() {
                        newLimit = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      usageData = usageData!.updateAppLimit(app.id, newLimit);
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}