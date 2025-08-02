// features/screen_time/widgets/weekly_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/usage_data.dart';

class WeeklyChart extends StatelessWidget {
  final UsageData usageData;
  final VoidCallback onRefresh;

  const WeeklyChart({
    super.key,
    required this.usageData,
    required this.onRefresh,
  });

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
          const SizedBox(height: 15),
          _buildProgressBar(),
          const SizedBox(height: 20),
          _buildChart(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final double weeklyTotal = usageData.weeklyEmissions.fold(0.0, (sum, value) => sum + value);
    final double dailyTarget = usageData.dailyCarbonLimit;
    final double weeklyTarget = dailyTarget * 7;
    final bool isOverLimit = weeklyTotal > weeklyTarget;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly carbon emission',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800] ?? Colors.grey,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Daily average',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500] ?? Colors.grey,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 5),
            Text.rich(
              TextSpan(
                text: '${(weeklyTotal / DateTime.now().weekday).toStringAsFixed(1)} g',
                style: TextStyle(
                  fontSize: 20,
                  color: isOverLimit ? (Colors.red[600] ?? Colors.red) : (Colors.green[600] ?? Colors.green),
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: ' / ${dailyTarget.toStringAsFixed(1)} g CO₂',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[700] ?? Colors.grey,
                      fontWeight: FontWeight.w300,
                    ),
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
            color: Colors.grey[600] ?? Colors.grey,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final double weeklyTotal = usageData.weeklyEmissions.fold(0.0, (sum, value) => sum + value);
    final double weeklyTarget = usageData.dailyCarbonLimit * 7;
    final bool isOverLimit = weeklyTotal > weeklyTarget;
    
    return Container(
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.grey[200],
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (weeklyTotal / weeklyTarget).clamp(0.0, 1.0),
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
      child: LineChart(
        LineChartData(
          maxY: _calculateMaxY(),
          minY: 0,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: const Color(0xFF424242), // Colors.grey[800]과 동일
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final dayIndex = touchedSpot.x.toInt();
                  if (dayIndex >= 0 && dayIndex < usageData.weekDays.length) {
                    return LineTooltipItem(
                      '${usageData.weekDays[dayIndex]}\n'
                      '${touchedSpot.y.toStringAsFixed(1)} g CO₂',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }
                  return null;
                }).toList();
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
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.toInt();
                  if (index >= 0 && index < usageData.weekDays.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        usageData.weekDays[index],
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
          lineBarsData: [
            _createLineChartBarData(),
          ],
        ),
      ),
    );
  }

  LineChartBarData _createLineChartBarData() {
    final List<FlSpot> spots = usageData.weeklyEmissions.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: Colors.green[500]!,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final bool isToday = index == (DateTime.now().weekday - 1);
          return FlDotCirclePainter(
            radius: isToday ? 6 : 4,
            color: isToday ? Colors.green[700]! : Colors.white,
            strokeWidth: 2,
            strokeColor: Colors.green[500]!,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            Colors.green[400]!.withValues(alpha: 0.3),
            Colors.green[400]!.withValues(alpha: 0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      shadow: Shadow(
        color: Colors.green.withValues(alpha: 0.2),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    );
  }

  double _calculateMaxY() {
    if (usageData.weeklyEmissions.isEmpty) return 120.0;
    
    final double maxEmission = usageData.weeklyEmissions.reduce((a, b) => a > b ? a : b);

    return (maxEmission * 1.2).clamp(120.0, double.infinity);
  }

  double _calculateGridInterval() {
    final double maxY = _calculateMaxY();
    return maxY / 6;
  }
}