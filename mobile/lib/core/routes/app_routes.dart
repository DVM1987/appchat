import 'package:flutter/material.dart';

import '../../presentation/screens/auth/phone_input_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/home/home_screen.dart';

class AppRoutes {
  // Route Names
  static const String home = '/';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String login = '/login';
  static const String register = '/register';
  static const String newGroup = '/new-group';
  static const String broadcastLists = '/broadcast-lists';

  // Route Generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );

      case login:
        return MaterialPageRoute(
          builder: (_) => const PhoneInputScreen(),
          settings: settings,
        );

      case register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );

      case chat:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: args?['chatId'] ?? '',
            otherUserName: args?['otherUserName'] ?? 'Chat',
            otherUserAvatar: args?['otherUserAvatar'],
            isGroup: args?['isGroup'] ?? false,
            creatorId: args?['creatorId'],
            participantIds: (args?['participantIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList(),
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }

  // Navigation Helpers
  static void navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void navigateToAndReplace(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void navigateBack(BuildContext context) {
    Navigator.pop(context);
  }
}
