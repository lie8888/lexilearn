import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexilearn/constants.dart'; // 确保这里导入了更新后的 constants.dart

class ApiService {
  // ... (其他方法 _getToken, _getHeaders, _handleResponse, login, register, verify, getVocabList, getVocabDownloadInfo 保持不变) ...
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: SECURE_STORAGE_TOKEN_KEY);
  }

  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (requiresAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        if (kDebugMode) {
          print("[ApiService] Warning: Auth required but no token found.");
        }
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final statusCode = response.statusCode;
    Map<String, dynamic> body;
    try {
      if (response.body.isEmpty && (statusCode >= 200 && statusCode < 300)) {
        return {'success': true, 'statusCode': statusCode};
      }
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      if (kDebugMode) {
        print("[ApiService] Error decoding response body: $e");
        print("[ApiService] Response Body: ${response.body}");
      }
      return {
        'success': false,
        'error': '无法解析服务器响应',
        'statusCode': statusCode,
        'rawBody': response.body
      };
    }

    if (statusCode >= 200 && statusCode < 300) {
      return {'success': true, ...body, 'statusCode': statusCode};
    } else {
      if (kDebugMode) {
        print(
            "[ApiService] API Error ($statusCode): ${body['error'] ?? response.reasonPhrase}");
      }
      return {
        'success': false,
        'error': body['error'] ?? '请求失败 ($statusCode)',
        'statusCode': statusCode,
      };
    }
  }

  // --- User Endpoints ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/user/login'),
        headers: await _getHeaders(requiresAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print("[ApiService] Network Error (Login): $e");
      return {'success': false, 'error': '网络错误，请稍后重试'};
    }
  }

  Future<Map<String, dynamic>> register(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/user/register'),
        headers: await _getHeaders(requiresAuth: false),
        body: jsonEncode({'email': email}),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print("[ApiService] Network Error (Register): $e");
      return {'success': false, 'error': '网络错误，请稍后重试'};
    }
  }

  Future<Map<String, dynamic>> verify(
      String email, String code, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/user/verify'),
        headers: await _getHeaders(requiresAuth: false),
        body: jsonEncode({'email': email, 'code': code, 'password': password}),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print("[ApiService] Network Error (Verify): $e");
      return {'success': false, 'error': '网络错误，请稍后重试'};
    }
  }

  // --- Vocab Endpoints ---
  Future<Map<String, dynamic>> getVocabList() async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/vocab'),
        headers: await _getHeaders(requiresAuth: false),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
          return {
            'success': true,
            'data': list,
            'statusCode': response.statusCode
          };
        } catch (e) {
          if (kDebugMode) print("[ApiService] Error parsing vocab list: $e");
          return {
            'success': false,
            'error': '无法解析词库列表',
            'statusCode': response.statusCode
          };
        }
      } else {
        Map<String, dynamic> errorBody = {};
        try {
          errorBody = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
        if (kDebugMode)
          print(
              "[ApiService] Failed to get vocab list (${response.statusCode}): ${errorBody['error'] ?? response.reasonPhrase}");
        return {
          'success': false,
          'error': errorBody['error'] ?? '获取词库列表失败 (${response.statusCode})',
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      if (kDebugMode) print("[ApiService] Network Error (getVocabList): $e");
      return {'success': false, 'error': '网络错误，请稍后重试'};
    }
  }

  Future<Map<String, dynamic>> getVocabDownloadInfo(int vocabId) async {
    try {
      // 这个请求使用 API_BASE_URL，应该已经是 10.0.2.2:3000
      final response = await http.get(
        Uri.parse('$API_BASE_URL/vocab/$vocabId'),
        headers: await _getHeaders(requiresAuth: false),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode)
        print("[ApiService] Network Error (getVocabDownloadInfo): $e");
      return {'success': false, 'error': '网络错误，请稍后重试'};
    }
  }

  // --- downloadJsonlFile ---
  // 确保这个方法使用更新后的 API_BASE_URL (即 10.0.2.2:3000) 来拼接相对路径
  Future<({bool success, String? data, String? error})> downloadJsonlFile(
      String url) async {
    Uri uri;
    try {
      if (kDebugMode) {
        print("[ApiService] Received URL for download: $url");
      }
      // 检查 URL 是否已经是绝对路径 (可能包含错误的 localhost)
      if (url.startsWith('http://') || url.startsWith('https://')) {
        // *** 关键检查：如果URL包含localhost，但我们在模拟器环境，则替换它 ***
        if (url.contains('//localhost') &&
            API_BASE_URL.contains('//10.0.2.2')) {
          final correctedUrl = url.replaceFirst('//localhost', '//10.0.2.2');
          uri = Uri.parse(correctedUrl);
          if (kDebugMode)
            print("[ApiService] Corrected localhost URL to: $uri");
        } else {
          uri = Uri.parse(url); // 已经是绝对路径，直接使用 (或后端返回了正确的IP)
        }
      }
      // 检查 URL 是否是相对路径 (以 / 开头)
      else if (url.startsWith('/')) {
        // 从 API_BASE_URL (现在是 10.0.2.2) 中移除可能存在的尾部斜杠
        final baseUrl = API_BASE_URL.endsWith('/')
            ? API_BASE_URL.substring(0, API_BASE_URL.length - 1)
            : API_BASE_URL;
        final relativePath = url.startsWith('/') ? url.substring(1) : url;
        uri = Uri.parse('$baseUrl/$relativePath'); // 拼接基础 URL
      }
      // 假设是相对于 API_BASE_URL 的路径 (不以 / 开头)
      else {
        final baseUrl = API_BASE_URL.endsWith('/')
            ? API_BASE_URL.substring(0, API_BASE_URL.length - 1)
            : API_BASE_URL;
        uri = Uri.parse('$baseUrl/$url'); // 拼接基础 URL
      }

      if (kDebugMode) {
        print("[ApiService] Attempting to download from constructed URI: $uri");
      }
    } catch (e) {
      if (kDebugMode)
        print("[ApiService] Error parsing download URL '$url': $e");
      return (success: false, data: null, error: '无效的下载链接格式: $url');
    }

    // ...(后面的 try-catch 下载逻辑保持不变) ...
    try {
      final response = await http
          .get(
            uri,
          )
          .timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print(
            "[ApiService] Download response status code: ${response.statusCode} for $uri");
      }

      if (response.statusCode == 200) {
        return (
          success: true,
          data: utf8.decode(response.bodyBytes),
          error: null
        );
      } else {
        String errorMessage = '下载文件失败 (${response.statusCode})';
        if (response.reasonPhrase != null &&
            response.reasonPhrase!.isNotEmpty) {
          errorMessage += ' - ${response.reasonPhrase}';
        }
        return (success: false, data: null, error: errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "[ApiService] Network/Timeout Error during download from $uri: $e");
      }
      return (success: false, data: null, error: '网络错误或超时，无法下载文件: $e');
    }
  } // <-- downloadJsonlFile 方法结束
} // <-- ApiService 类结束

// 辅助函数
int min(int a, int b) => a < b ? a : b;
