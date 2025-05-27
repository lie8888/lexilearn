// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lexilearn/pages/home_page.dart';
import 'package:lexilearn/pages/learn_page.dart';
import 'package:lexilearn/pages/login_page.dart';
import 'package:lexilearn/pages/menu_page.dart';
import 'package:lexilearn/pages/plan_page.dart';
import 'package:lexilearn/pages/register_page.dart';
import 'package:lexilearn/pages/review_page.dart';
import 'package:lexilearn/pages/stats_page.dart';
import 'package:lexilearn/pages/vocab_select_page.dart';
import 'package:lexilearn/providers/auth_provider.dart';
import 'package:lexilearn/providers/plan_provider.dart';
import 'package:lexilearn/providers/vocab_provider.dart';
import 'package:lexilearn/providers/stats_provider.dart';
import 'package:lexilearn/services/hive_service.dart';
import 'package:lexilearn/widgets/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
// --- RouteObserver ---
// 创建一个全局的 RouteObserver 实例，用于监听路由变化
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  await initializeDateFormatting('zh_CN', null); // <-- 添加这行来初始化中文日期格式
  runApp(const LexiLearnApp());
}

class LexiLearnApp extends StatelessWidget {
  const LexiLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. AuthProvider
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // 2. PlanProvider (依赖 Auth)
        ChangeNotifierProxyProvider<AuthProvider, PlanProvider>(
          create: (_) => PlanProvider(),
          update: (_, auth, previousPlan) {
            final plan = previousPlan ?? PlanProvider();
            final currentUserId = auth.userId;
            final previousUserId = plan.currentUserId;
            final userDataStatus = auth.userDataStatus; // *** 获取用户数据状态 ***

            // --- 修改：仅当用户ID变化且用户数据准备就绪时加载/重置 ---
            if (currentUserId != previousUserId) {
              Future.microtask(() {
                if (currentUserId != null &&
                    userDataStatus == UserDataStatus.ready) {
                  if (kDebugMode) {
                    print(
                        "[ProxyProvider][Plan] Auth changed & data ready, loading plan for user $currentUserId");
                  }
                  plan.loadPlan(currentUserId);
                } else if (currentUserId == null) {
                  if (kDebugMode) {
                    print(
                        "[ProxyProvider][Plan] Auth changed (logout), resetting plan.");
                  }
                  plan.resetPlan();
                } else {
                  if (kDebugMode) {
                    print(
                        "[ProxyProvider][Plan] Auth changed, but data not ready ($userDataStatus). Waiting.");
                  }
                  // 可选：如果需要，在数据未就绪时也重置
                  // plan.resetPlan();
                }
              });
            }
            // --- 结束修改 ---
            return plan;
          },
        ),

        // 3. VocabProvider (依赖 Auth)
        ChangeNotifierProxyProvider<AuthProvider, VocabProvider>(
          create: (_) => VocabProvider(),
          update: (_, auth, previousVocab) {
            final vocab = previousVocab ?? VocabProvider();
            final currentUserId = auth.userId;
            final previousUserId = vocab.currentUserId;

            if (currentUserId != previousUserId) {
              // Update userId immediately for synchronous access
              vocab.updateUserId(currentUserId);
              // Schedule async operations
              Future.microtask(() async {
                if (currentUserId != null &&
                    auth.userDataStatus == UserDataStatus.ready) {
                  if (kDebugMode) {
                    print(
                        "[ProxyProvider][Vocab] Auth changed & data ready, loading vocab selection for user $currentUserId");
                  }
                  // Trigger loading of selected book ID from storage
                  await vocab.loadSelectedBookId(userId: currentUserId);
                  // Only fetch list if needed (e.g., not already loaded)
                  if (vocab.listStatus == VocabListStatus.initial ||
                      vocab.listStatus == VocabListStatus.error) {
                    await vocab.fetchVocabList();
                  }
                } else if (currentUserId == null) {
                  if (kDebugMode) {
                    print(
                        "[ProxyProvider][Vocab] Auth changed (logout), clearing vocab selection.");
                  }
                  await vocab.clearSelection();
                } else {
                  if (kDebugMode) {
                    print(
                        "[ProxyProvider][Vocab] Auth changed, but data not ready (${auth.userDataStatus}). Waiting.");
                  }
                }
              });
            }
            return vocab;
          },
        ),

        // 4. StatsProvider (依赖 Auth 和 Vocab)
        ChangeNotifierProxyProvider2<AuthProvider, VocabProvider,
            StatsProvider>(
          create: (context) => StatsProvider(
              context.read<AuthProvider>(), context.read<VocabProvider>()),
          update: (_, auth, vocab, previousStats) {
            final stats = previousStats ??
                StatsProvider(
                    auth, vocab); // Pass both dependencies on creation
            final currentUserId = auth.userId;
            final currentBookId = vocab.selectedBookId;
            final currentUserDataStatus = auth.userDataStatus;

            // Track changes in dependencies
            final userIdChanged = currentUserId != stats.currentUserIdInternal;
            final bookIdChanged = currentBookId != stats.currentBookIdInternal;
            final dataStatusChanged =
                currentUserDataStatus != stats.currentUserDataStatusInternal;

            // Update internal state of StatsProvider
            stats.updateDependencies(
                currentUserId, currentBookId, currentUserDataStatus);

            // --- Reload Logic ---
            if (userIdChanged || bookIdChanged || dataStatusChanged) {
              if (kDebugMode) {
                print(
                    "[ProxyProvider][Stats] Dependency changed: user($userIdChanged), book($bookIdChanged), dataStatus($dataStatusChanged).");
                print(
                    "  Current State: User=${stats.currentUserIdInternal}, Book=${stats.currentBookIdInternal}, DataStatus=${stats.currentUserDataStatusInternal}");
              }
              // If user or book changes, we definitely need new data, reset loaded flag
              if (userIdChanged || bookIdChanged) {
                stats.resetLoadedFlag();
              }

              // Check if dependencies are ready AND data needs loading/reloading
              if (currentUserId != null &&
                  currentBookId != null &&
                  currentUserDataStatus == UserDataStatus.ready) {
                // Only trigger load if dependencies changed OR data hasn't been loaded once yet for the current state
                if (userIdChanged ||
                    bookIdChanged ||
                    dataStatusChanged ||
                    !stats.isDataLoadedOnce) {
                  if (kDebugMode)
                    print(
                        "[ProxyProvider][Stats] Dependencies ready and changed/not loaded once. Triggering stats load.");
                  Future.microtask(() => stats.loadStatsData());
                } else {
                  if (kDebugMode)
                    print(
                        "[ProxyProvider][Stats] Dependencies ready, but unchanged and data loaded once. Skipping load.");
                }
              } else if (currentUserId == null || currentBookId == null) {
                // If user logged out or no book selected, reset stats state
                if (kDebugMode)
                  print(
                      "[ProxyProvider][Stats] User logged out or no book selected. Resetting stats.");
                Future.microtask(() => stats.resetState());
              } else {
                // Dependencies changed, but not ready yet (e.g., auth loading)
                if (kDebugMode)
                  print(
                      "[ProxyProvider][Stats] Dependencies changed but not ready ($currentUserDataStatus). Waiting.");
                // Optionally reset stats here if needed when data isn't ready
                // Future.microtask(() => stats.resetState());
              }
            }

            return stats;
          },
        ),
      ],
      child: MaterialApp(
        title: 'LexiLearn',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver], // ** 注册 RouteObserver **
        home: const AuthHandler(),
        routes: {
          '/login': (_) => const LoginPage(),
          '/check_vocab': (_) => const CheckVocabWrapper(),
          '/vocab_select': (_) => const VocabSelectPage(),
          '/home': (_) => const HomePage(),
          '/register': (_) => const RegisterPage(),
          '/menu': (_) => const MenuPage(),
          '/stats': (_) => const StatsPage(),
          '/plan': (_) => const PlanPage(),
          '/learn': (_) => const LearnPage(),
          '/review': (_) => const ReviewPage(),
        },
      ),
    );
  }
}

// AuthHandler (保持不变)
class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});
  @override
  Widget build(BuildContext context) {
    final authStatus = context.select((AuthProvider auth) => auth.status);
    final authError = context.select((AuthProvider auth) => auth.errorMessage);
    final userDataStatus =
        context.select((AuthProvider auth) => auth.userDataStatus);
    if (kDebugMode) {
      print(
          "[AuthHandler] Building with auth status: $authStatus, userDataStatus: $userDataStatus");
    }
    switch (authStatus) {
      case AuthStatus.loading:
      case AuthStatus.unknown:
        return const InitialLoadingScreen();
      case AuthStatus.error:
        return Scaffold(
          body: Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text("应用错误",
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(authError ?? "无法验证登录状态或加载数据。",
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        Provider.of<AuthProvider>(context, listen: false)
                            .logout(),
                    child: const Text("返回登录"),
                  )
                ],
              ),
            ),
          )),
        );
      case AuthStatus.authenticated:
        // --- 修改：添加对 UserDataStatus 的检查 ---
        if (userDataStatus == UserDataStatus.initializing) {
          return const InitialLoadingScreen(message: "准备用户数据...");
        } else if (userDataStatus == UserDataStatus.error) {
          // 显示特定的错误屏幕，允许用户尝试登出或重试（如果可能）
          return Scaffold(
            body: Center(
                child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storage_rounded,
                        color: Theme.of(context).colorScheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text("数据加载错误",
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(authError ?? "无法加载用户本地数据。",
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () =>
                          Provider.of<AuthProvider>(context, listen: false)
                              .logout(),
                      child: const Text("退出登录"),
                    )
                  ],
                ),
              ),
            )),
          );
        } else {
          // AuthStatus.authenticated && UserDataStatus.ready
          return const CheckVocabWrapper();
        }
      // --- 结束修改 ---
      case AuthStatus.unauthenticated:
        return const LoginPage();
    }
  }
}

// CheckVocabWrapper (保持不变)
class CheckVocabWrapper extends StatelessWidget {
  const CheckVocabWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final selectedBookId =
        context.select((VocabProvider vocab) => vocab.selectedBookId);
    final planIsLoading = context.select((PlanProvider plan) => plan.isLoading);
    final vocabIsLoading = context.select(
        (VocabProvider vocab) => vocab.loadStatus == VocabLoadStatus.loading);
    if (kDebugMode) {
      print(
          "[CheckVocabWrapper] Building. Selected bookId: $selectedBookId, Plan Loading: $planIsLoading, Vocab Loading: $vocabIsLoading");
    }
    if (planIsLoading || vocabIsLoading) {
      if (kDebugMode) {
        print("[CheckVocabWrapper] Waiting for Plan/Vocab data...");
      }
      return const InitialLoadingScreen(message: "加载用户数据...");
    }
    if (selectedBookId != null && selectedBookId.isNotEmpty) {
      if (kDebugMode) {
        print(
            "[CheckVocabWrapper] Book selected ('$selectedBookId'). Showing HomePage.");
      }
      return const HomePage();
    } else {
      if (kDebugMode) {
        print("[CheckVocabWrapper] No book selected. Showing VocabSelectPage.");
      }
      return const VocabSelectPage();
    }
  }
}

// InitialLoadingScreen (保持不变)
class InitialLoadingScreen extends StatelessWidget {
  final String message;
  const InitialLoadingScreen({this.message = "正在加载应用...", super.key});
  @override
  Widget build(BuildContext context) {
    // Removed initial auth check trigger from here, AuthProvider handles it
    return Scaffold(
      body: Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message)
        ],
      )),
    );
  }
}
