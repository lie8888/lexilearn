import 'package:flutter/material.dart';
import 'package:lexilearn/constants.dart'; // 确保常量文件路径正确

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    // --- 使用 ColorScheme.fromSeed 生成颜色方案 ---
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor, // 主要种子颜色
      secondary: secondaryColor, // 可以指定次要颜色
      tertiary: tertiaryColor, // 可以指定三次颜色
      error: errorColor, // 错误颜色
      brightness: Brightness.light, // 明确亮度
    ),
    // --- 移除 colorSchemeSeed 和 primaryColor ---
    // colorSchemeSeed: primaryColor, // 移除
    // primaryColor: primaryColor,    // 移除 (会从 colorScheme 获取)

    cardTheme: CardTheme(
      elevation: elevationLow,
      shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: elevationLow,
        // M3 按钮颜色默认会从 colorScheme 派生，通常不需要手动设置
        // backgroundColor: primaryColor, // 可以移除，除非需要强制覆盖
        // foregroundColor: Colors.white, // 可以移除
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: globalBorderRadius),
      focusedBorder: OutlineInputBorder(
        borderRadius: globalBorderRadius,
        // M3 focused border 默认使用 colorScheme.primary
        // borderSide: const BorderSide(color: primaryColor, width: 2), // 可以移除
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0, // Common M3 style
      // M3 AppBar 颜色通常来自 colorScheme.surface or background
      // backgroundColor: Colors.transparent, // 设置为 transparent 可能导致内容与 AppBar 重叠
      // foregroundColor: Colors.black, // 会根据亮度自动调整
      // 推荐让 ThemeData 自动处理 AppBar 颜色
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    // --- 使用 ColorScheme.fromSeed 生成颜色方案 ---
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor, // 可以在暗色模式下微调
      tertiary: tertiaryColor,
      error: errorColor, // 可以在暗色模式下微调
      brightness: Brightness.dark, // 明确亮度
    ),
    // --- 移除 colorSchemeSeed 和 primaryColor ---
    // colorSchemeSeed: primaryColor, // 移除
    // primaryColor: primaryColor,    // 移除

    cardTheme: CardTheme(
      elevation: elevationLow,
      shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: elevationLow,
        // M3 颜色会自动适应暗色模式
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: globalBorderRadius),
      focusedBorder: OutlineInputBorder(
        borderRadius: globalBorderRadius,
        // borderSide: const BorderSide(color: primaryColor, width: 2), // M3 uses primary in dark too
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      // backgroundColor: Colors.transparent, // 移除以使用默认颜色
      // foregroundColor: Colors.white, // 会自动调整
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
