import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- 添加这一行
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/services/api_service.dart';
// import 'package:lexilearn/widgets/app_theme.dart'; // --- 移除 ---
import 'package:lexilearn/widgets/error_feedback.dart';

// ... (StatefulWidget and State class definition remains the same) ...
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ApiService _apiService = ApiService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _codeSent = false;
  bool _isSendingCode = false;
  bool _isVerifying = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    FocusScope.of(context).unfocus();

    // --- 简化验证逻辑 ---
    // 先只检查Email格式是否基本正确
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      // 直接提示错误，不依赖formKey.validate()，因为它会验证所有字段
      ErrorFeedback.showErrorSnackbar(context, "请输入有效的邮箱地址");
      return;
    }
    // --- End 简化 ---

    setState(() => _isSendingCode = true);

    final result = await _apiService.register(email); // 使用trim后的email

    if (mounted) {
      if (result['success']) {
        setState(() => _codeSent = true);
        ErrorFeedback.showSuccessSnackbar(
            context, result['message'] ?? '验证码已发送');
      } else {
        ErrorFeedback.showErrorSnackbar(context, result['error'] ?? '发送验证码失败');
      }
      setState(() => _isSendingCode = false);
    }
  }

  Future<void> _handleVerifyAndRegister() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isVerifying = true);

      final result = await _apiService.verify(
        _emailController.text.trim(),
        _codeController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (result['success']) {
          ErrorFeedback.showSuccessSnackbar(
              context, result['message'] ?? '注册成功！请登录。');
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        } else {
          ErrorFeedback.showErrorSnackbar(
              context, result['error'] ?? '注册失败，请检查验证码或密码');
        }
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isLoading = _isSendingCode || _isVerifying;

    return Scaffold(
      appBar: AppBar(
        title: const Text('注册 LexiLearn'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: elevationLow,
              shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '创建您的账号',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 24),

                      // --- Email Field ---
                      TextFormField(
                        controller: _emailController,
                        // ... (validator and keyboardType same) ...
                        decoration: InputDecoration(
                            labelText: '邮箱',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: const OutlineInputBorder(),
                            // Send code button integrated as suffix
                            suffixIcon: Padding(
                              // Add padding for better spacing
                              padding: const EdgeInsets.only(right: 8.0),
                              child: TextButton(
                                onPressed: isLoading || _codeSent
                                    ? null
                                    : _handleSendCode, // Disable if loading or already sent
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero),
                                child: _isSendingCode
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Text(_codeSent
                                        ? '已发送'
                                        : '发送验证码'), // Change text after sent
                              ),
                            )),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入邮箱';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return '请输入有效的邮箱地址';
                          }
                          return null;
                        },
                        readOnly:
                            _codeSent, // Disable email editing after code sent
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: 16),

                      // --- Code Field (Conditional) ---
                      if (_codeSent)
                        TextFormField(
                          controller: _codeController,
                          // ... (decoration, keyboardType same) ...
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            prefixIcon: Icon(Icons.pin_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ], // Only allow digits
                          validator: (value) {
                            if (!_codeSent) {
                              return null;
                            } // Only validate if shown
                            if (value == null || value.isEmpty) {
                              return '请输入验证码';
                            }
                            if (value.length != 6) {
                              return '验证码应为6位数字';
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                      if (_codeSent) const SizedBox(height: 16),

                      // --- Password Field (Conditional) ---
                      if (_codeSent)
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          // ... (decoration, suffixIcon same) ...
                          decoration: InputDecoration(
                              labelText: '设置密码 (至少6位)',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              )),
                          validator: (value) {
                            if (!_codeSent) {
                              return null;
                            }
                            if (value == null || value.isEmpty) {
                              return '请输入密码';
                            }
                            if (value.length < 6) {
                              return '密码长度至少为6位';
                            }
                            // Check confirm password match only if confirm field has text
                            if (_confirmPasswordController.text.isNotEmpty &&
                                value != _confirmPasswordController.text) {
                              return '两次输入的密码不一致';
                            }
                            return null;
                          },
                          enabled: !isLoading,
                          // Re-validate confirm password when this field changes
                          onChanged: (_) => _formKey.currentState?.validate(),
                        ),
                      if (_codeSent) const SizedBox(height: 16),

                      // --- Confirm Password Field (Conditional) ---
                      if (_codeSent)
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          // ... (decoration, suffixIcon same) ...
                          decoration: InputDecoration(
                              labelText: '确认密码',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              )),
                          validator: (value) {
                            if (!_codeSent) {
                              return null;
                            }
                            if (value == null || value.isEmpty) {
                              return '请再次输入密码';
                            }
                            if (value != _passwordController.text) {
                              return '两次输入的密码不一致';
                            }
                            return null;
                          },
                          enabled: !isLoading,
                          // Re-validate password when this field changes
                          onChanged: (_) => _formKey.currentState?.validate(),
                        ),
                      if (_codeSent) const SizedBox(height: 24),

                      // --- Register Button (Conditional) ---
                      if (_codeSent)
                        ElevatedButton(
                          onPressed:
                              isLoading ? null : _handleVerifyAndRegister,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('完成注册'),
                        ),

                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (Navigator.canPop(context)) {
                                  // --- 添加花括号 ---
                                  Navigator.pop(context);
                                } else {
                                  Navigator.pushReplacementNamed(
                                      context, '/login');
                                }
                              },
                        child: const Text('已有账号？返回登录'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
