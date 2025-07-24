import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';
import 'dart:async';

void main() {
  runApp(const ClimateScreenTimeApp());
}

class ClimateScreenTimeApp extends StatelessWidget {
  const ClimateScreenTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climate Screen Time',
      theme: ThemeData(useMaterial3: true),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Map<String, double> carbonPerHour = {
    'com.google.android.youtube': 100.0,
    'com.zhiliaoapp.musically': 80.0, // TikTok
    'com.instagram.android': 70.0,
    'com.android.chrome': 40.0,
  };

  Map<String, double> appUsagesInMinutes = {};
  double totalCO2 = 0;

  @override
  void initState() {
    super.initState();
    _getUsageStats();
  }

  Future<void> _getUsageStats() async {
    bool granted = await UsageStats.checkUsagePermission() ?? false;
    if (!granted) {
      UsageStats.grantUsagePermission();
      return;
    }

    DateTime end = DateTime.now();
    DateTime start = end.subtract(const Duration(hours: 24));
    List<UsageInfo> stats = await UsageStats.queryUsageStats(start, end);

    Map<String, double> tempUsages = {};
    double total = 0;

    for (var info in stats) {
      if (info.packageName == null || info.totalTimeInForeground == null) continue;

      int ms = int.tryParse(info.totalTimeInForeground!) ?? 0;
      double minutes = ms / 60000.0;

      if (carbonPerHour.containsKey(info.packageName)) {
        tempUsages[info.packageName!] = minutes;

        double hours = minutes / 60.0;
        total += hours * carbonPerHour[info.packageName]!;
      }
    }

    setState(() {
      appUsagesInMinutes = tempUsages;
      totalCO2 = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 탄소 배출량')),
      body: Column(
        children: [
          ListTile(
            title: const Text("총 배출량"),
            subtitle: Text('${totalCO2.toStringAsFixed(1)} g CO₂'),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: appUsagesInMinutes.entries.map((entry) {
                final package = entry.key;
                final minutes = entry.value;
                final co2 = (minutes / 60.0) * carbonPerHour[package]!;
                return ListTile(
                  title: Text(package),
                  subtitle: Text('${minutes.toStringAsFixed(1)}분 사용 → ${co2.toStringAsFixed(1)} g CO₂'),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}