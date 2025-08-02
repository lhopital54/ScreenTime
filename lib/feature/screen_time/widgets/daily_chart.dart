// features/screen_time/widgets/daily_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/usage_data.dart';

class DailyChart extends StatelessWidget {
  final UsageData usageData;
  final VoidCallback onLimitTap;
  final VoidCallback onRefresh;

  const DailyChart({
    Key? key,
    required this.usageData,
    required this.onLimitTap,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isOverLimit = usageData.isOverDailyLimit;
    
    return GestureDetector(
      onTap: onLimitTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isOverLimit ? Colors.red[300]! : Colors.transparent,
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
            _buildHeader(isOverLimit),
            const SizedBox(height: 15),
            _buildProgressBar(isOverLimit),
            const SizedBox(height: 20),
            _buildChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isOverLimit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily carbon emission',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 5),
            Text.rich(
              TextSpan(
                text: '${usageData.totalDailyEmissions.toStringAsFixed(1)} g',
                style: TextStyle(
                  fontSize: 20,
                  color: isOverLimit ? Colors.red[600] : Colors.green[600],
                  fontWeight: FontWeight.w800),
                children: [
                  TextSpan(
                    text: ' / ${usageData.dailyCarbonLimit.toStringAsFixed(1)} g CO₂',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w300),
                  )
                ],
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: onRefresh,
          icon: Icon(
            Icons.refresh,
            color: Colors.grey[600],
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(bool isOverLimit) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.grey[200],
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (usageData.totalDailyEmissions / usageData.dailyCarbonLimit)
            .clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isOverLimit ? Colors.red[400] : Colors.green[400],
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _calculateMaxY(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.grey[800],
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${usageData.timeLabels[group.x.toInt()]}\n'
                  '${rod.toY.toStringAsFixed(1)} g CO₂',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            horizontalInterval: _calculateGridInterval(),
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[300]!,
                strokeWidth: 1,
                dashArray: [3, 3],
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey[300]!,
                strokeWidth: 1,
                dashArray: [3, 3],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value >= 0 && value < usageData.timeLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        usageData.timeLabels[value.toInt()],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _calculateGridInterval(),
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    '${value.toInt()}g',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _buildBarGroups(),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return usageData.dailyEmissions.asMap().entries.map((entry) {
      final int index = entry.key;
      final double value = entry.value;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: _getBarColor(value),
            width: 25,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
            gradient: LinearGradient(
              colors: [
                _getBarColor(value),
                _getBarColor(value).withValues(alpha: 0.7),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
    }).toList();
  }

  Color _getBarColor(double value) {
    final double maxValue = usageData.dailyEmissions.reduce((a, b) => a > b ? a : b);
    final double ratio = value / maxValue;
    
    if (ratio > 0.8) {
      return Colors.red[400]!;
    } else if (ratio > 0.6) {
      return Colors.orange[400]!;
    } else if (ratio > 0.4) {
      return Colors.yellow[600]!;
    } else {
      return Colors.green[400]!;
    }
  }

  double _calculateMaxY() {
    final double maxEmission = usageData.dailyEmissions.reduce((a, b) => a > b ? a : b);
    return (maxEmission * 1.2).clamp(30.0, double.infinity);
  }

  double _calculateGridInterval() {
    final double maxY = _calculateMaxY();
    return maxY / 6;
  }
}