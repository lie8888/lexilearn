// frontend/lib/constants.dart

import 'package:flutter/material.dart';

// --- Material 3 Colors (基础配色，保持不变) ---
const Color primaryColor = Color(0xFFA5D6A7); // 整体主色调可能仍有用
const Color secondaryColor = Color(0xFFD7CCC8);
const Color tertiaryColor = Color(0xFF81C784);
const Color errorColor = Color(0xFFB00020);
const Color primaryContainerColor = Color(0xFFC8E6C9);
const Color onPrimaryContainerColor = Color(0xFF1B5E20);
const Color surfaceColor = Colors.white; // 亮色模式表面色
const Color onSurfaceColor = Colors.black87; // 亮色模式表面上的文字/图标颜色
const Color onSurfaceVariantColor = Colors.black54; // 亮色模式表面上的次要文字/图标颜色
const Color outlineColor = Colors.black26; // 亮色模式轮廓颜色

// --- Stats Page Specific Colors (根据 UI 规范新增) ---
// 单词学习量图表 (折线图)
const Color statsLearnCurveColorLight = Color(0xFF4285F4); // 谷歌蓝 (亮色)
const Color statsLearnCurveColorDark = Color(0xFF8AB4F8); // 谷歌蓝 (暗色)
const Color statsReviewCurveColorLight = Color(0xFFFB8C00); // 活力橙 (亮色)
const Color statsReviewCurveColorDark = Color(0xFFFFB74D); // 活力橙 (暗色)

// 学习时长图表 (柱状图)
const Color statsDurationBarTodayColorLight = Color(0xFF3367D6); // 深蓝 (亮色 - 当日)
const Color statsDurationBarTodayColorDark = Color(0xFF8AB4F8); // 适配暗色 (参考学习曲线)
const Color statsDurationBarOtherColorLight =
    Color(0xFF7BAAF7); // 浅蓝 (亮色 - 其他日期)
const Color statsDurationBarOtherColorDark =
    Color(0xFF5F84CC); // 适配暗色 (稍暗/饱和度稍低的蓝)

// 图表辅助线颜色 (直接在 StatsPage 中使用 Colors.grey[200/700]，因为它们是标准颜色)
// const Color statsGuideLineColorLight = Color(0xFFE0E0E0); // Colors.grey[300] perhaps? Spec says 200
// const Color statsGuideLineColorDark = Color(0xFF616161); // Colors.grey[700]

// 卡片标题颜色 (直接在 StatsPage 中使用 Colors.grey[700/300]，理由同上)
// const Color statsCardTitleColorLight = Color(0xFF616161); // Colors.grey[700]
// const Color statsCardTitleColorDark = Color(0xFFD6D6D6); // Colors.grey[300]

// --- API ---
// 使用 10.0.2.2 访问本地主机 (适用于 Android 模拟器)
// 如果使用 iOS 模拟器或真机，可能需要替换为电脑的局域网 IP 地址
const String API_BASE_URL = 'http://8.138.93.105:3000';

// --- Hive Box Names ---
const String HIVE_BOX_CONFIG = 'config'; // 存储全局配置，如累计时长
const String HIVE_BOX_VOCAB_PREFIX = 'vocab_'; // 词库数据 Box 前缀
const String HIVE_BOX_WRONG_WORDS = 'wrong'; // 错词本 Box
const String HIVE_BOX_PROGRESS = 'progress_v3'; // 单词学习进度 Box (保留 v3)
const String HIVE_BOX_PLAN = 'plan'; // 学习计划 Box
const String HIVE_BOX_DAILY_STATS = 'daily_stats'; // 每日学习统计 Box

// --- Hive Keys ---
// Plan Box Keys
const String HIVE_KEY_DAILY_LEARN_GOAL = 'dailyLearnGoal';
const String HIVE_KEY_DAILY_REVIEW_GOAL = 'dailyReviewGoal';

// Daily Stats Box Keys (Box 的 key 是 'YYYY-MM-DD', value 是 Map)
const String DAILY_STATS_KEY_LEARNED_COUNT = 'learned'; // 当日学习单词数
const String DAILY_STATS_KEY_REVIEWED_COUNT = 'reviewed'; // 当日复习单词数
const String DAILY_STATS_KEY_DURATION_MS = 'duration_ms'; // 当日学习总时长 (毫秒)
// 注意：未来可能需要按 bookId 存储每日统计，例如 value 变成 Map<String, Map>
// {'bookId1': {'learned': 10, 'reviewed': 5, 'duration_ms': 300000}, ...}

// Config Box Keys
const String CONFIG_KEY_TOTAL_DURATION_MS = 'total_duration_ms'; // App 累计学习总时长

// --- Secure Storage Keys ---
const String SECURE_STORAGE_TOKEN_KEY = 'jwt_token';
const String SECURE_STORAGE_USER_ID_KEY = 'user_id';
const String SECURE_STORAGE_EMAIL_KEY = 'user_email';
const String SECURE_STORAGE_SELECTED_BOOK_ID = 'selected_book_id'; // 当前选择的词库 ID

// --- UI Constants ---
final BorderRadius globalBorderRadius = BorderRadius.circular(16); // 全局圆角
const double elevationLow = 2.0; // 低海拔阴影 (M3 推荐更低的阴影值)
const double elevationMedium = 4.0; // 中海拔阴影
const double elevationHigh = 6.0; // 高海拔阴影

// --- Enums ---
// SessionType 和 SessionStatus 定义在 word_state_provider.dart
// StatsTimeRange 定义在 stats_provider.dart
// AuthStatus 定义在 auth_provider.dart
// VocabListStatus, VocabLoadStatus, VocabDownloadStatus 定义在 vocab_provider.dart
