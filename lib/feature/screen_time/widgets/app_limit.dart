// features/screen_time/widgets/app_limit.dart
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart' as ia;
import 'package:installed_apps/app_info.dart' as ia;
import '../models/app_info.dart';
import '../data/app_info_data.dart';

class AppLimit extends StatelessWidget {
  final List<AppInfo> appInfos;
  final Function(AppInfo) onAppTap;
  final VoidCallback? onAppAdded;

  const AppLimit({
    Key? key,
    required this.appInfos,
    required this.onAppTap,
    this.onAppAdded,
  }) : super(key: key);

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
          Text(
            'Limit apps',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          ...appInfos.map((app) => _buildAppLimitItem(app)).toList(),
          const SizedBox(height: 10),
          _buildAddAppButton(context),
        ],
      ),
    );
  }

  Widget _buildAppLimitItem(AppInfo app) {
    final double percentage = app.usagePercentage;
    final bool isOverLimit = app.isOverLimit;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () => onAppTap(app),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOverLimit ? Colors.red[300]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: app.icon != null 
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        app.icon!,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.apps,
                            color: Colors.grey,
                            size: 24,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.apps,
                      color: Colors.grey,
                      size: 24,
                    ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${app.currentEmission.toStringAsFixed(1)}g / ${app.limit.toStringAsFixed(1)}g CO₂',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverLimit ? Colors.red[600] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Usage: ${app.currentUsage.toStringAsFixed(1)} min (${app.emitRate}g CO₂ / hr)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverLimit ? Colors.red[400]! : Colors.green[400]!,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddAppButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () => _showAddAppDialog(context),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.blue[200]!,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.blue[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add App to Track',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Select an app to monitor its carbon emissions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.blue[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddAppDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select App to Track',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: FutureBuilder<List<ia.AppInfo>>(
                    future: _getInstalledApps(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading apps: ${snapshot.error}',
                            style: TextStyle(color: Colors.red[600]),
                          ),
                        );
                      }
                      
                      final apps = snapshot.data ?? [];
                      final filteredApps = _filterAvailableApps(apps);
                      
                      if (filteredApps.isEmpty) {
                        return Center(
                          child: Text(
                            'No new apps available to track',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          return _buildAppSelectionItem(context, app);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppSelectionItem(BuildContext context, ia.AppInfo app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          child: app.icon != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  app.icon!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.apps,
                  color: Colors.grey[600],
                  size: 24,
                ),
              ),
        ),
        title: Text(
          app.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          app.packageName,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.add_circle_outline,
          color: Colors.blue[600],
        ),
        onTap: () => _addSelectedApp(context, app),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        tileColor: Colors.grey[50],
      ),
    );
  }

  Future<List<ia.AppInfo>> _getInstalledApps() async {
    try {
      final apps = await ia.InstalledApps.getInstalledApps(true, true);
      // 시스템 앱 제외하고 사용자 앱만 반환
      return apps.where((app) => 
        // !app.packageName.startsWith('com.android') &&
        // !app.packageName.startsWith('com.google.android') &&
        app.name.isNotEmpty
      ).toList();
    } catch (e) {
      print('Error getting installed apps: $e');
      return [];
    }
  }

  List<ia.AppInfo> _filterAvailableApps(List<ia.AppInfo> allApps) {
    // 이미 추가된 앱들 제외
    final existingPackageNames = appInfos.map((app) => app.id).toSet();
    
    return allApps.where((app) => 
      !existingPackageNames.contains(app.packageName) &&
      !AppInfoData.isRegisteredApp(app.packageName)
    ).toList();
  }

  Future<void> _addSelectedApp(BuildContext context, ia.AppInfo selectedApp) async {
    Navigator.pop(context); // 다이얼로그 닫기
    
    // 설정값 입력 다이얼로그 표시
    _showAppSettingsDialog(context, selectedApp);
  }

  Future<void> _showAppSettingsDialog(BuildContext context, ia.AppInfo selectedApp) async {
    final TextEditingController emitRateController = TextEditingController(text: '150.0');
    final TextEditingController limitController = TextEditingController(text: '200.0');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('App Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: selectedApp.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        selectedApp.icon!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(Icons.apps),
                title: Text(selectedApp.name),
                subtitle: Text(selectedApp.packageName),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emitRateController,
                decoration: const InputDecoration(
                  labelText: 'Emission Rate (g CO₂/hour)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                decoration: const InputDecoration(
                  labelText: 'Daily Limit (g CO₂)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveNewApp(
                  context,
                  selectedApp,
                  emitRateController.text,
                  limitController.text,
                );
              },
              child: Text('Add App'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveNewApp(
    BuildContext context,
    ia.AppInfo selectedApp,
    String emitRateText,
    String limitText,
  ) async {
    try {
      double emitRate = double.tryParse(emitRateText) ?? 170.0;
      double limit = double.tryParse(limitText) ?? 200.0;
      
      // 앱 아이콘도 함께 저장
      if (selectedApp.icon != null) {
        AppInfoData.appIcons[selectedApp.packageName] = selectedApp.icon;
      }
      
      await AppInfoData.addApp(
        packageName: selectedApp.packageName,
        displayName: selectedApp.name,
        emitRate: emitRate,
        defaultLimit: limit,
      );
      
      Navigator.pop(context); // 설정 다이얼로그 닫기
      
      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedApp.name} added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 부모 위젯에 알림 (앱 목록 새로고침용)
      onAppAdded?.call();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding app: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}