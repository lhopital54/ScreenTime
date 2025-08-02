// features/screen_time/screen_time_screen.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/usage_data.dart';
import 'data/app_info_data.dart';
import 'models/app_info.dart';
import 'widgets/app_lock.dart';
import 'widgets/daily_chart.dart';
import 'widgets/app_limit.dart';
import 'widgets/weekly_chart.dart';
import 'widgets/weekly_insight.dart';

class ScreenTimeScreen extends StatefulWidget {
  @override
  _ScreenTimeScreenState createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  bool isAppLocked = false;
  bool isLoading = true;
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

  Future<void> _initializeJsonFiles() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String localPath = appDocDir.path;
      
      List<String> jsonFiles = [
        'app_list.json',
        'daily_usage.json', 
        'weekly_usage.json'
      ];
      
      for (String fileName in jsonFiles) {
        File localFile = File('$localPath/$fileName');
        
        if (!await localFile.exists()) {
          await createDefaultJsonFile(localFile, fileName);
        } else {
          print('$fileName already exists in local storage');
        }
      }
    } catch (e) {
      print('Error initializing JSON files: $e');
    }
  }

  Future<void> createDefaultJsonFile(File file, String fileName) async {
    try {
      String defaultContent;
      
      switch (fileName) {
        case 'app_list.json':
          defaultContent = '''
  {
    "apps": [
      {
        "packageName": "com.google.android.youtube",
        "displayName": "YouTube",
        "emitRate": 170.0,
        "defaultLimit": 200.0
      }
    ]
  }''';
          break;
          
        case 'daily_usage.json':
          defaultContent = '''
  {
    "date": "${DateTime.now().toIso8601String().substring(0, 10)}",
    "dailyCarbonLimit": 500.0,
    "timeSlots": ["00-04", "04-08", "08-12", "12-16", "16-20", "20-24"],
    "apps": [
      {
        "id": "com.google.android.youtube", 
        "usageBySlot": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        "totalUsage": 0.0
      }
    ]
  }''';
          break;
          
        case 'weekly_usage.json':
          defaultContent = '''
  {
    "week": "${_getWeekString()}",
    "weekDays": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    "weeklyEmissions": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "apps": [
      {
        "id": "com.google.android.youtube",
        "weeklyUsage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
      }
    ]
  }''';
          break;
          
        default:
          defaultContent = '{}';
      }
      
      await file.writeAsString(defaultContent);
      print('Created default $fileName');
      
    } catch (e) {
      print('Error creating default $fileName: $e');
    }
  }

  String _getWeekString() {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
    
    return '${startOfWeek.toIso8601String().substring(0, 10)} to ${endOfWeek.toIso8601String().substring(0, 10)}';
  }

  void _checkPermissionAndLoadData() async {
    await _initializeJsonFiles();

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
    await AppInfoData.refreshWeeklyUsageData();
    WeeklyInsightsWidget.refreshInsights();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.black, size: 20),
            SizedBox(width: 8),
            Text('Usage data has been updated', style: TextStyle(color: Colors.black)),
          ],
        ),
        backgroundColor: Colors.white,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshUsageData() async {
    try {
      _loadData();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refreshing data: $error'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          const SizedBox(height: 20),
          DailyChart(
            usageData: usageData!,
            onLimitTap: _showDailyLimitDialog,
            onRefresh: _refreshUsageData
          ),
          const SizedBox(height: 20),
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
          WeeklyChart(
            usageData: usageData!,
            onRefresh: () {
              AppInfoData.refreshWeeklyUsageData();
            }
          ),
          const SizedBox(height: 20),
          const WeeklyInsightsWidget(),
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
                    divisions: 90,
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
                  onPressed: () async {
                    UsageData updatedData = await usageData!.updateDailyLimit(newLimit);
                    setState(() {
                      usageData = updatedData;
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
                    min: 0,
                    max: 500,
                    divisions: 50,
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
                  onPressed: () async {
                    UsageData updatedData = await usageData!.updateAppLimit(app.id, newLimit);
                    setState(() {
                      usageData = updatedData;
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