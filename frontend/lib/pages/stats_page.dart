// frontend/lib/pages/stats_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lexilearn/constants.dart'; // 引入常量
import 'package:lexilearn/providers/stats_provider.dart';
import 'package:lexilearn/providers/auth_provider.dart'; // 需要 UserDataStatus
import 'package:fl_chart/fl_chart.dart'; // 引入图表库
import 'dart:math';
import 'package:intl/intl.dart'; // 需要日期格式化
import 'package:flutter/foundation.dart';
import 'package:lexilearn/main.dart'; // 引入 routeObserver

// --- Chart Widget Implementations ---

// region Word Count Chart (BarChart based on BarChartSample2)
class WordCountBarChart extends StatefulWidget {
  // 移除 AppColors 引用，改为从 constants.dart 获取
  // final Color leftBarColor = AppColors.contentColorYellow; // Example Color
  // final Color rightBarColor = AppColors.contentColorRed; // Example Color
  // final Color avgColor = AppColors.contentColorOrange.avg(AppColors.contentColorRed); // Example Color

  const WordCountBarChart({super.key});

  @override
  State<StatefulWidget> createState() => WordCountBarChartState();
}

class WordCountBarChartState extends State<WordCountBarChart> {
  final double width = 7; // Bar width

  late List<BarChartGroupData> rawBarGroups;
  late List<BarChartGroupData> showingBarGroups;
  late List<StatsChartDataPoint> weekData; // 存储原始数据点
  double maxY = 20; // Default max Y, will be calculated

  int touchedGroupIndex = -1;

  // 从 constants.dart 获取颜色
  late Color leftBarColor; // Learned count color
  late Color rightBarColor; // Reviewed count color
  late Color avgColor; // Color on touch (using tertiary for now)

  @override
  void initState() {
    super.initState();
    // _loadChartData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当 Provider 更新时（例如切换主题），重新加载数据以更新颜色
    _loadChartData();
  }

  // 从 Provider 加载数据并设置图表
  void _loadChartData() {
    final statsProvider = context.read<StatsProvider>();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // 设置颜色
    leftBarColor =
        isDarkMode ? statsLearnCurveColorDark : statsLearnCurveColorLight;
    rightBarColor =
        isDarkMode ? statsReviewCurveColorDark : statsReviewCurveColorLight;
    avgColor = tertiaryColor; // 使用常量中的 tertiaryColor 作为触摸时的颜色

    // 获取过去7天的数据
    final data = statsProvider.wordChartData;
    final now = DateTime.now().dateOnly;
    weekData = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return data.firstWhere((p) => p.date == date,
          orElse: () => StatsChartDataPoint(date, 0, 0));
    });

    if (weekData.isEmpty) {
      rawBarGroups = [];
      showingBarGroups = [];
      maxY = 20; // Reset to default if empty
      // Check if mounted before calling setState
      if (mounted) {
        setState(() {});
      }
      return;
    }

    // 计算 maxY
    double tempMaxY = 0;
    for (var p in weekData) {
      tempMaxY = max(tempMaxY, max(p.value1, p.value2));
    }
    // Ensure maxY is at least 10 for better visualization, add buffer
    maxY = (tempMaxY < 10) ? 10 : (tempMaxY * 1.2).ceilToDouble();

    // 生成 BarChartGroupData
    rawBarGroups = List.generate(weekData.length, (index) {
      final dataPoint = weekData[index];
      return makeGroupData(
          index,
          dataPoint.value1, // Learned count (y1)
          dataPoint.value2, // Reviewed count (y2)
          isTouched: index == touchedGroupIndex);
    });

    showingBarGroups = List.of(rawBarGroups);
    // Check if mounted before calling setState after async gap (if any future provider update)
    if (mounted) {
      setState(() {});
    }
  }

  // 检查数据是否有效为空 (所有值都 <= 0)
  bool _isEffectivelyEmpty(List<StatsChartDataPoint> data) {
    if (data.isEmpty) return true;
    return data.every((p) => p.value1 <= 0 && p.value2 <= 0);
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.data_exploration_outlined,
              size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text("暂无单词学习记录", style: subtitleStyle),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否应该显示空状态
    final statsProvider = context.watch<StatsProvider>(); // Watch for changes
    if (_isEffectivelyEmpty(weekData) && !statsProvider.isLoading) {
      return _buildEmptyState(context);
    }
    // If loading or data exists, build the chart
    // Re-read colors in build in case theme changed
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    leftBarColor =
        isDarkMode ? statsLearnCurveColorDark : statsLearnCurveColorLight;
    rightBarColor =
        isDarkMode ? statsReviewCurveColorDark : statsReviewCurveColorLight;
    avgColor = tertiaryColor;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.grey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              // Tooltip logic
              if (groupIndex < 0 || groupIndex >= weekData.length) return null;
              final dataPoint = weekData[groupIndex];
              final dateStr = DateFormat('MM-dd').format(dataPoint.date);
              final String type = rodIndex == 0 ? '学习' : '复习';
              final int value = rod.toY.toInt();
              final Color valueColor =
                  rodIndex == 0 ? leftBarColor : rightBarColor;

              return BarTooltipItem(
                '$dateStr\n',
                TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface, // Use theme color
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
                children: <TextSpan>[
                  TextSpan(
                    text: '$type: ',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11),
                  ),
                  TextSpan(
                    text: '$value 词',
                    style: TextStyle(
                        color: valueColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11),
                  ),
                ],
                textAlign: TextAlign.center,
              );
            },
            tooltipRoundedRadius: 8, // Add some radius
          ),
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            setState(() {
              // Case 1: 触摸结束或无效
              if (!event.isInterestedForInteractions ||
                  barTouchResponse == null ||
                  barTouchResponse.spot == null) {
                touchedGroupIndex = -1; // 重置触摸索引
                showingBarGroups = List.of(rawBarGroups); // 恢复显示原始数据
                return;
              }

              // Case 2: 触摸到某个组
              final newTouchedGroupIndex =
                  barTouchResponse.spot!.touchedBarGroupIndex;

              // 如果触摸索引发生了变化
              if (touchedGroupIndex != newTouchedGroupIndex) {
                touchedGroupIndex = newTouchedGroupIndex; // 更新当前触摸的组索引

                // 基于原始数据创建显示列表
                showingBarGroups = List.of(rawBarGroups);

                // 修改被触摸组的外观
                if (touchedGroupIndex != -1) {
                  final originalGroup = showingBarGroups[touchedGroupIndex];
                  showingBarGroups[touchedGroupIndex] = originalGroup.copyWith(
                    // 创建新的 barRods 列表，只修改外观
                    barRods: originalGroup.barRods.map((rod) {
                      return rod.copyWith(
                        // --- 这里是关键修改 ---
                        // toY: rod.toY, // 保持原始高度，这行可以省略，因为 copyWith 默认不修改
                        color: avgColor, // 将颜色改为高亮色 (avgColor 即 tertiaryColor)
                        // 你也可以选择添加边框来高亮:
                        // borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
                        // --- 修改结束 ---
                      );
                    }).toList(),
                  );
                }
              }
              // 可选：处理触摸在组内但未精确在柱子上的情况，目前逻辑是移出组则重置
            });
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) =>
                  bottomTitles(value, meta, weekData, Theme.of(context)),
              reservedSize: 38,
            ),
          ),
          leftTitles: AxisTitles(
            // Show left titles for reference
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval:
                  (maxY / 4).clamp(1.0, maxY), // Calculate interval dynamically
              getTitlesWidget: leftTitles,
            ),
          ),
        ),
        borderData: FlBorderData(
          // Add subtle border
          show: true,
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
            left: const BorderSide(color: Colors.transparent),
            right: const BorderSide(color: Colors.transparent),
            top: const BorderSide(color: Colors.transparent),
          ),
        ),
        barGroups: showingBarGroups,
        gridData: FlGridData(
          // Show horizontal grid lines
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval:
              (maxY / 4).clamp(1.0, maxY), // Same interval as left titles
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context)
                .dividerColor
                .withOpacity(0.5), // Subtle grid lines
            strokeWidth: 0.5,
            dashArray: [3, 3],
          ),
        ),
      ),
    );
  }

  // Left axis titles
  Widget leftTitles(double value, TitleMeta meta) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );
    String text = value.toInt().toString();
    // Show only intervals, not every value if too dense
    if (value % meta.appliedInterval != 0 && value != 0 && value != maxY) {
      return Container();
    }
    if (value == 0) {
      // Don't show 0 at the bottom if grid starts there
      return Container();
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4, // Space between axis and title
      child: Text(text, style: style),
    );
  }

  // Bottom axis titles (Weekdays)
  Widget bottomTitles(double value, TitleMeta meta,
      List<StatsChartDataPoint> weekData, ThemeData theme) {
    final style = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
      fontSize: 11,
    );
    Widget text;
    final int index = value.toInt();
    if (index < 0 || index >= weekData.length) return Container();

    final date = weekData[index].date;
    final today = DateTime.now().dateOnly;

    if (date == today) {
      text = Text('今',
          style: style.copyWith(
              color: theme.colorScheme.primary)); // Highlight Today
    } else {
      text = Text(DateFormat('E', 'zh_CN').format(date),
          style: style); // Use 'E' for short weekday
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 16, //margin top
      child: text,
    );
  }

  // Creates BarChartGroupData for a specific day
  BarChartGroupData makeGroupData(int x, double y1, double y2,
      {bool isTouched = false}) {
    final Color currentLeftColor = isTouched ? avgColor : leftBarColor;
    final Color currentRightColor = isTouched ? avgColor : rightBarColor;

    return BarChartGroupData(
      barsSpace: 4,
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: currentLeftColor,
          width: width,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4)), // Rounded top corners
          borderSide: isTouched // Add border on touch if needed
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 1)
              : const BorderSide(color: Colors.transparent, width: 0),
        ),
        BarChartRodData(
          toY: y2,
          color: currentRightColor,
          width: width,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          borderSide: isTouched
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 1)
              : const BorderSide(color: Colors.transparent, width: 0),
        ),
      ],
    );
  }
}

// endregion

// region Duration Chart (LineChart based on LineChartSample2)
class DurationLineChart extends StatefulWidget {
  const DurationLineChart({super.key});

  @override
  State<DurationLineChart> createState() => _DurationLineChartState();
}

class _DurationLineChartState extends State<DurationLineChart> {
  late List<Color> gradientColors; // Defined in initState based on theme
  late List<StatsChartDataPoint> weekData; // Store fetched data
  double maxY = 15; // Default max Y, will be calculated

  // We don't need the avg toggle for duration chart
  // bool showAvg = false;

  @override
  void initState() {
    super.initState();
    // _loadChartData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadChartData(); // Reload on theme change
  }

  void _loadChartData() {
    final statsProvider = context.read<StatsProvider>();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Set gradient colors based on theme (using duration bar colors)
    gradientColors = isDarkMode
        ? [
            statsDurationBarTodayColorDark.withOpacity(0.8),
            statsDurationBarOtherColorDark
          ]
        : [
            statsDurationBarTodayColorLight.withOpacity(0.8),
            statsDurationBarOtherColorLight
          ];

    // Fetch data for the last 7 days
    final data = statsProvider.durationChartData;
    final now = DateTime.now().dateOnly;
    weekData = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return data.firstWhere((p) => p.date == date,
          orElse: () => StatsChartDataPoint(date, 0));
    });

    if (weekData.isEmpty) {
      maxY = 15; // Reset to default if empty
      if (mounted) {
        setState(() {});
      }
      return;
    }

    // Calculate maxY for duration (in minutes)
    double tempMaxY = 0;
    for (var p in weekData) {
      tempMaxY = max(tempMaxY, p.value1);
    }
    maxY = (tempMaxY < 10)
        ? 15
        : (tempMaxY * 1.2).ceilToDouble(); // Ensure at least 15 min range

    if (mounted) {
      setState(() {});
    }
  }

  // Helper to format duration
  String _formatDuration(Duration d) {
    if (d.inMinutes <= 0) return "<1m";
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return "${hours}h${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  // Check if data is effectively empty
  bool _isEffectivelyEmpty(List<StatsChartDataPoint> data) {
    if (data.isEmpty) return true;
    return data
        .every((p) => p.value1 <= 0.1); // Check if all durations are near zero
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off_outlined,
              size: 48, color: Colors.grey), // Timer off icon
          const SizedBox(height: 12),
          Text("暂无学习时长记录", style: subtitleStyle),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check for empty state in build as well
    final statsProvider =
        context.watch<StatsProvider>(); // Watch for loading state
    if (_isEffectivelyEmpty(weekData) && !statsProvider.isLoading) {
      return _buildEmptyState(context);
    }
    // Update colors based on current theme in build
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    gradientColors = isDarkMode
        ? [
            statsDurationBarTodayColorDark.withOpacity(0.8),
            statsDurationBarOtherColorDark
          ]
        : [
            statsDurationBarTodayColorLight.withOpacity(0.8),
            statsDurationBarOtherColorLight
          ];

    return Stack(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.70, // Keep aspect ratio from example
          child: Padding(
            padding: const EdgeInsets.only(
              right: 18,
              left: 12,
              top: 24,
              bottom: 12,
            ),
            child: LineChart(
              // We only need the mainData, remove the avg toggle logic
              mainData(),
            ),
          ),
        ),
        // Removed the 'avg' toggle button
      ],
    );
  }

  // Bottom titles (Weekdays)
  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    final theme = Theme.of(context);
    final style = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
      fontSize: 11,
    );
    Widget text;
    final int index = value.toInt();
    if (index < 0 || index >= weekData.length) return Container();

    final date = weekData[index].date;
    final today = DateTime.now().dateOnly;

    if (date == today) {
      text = Text('今', style: style.copyWith(color: theme.colorScheme.primary));
    } else {
      text = Text(DateFormat('E', 'zh_CN').format(date), style: style);
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8, // Add space below title
      child: text,
    );
  }

  // Left titles (Duration in Minutes)
  Widget leftTitleWidgets(double value, TitleMeta meta) {
    final theme = Theme.of(context);
    final style = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );
    // Show titles only at intervals
    if (value % meta.appliedInterval != 0 && value != 0 && value != maxY) {
      return Container();
    }
    if (value == 0) {
      // Don't show 0 if axis starts at 0
      return Container();
    }

    String text = '${value.toInt()}m'; // Display as minutes

    return Text(text, style: style, textAlign: TextAlign.left);
  }

  // Main chart data generation
  LineChartData mainData() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color gridLineColor =
        isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final Color borderColor =
        isDarkMode ? Colors.grey[700]! : Colors.grey[400]!;
    final Color tooltipBgColor = isDarkMode
        ? Colors.grey[850]!.withAlpha((255 * 0.9).round())
        : Colors.white.withAlpha((255 * 0.9).round());
    final Color tooltipTextColor = isDarkMode ? Colors.white70 : Colors.black87;

    // Create spots from weekData
    final List<FlSpot> spots = weekData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value1);
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false, // Hide vertical lines
        drawHorizontalLine: true,
        horizontalInterval:
            (maxY / 4).clamp(5.0, maxY), // Interval based on max Y
        getDrawingHorizontalLine: (value) {
          return FlLine(
              color: gridLineColor,
              strokeWidth: 0.5,
              dashArray: [3, 3] // Dashed lines
              );
        },
        // getDrawingVerticalLine: (value) { // Not needed if drawVerticalLine is false
        //   return FlLine(
        //     color: gridLineColor,
        //     strokeWidth: 0.5,
        //   );
        // },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: (maxY / 4).clamp(5.0, maxY), // Match grid interval
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42, // Adjust space for labels like "60m"
          ),
        ),
      ),
      borderData: FlBorderData(
          // Add subtle bottom border
          show: true,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1),
            left: const BorderSide(color: Colors.transparent),
            right: const BorderSide(color: Colors.transparent),
            top: const BorderSide(color: Colors.transparent),
          )),
      minX: 0,
      maxX: 6, // 7 days (0 to 6)
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
            spots: spots, // Use generated spots
            isCurved: true,
            gradient: LinearGradient(
              // Use defined gradient colors
              colors: gradientColors,
              begin: Alignment.topCenter, // Adjust gradient direction
              end: Alignment.bottomCenter,
            ),
            barWidth: 4, // Slightly thicker line
            isStrokeCapRound: true,
            dotData: const FlDotData(
              // Hide dots by default
              show: false,
            ),
            belowBarData: BarAreaData(
              // Fill area below line
              show: true,
              gradient: LinearGradient(
                colors: gradientColors
                    .map((color) => color.withOpacity(0.2)) // Use transparency
                    .toList(),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            shadow: Shadow(
              // Add subtle shadow
              color: gradientColors.last.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )),
      ],
      lineTouchData: LineTouchData(
        // Customize touch interaction
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: tooltipBgColor,
          tooltipRoundedRadius: 8,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              final flSpot = touchedSpot;
              if (flSpot.spotIndex < 0 || flSpot.spotIndex >= weekData.length)
                return null;

              final dataPoint = weekData[flSpot.spotIndex];
              final dateStr = DateFormat('MM-dd').format(dataPoint.date);
              final duration = Duration(
                  minutes: flSpot.y.round()); // Round y value to get minutes
              final durationStr = _formatDuration(duration);

              return LineTooltipItem(
                  '$dateStr\n',
                  TextStyle(
                      color: tooltipTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                  children: [
                    TextSpan(
                      text: durationStr,
                      style: TextStyle(
                          color: gradientColors
                              .last, // Use a color from the gradient
                          fontWeight: FontWeight.w900,
                          fontSize: 11),
                    ),
                  ],
                  textAlign: TextAlign.center);
            }).toList();
          },
        ),
      ),
    );
  }

  // Removed avgData() as it's not needed for the duration chart
}
// endregion

// Page Widget (Stateless) - Remains the same
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StatsPageContent();
  }
}

// Page Content StatefulWidget - Remains mostly the same
class _StatsPageContent extends StatefulWidget {
  const _StatsPageContent();

  @override
  State<_StatsPageContent> createState() => _StatsPageContentState();
}

// Page Content State (Handles logic, animations, RouteAware)
class _StatsPageContentState extends State<_StatsPageContent>
    with TickerProviderStateMixin, RouteAware {
  // Stagger animation remains useful for card entry
  late AnimationController _staggerController;
  final List<Animation<double>> _fadeAnimations = [];
  final int _numCards = 3; // Overview, Words, Duration

  @override
  void initState() {
    super.initState();

    // 1. Init Stagger Animation
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200 * _numCards + 100),
    );
    for (int i = 0; i < _numCards; i++) {
      final start = (i * 150) / _staggerController.duration!.inMilliseconds;
      final end = start + (300 / _staggerController.duration!.inMilliseconds);
      _fadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
                curve: Curves.easeOut),
          ),
        ),
      );
    }

    // 3. Post Frame Callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staggerController.forward();
    });
  }

  // --- RouteAware Lifecycle ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      // 订阅路由监听器
      routeObserver.subscribe(this, route);
      if (kDebugMode) print("[StatsPage] Subscribed to RouteObserver.");
    }
  }

  @override
  void dispose() {
    // 取消订阅
    routeObserver.unsubscribe(this);
    if (kDebugMode) print("[StatsPage] Unsubscribed from RouteObserver.");
    _staggerController.dispose();
    // 确保释放所有控制器
    super.dispose();
  }

  // 当页面首次或通过 pushNamed 进入时调用
  @override
  void didPush() {
    super.didPush();
    if (kDebugMode)
      print(
          "[StatsPage] didPush: Page became visible. Triggering data refresh...");
    // 确保在 build 完成后再加载
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadData());
  }

  // 处理返回进入
  @override
  void didPopNext() {
    super.didPopNext();
    if (kDebugMode)
      print(
          "[StatsPage] didPopNext: Returned to page. Triggering data refresh...");
    _reloadData(); // 调用统一的加载方法
    // 返回时重置并播放卡片动画
    _staggerController.reset();
    _staggerController.forward();
  }

  // 统一的重新加载数据方法
  void _reloadData() {
    // 确保 widget 仍然挂载
    if (!mounted) {
      if (kDebugMode)
        print("[StatsPage][_reloadData] Widget not mounted, skipping load.");
      return;
    }
    try {
      final statsProvider = context.read<StatsProvider>();
      // 检查必要的依赖是否存在
      if (statsProvider.currentUserIdInternal != null &&
          statsProvider.currentBookIdInternal != null &&
          statsProvider.currentUserDataStatusInternal == UserDataStatus.ready) {
        if (kDebugMode)
          print(
              "[StatsPage] _reloadData: Dependencies seem ready, calling loadStatsData.");
        // 直接调用加载，让 Provider 内部处理 isLoading 状态
        statsProvider.loadStatsData();
      } else {
        if (kDebugMode)
          print(
              "[StatsPage] _reloadData: Dependencies not ready (User: ${statsProvider.currentUserIdInternal}, Book: ${statsProvider.currentBookIdInternal}, Status: ${statsProvider.currentUserDataStatusInternal}), skipping load.");
      }
    } catch (e) {
      // Provider 可能尚未准备好
      if (kDebugMode)
        print(
            "[StatsPage][_reloadData] Error accessing provider or loading data: $e");
    }
  }

  // --- End RouteAware ---

  // --- Helper Functions ---
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else if (minutes >= 1) {
      return "${minutes}m";
    } else {
      return "<1m";
    }
  }

  Widget _buildAnimatedCard(
      {required Animation<double> animation, required Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print("[StatsPage] Build method running.");
    final statsProvider = context.watch<StatsProvider>();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Use Material 3 elevation overlay for card background
    final Color cardBackgroundColor = ElevationOverlay.applySurfaceTint(
        theme.colorScheme.surface, theme.colorScheme.surfaceTint, 2);
    final Color cardTitleColor = theme.colorScheme.onSurfaceVariant;
    final Color primaryTextColor = theme.colorScheme.onSurface;
    final Color secondaryTextColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("学习数据"), // Static title
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        color: theme.colorScheme.surface, // Page background color
        // Add RefreshIndicator
        child: RefreshIndicator(
          onRefresh: () async {
            if (kDebugMode) print("[StatsPage] Pull to refresh triggered.");
            // Call Provider to load data and wait for completion
            await statsProvider.loadStatsData();
            // Optionally reset card animation for visual feedback
            _staggerController.reset();
            _staggerController.forward();
          },
          // The main content is the child of RefreshIndicator
          child: _buildBodyContent(
              // Pass necessary parameters
              statsProvider,
              theme,
              isDarkMode,
              cardBackgroundColor,
              cardTitleColor,
              primaryTextColor,
              secondaryTextColor),
        ),
      ),
    );
  }

  // Build page body content
  Widget _buildBodyContent(
      StatsProvider statsProvider,
      ThemeData theme,
      bool isDarkMode,
      Color cardBg,
      Color cardTitleColor,
      Color primaryTextColor,
      Color secondaryTextColor) {
    // --- Loading and Error Handling ---
    // Show loading only on initial load
    if (statsProvider.isLoading && !statsProvider.isDataLoadedOnce) {
      if (kDebugMode)
        print("[StatsPage][Body] Showing initial loading indicator.");
      return const Center(child: CircularProgressIndicator());
    }
    // Show error only if data has never loaded successfully
    if (statsProvider.error != null && !statsProvider.isDataLoadedOnce) {
      if (kDebugMode)
        print(
            "[StatsPage][Body] Showing initial error screen: ${statsProvider.error}");
      return Center(
          child:
              Text("加载数据时出错: ${statsProvider.error}")); // Simple error display
    }
    // If no book is selected after loading attempt
    if (statsProvider.selectedBookId == null && !statsProvider.isLoading) {
      if (kDebugMode) print("[StatsPage][Body] No book selected.");
      return const Center(child: Text("请先在菜单中选择一个词库"));
    }

    // --- Main Content ListView ---
    return ListView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: kToolbarHeight + MediaQuery.of(context).padding.top + 10,
        bottom: 24,
      ),
      physics:
          const AlwaysScrollableScrollPhysics(), // Ensure scrollable even with few items for RefreshIndicator
      children: [
        // --- Overview Card ---
        _buildAnimatedCard(
          animation: _fadeAnimations[0],
          child: _buildOverviewCard(context, statsProvider, theme, cardBg,
              primaryTextColor, secondaryTextColor),
        ),
        const SizedBox(height: 20),

        // --- Word Count Chart Card ---
        _buildAnimatedCard(
          animation: _fadeAnimations[1],
          child: _buildChartCard(
              context: context,
              title: "单词学习量 (近7天)",
              icon: Icons.bar_chart_rounded, // Use Bar chart icon now
              cardBackgroundColor: cardBg,
              titleColor: cardTitleColor,
              chart:
                  const WordCountBarChart() // *** Use the new Bar Chart widget ***
              ),
        ),
        const SizedBox(height: 20),

        // --- Duration Chart Card ---
        _buildAnimatedCard(
          animation: _fadeAnimations[2],
          child: _buildChartCard(
              context: context,
              title: "学习时长 (近7天)",
              icon: Icons.timeline_rounded, // Use Line chart icon now
              cardBackgroundColor: cardBg,
              titleColor: cardTitleColor,
              chart:
                  const DurationLineChart() // *** Use the new Line Chart widget ***
              ),
        ),
      ],
    );
  }

  // Builds the overview card - unchanged
  Widget _buildOverviewCard(
      BuildContext context,
      StatsProvider stats,
      ThemeData theme,
      Color bgColor,
      Color textColor,
      Color secondaryTextColor) {
    final overview = stats.overviewData;
    final double progress = (overview.totalCount > 0)
        ? (overview.learnedCount / overview.totalCount).clamp(0.0, 1.0)
        : 0.0;
    final String progressPercent = (progress * 100).toStringAsFixed(0);

    return Card(
      elevation: elevationLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Current Vocab Progress ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style:
                        theme.textTheme.bodyMedium?.copyWith(color: textColor),
                    children: <TextSpan>[
                      const TextSpan(text: '当前词库已学 '),
                      TextSpan(
                          text: '${overview.learnedCount}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: ' / ${overview.totalCount} 词'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  backgroundColor:
                      theme.colorScheme.primary.withAlpha((255 * 0.2).round()),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "$progressPercent%",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: secondaryTextColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // --- Today & Total Stats ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                    child: _buildOverviewItem(
                        context,
                        Icons.lightbulb_outline_rounded,
                        overview.learnedToday.toString(),
                        "今日学习",
                        textColor,
                        secondaryTextColor)),
                Expanded(
                    child: _buildOverviewItem(
                        context,
                        Icons.history_rounded,
                        overview.reviewedToday.toString(),
                        "今日复习",
                        textColor,
                        secondaryTextColor)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                    child: _buildOverviewItem(
                        context,
                        Icons.timer_outlined,
                        _formatDuration(overview.timeToday),
                        "今日时长",
                        textColor,
                        secondaryTextColor)),
                Expanded(
                    child: _buildOverviewItem(
                        context,
                        Icons.functions_rounded,
                        _formatDuration(overview.timeTotal),
                        "累计时长",
                        textColor,
                        secondaryTextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Builds a single item for the overview card
  Widget _buildOverviewItem(BuildContext context, IconData icon, String value,
      String label, Color valueColor, Color labelColor) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: valueColor.withAlpha((255 * 0.8).round())),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: valueColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: labelColor)),
      ],
    );
  }

  // Build the generic chart card structure (Modified to include legend for word chart)
  Widget _buildChartCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget chart,
    required Color cardBackgroundColor,
    required Color titleColor,
  }) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: titleColor,
    );

    // Determine if this is the word count chart to show legend
    final bool isWordChart = chart is WordCountBarChart;

    return Card(
      elevation: elevationLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(icon, size: 18, color: titleStyle?.color),
                const SizedBox(width: 8),
                Text(title, style: titleStyle),
                const Spacer(),
                // Add Legend only for word chart
                if (isWordChart)
                  _buildWordChartLegend(
                      context, theme.brightness == Brightness.dark),
              ],
            ),
            const SizedBox(height: 16),
            // Chart container
            SizedBox(
                height: 220, // Adjust height as needed
                child: chart),
          ],
        ),
      ),
    );
  }

  // Build legend specifically for the word chart
  Widget _buildWordChartLegend(BuildContext context, bool isDarkMode) {
    final textStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11);
    // Use the actual colors being used by the chart
    final learnColor =
        isDarkMode ? statsLearnCurveColorDark : statsLearnCurveColorLight;
    final reviewColor =
        isDarkMode ? statsReviewCurveColorDark : statsReviewCurveColorLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem(learnColor, "学习", textStyle),
        const SizedBox(width: 10),
        _buildLegendItem(reviewColor, "复习", textStyle),
      ],
    );
  }

  // Build a single legend item
  Widget _buildLegendItem(Color color, String text, TextStyle? style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
  }
} // End of _StatsPageContentState

// DateTime Extension (keep as it's used)
extension DateTimeDateOnly on DateTime {
  DateTime get dateOnly => DateTime.utc(year, month, day);
}
