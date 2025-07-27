// features/screen_time/widgets/app_limit.dart
import 'package:flutter/material.dart';
import '../models/app_info.dart';

class AppLimit extends StatelessWidget {
  final List<AppInfo> appInfos;
  final Function(AppInfo) onAppTap;

  const AppLimit({
    Key? key,
    required this.appInfos,
    required this.onAppTap,
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
                  color: _getAppColor(app.name).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  app.icon,
                  color: _getAppColor(app.name),
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

  Color _getAppColor(String appName) {
    return Colors.grey;
  }
}