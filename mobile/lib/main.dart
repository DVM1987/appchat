import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/routes/app_routes.dart';
import 'data/services/push_notification_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/call_log_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/screens/auth/phone_input_screen.dart';
import 'presentation/screens/home/home_screen.dart';

void main() async {
  // Global error handler — catch ALL uncaught async/sync errors
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('[FlutterError] ${details.exception}');
        debugPrint('[FlutterError] ${details.stack}');
      };

      // Initialize Firebase
      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugPrint('[INIT] Firebase init error: $e');
      }

      // Register background message handler
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (e) {
        debugPrint('[INIT] Background handler error: $e');
      }

      // Initialize push notifications (non-blocking, with error handling)
      try {
        PushNotificationService().initialize();
      } catch (e) {
        debugPrint('[INIT] Push notification init error: $e');
      }

      runApp(const MyApp());
    },
    (error, stackTrace) {
      // This catches ALL uncaught async errors
      debugPrint('[ZONE ERROR] $error');
      debugPrint('[ZONE STACK] $stackTrace');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CallLogProvider()..load()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'MChat',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.background,
            ),
            home: const AuthChecker(),
            onGenerateRoute: AppRoutes.generateRoute,
          );
        },
      ),
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  bool _callbacksRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _registerLogoutCallbacks(authProvider);
    await authProvider.checkAuthStatus();
  }

  /// Register cleanup callbacks exactly once so that when the user
  /// logs out, ChatProvider and UserProvider are reset.
  void _registerLogoutCallbacks(AuthProvider authProvider) {
    if (_callbacksRegistered) return;
    _callbacksRegistered = true;

    authProvider.onLogout(() {
      // Clear stale conversation / user data
      try {
        context.read<ChatProvider>().clear();
      } catch (_) {}
      try {
        context.read<UserProvider>().clear();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show login screen if not authenticated, otherwise show home
        return authProvider.isAuthenticated
            ? const HomeScreen()
            : const PhoneInputScreen();
      },
    );
  }
}
