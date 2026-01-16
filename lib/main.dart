import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'navigation_observer.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'widgets/main_bottom_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e, st) {
    debugPrint('Firebase init failed: $e');
    debugPrintStack(stackTrace: st);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case '/signup':
        page = const Signup();
        break;
      case '/home':
        page = const MainTabScaffold();
        break;
      case '/explore':
        page = const MainTabScaffold(initialIndex: 1);
        break;
      case '/cuplikan':
        page = const MainTabScaffold(initialIndex: 2);
        break;
      case '/profile':
        page = const MainTabScaffold(initialIndex: 3);
        break;
      case '/login':
      default:
        page = const Login();
        break;
    }

    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        const begin = Offset(1, 0);
        const end = Offset.zero;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      onGenerateRoute: _onGenerateRoute,
      navigatorObservers: [routeObserver],
    );
  }
}
